#include "PipelineEventV1.h"

#include <CommonCrypto/CommonDigest.h>
#include <fcntl.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <atomic>
#include <limits>
#include <memory>
#include <vector>

namespace tftmac::causal {
namespace {

constexpr size_t kCapacity = 32768;
constexpr size_t kMaximumSegmentEvents = 65536;
constexpr uint64_t kSegmentDurationNs = 60ULL * 1000ULL * 1000ULL * 1000ULL;
constexpr long kDrainPollNs = 2L * 1000L * 1000L;

uint64_t MonotonicNowNs() {
    timespec value{};
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &value) != 0) return 0;
    return static_cast<uint64_t>(value.tv_sec) * 1000000000ULL +
           static_cast<uint64_t>(value.tv_nsec);
}

uint64_t CurrentThreadId() {
    uint64_t thread_id = 0;
    if (pthread_threadid_np(nullptr, &thread_id) != 0) return 0;
    return thread_id;
}

std::array<uint8_t, 32> Sha256(const void* bytes, size_t byte_count) {
    std::array<uint8_t, 32> digest{};
    CC_SHA256(bytes, static_cast<CC_LONG>(byte_count), digest.data());
    return digest;
}

bool WriteAll(int descriptor, const void* bytes, size_t byte_count) {
    const auto* cursor = static_cast<const uint8_t*>(bytes);
    while (byte_count > 0) {
        const ssize_t written = write(descriptor, cursor, byte_count);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return false;
        cursor += written;
        byte_count -= static_cast<size_t>(written);
    }
    return true;
}

struct ThreadRecorder {
    PipelineEventV1 events[kCapacity]{};
    std::atomic<uint64_t> write_index{0};
    std::atomic<uint64_t> read_index{0};
    std::atomic<uint64_t> overwrite_count{0};
    std::atomic<uint64_t> loss_count{0};
    std::atomic<uint64_t> pending_loss_count{0};
    std::atomic<bool> stop_requested{false};
    std::atomic<bool> flush_requested{false};
    std::atomic<uint64_t> flush_target_write{0};
    std::atomic<uint64_t> flush_completed{0};
    uint64_t sequence = 0;
    uint64_t segment_started_ns = 0;
    std::array<uint8_t, 32> previous_segment_sha256{};
    int descriptor = -1;
    pthread_t drain_thread{};
    bool drain_started = false;
    bool enabled = false;

    ThreadRecorder() {
        const char* enabled_value = std::getenv("TFTMAC_PIPELINE_EVENT_V1");
        const char* directory = std::getenv("TFTMAC_PIPELINE_EVENTS_DIR");
        if (!enabled_value || std::strcmp(enabled_value, "1") != 0 || !directory || !*directory) return;
        struct stat directory_stat {};
        if (stat(directory, &directory_stat) != 0 || !S_ISDIR(directory_stat.st_mode)) return;
        char path[PATH_MAX]{};
        const int length = std::snprintf(
            path,
            sizeof(path),
            "%s/pipeline-%d-%llu.bin",
            directory,
            getpid(),
            static_cast<unsigned long long>(CurrentThreadId()));
        if (length <= 0 || static_cast<size_t>(length) >= sizeof(path)) return;
        descriptor = open(path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, S_IRUSR | S_IWUSR);
        enabled = descriptor >= 0;
        segment_started_ns = MonotonicNowNs();
        if (enabled && pthread_create(&drain_thread, nullptr, DrainMain, this) == 0) {
            drain_started = true;
        } else {
            enabled = false;
            if (descriptor >= 0) close(descriptor);
            descriptor = -1;
        }
    }

    ~ThreadRecorder() {
        if (drain_started) {
            stop_requested.store(true, std::memory_order_release);
            pthread_join(drain_thread, nullptr);
        }
        if (descriptor >= 0) close(descriptor);
    }

    void Append(const PipelineEventV1& event) {
        if (!enabled) return;
        uint64_t write = write_index.load(std::memory_order_relaxed);
        const uint64_t read = read_index.load(std::memory_order_acquire);
        uint64_t pending_loss = pending_loss_count.load(std::memory_order_relaxed);
        const uint64_t required = pending_loss > 0 ? 2 : 1;
        if (write - read + required > kCapacity) {
            overwrite_count.fetch_add(1, std::memory_order_relaxed);
            loss_count.fetch_add(1, std::memory_order_relaxed);
            pending_loss_count.fetch_add(1, std::memory_order_relaxed);
            return;
        }
        if (pending_loss > 0 &&
            pending_loss_count.compare_exchange_strong(
                pending_loss, 0, std::memory_order_relaxed)) {
            PipelineEventV1 marker = event;
            marker.event_kind = static_cast<uint16_t>(EventKind::kLoss);
            marker.duration_ns = pending_loss;
            events[write % kCapacity] = marker;
            ++write;
        }
        events[write % kCapacity] = event;
        write_index.store(write + 1, std::memory_order_release);
    }

    static void* DrainMain(void* context) {
        static_cast<ThreadRecorder*>(context)->Drain();
        return nullptr;
    }

    void Drain() {
        std::vector<PipelineEventV1> segment;
        segment.reserve(kMaximumSegmentEvents);
        while (true) {
            uint64_t read = read_index.load(std::memory_order_relaxed);
            const uint64_t write = write_index.load(std::memory_order_acquire);
            while (read < write) {
                segment.push_back(events[read % kCapacity]);
                ++read;
                read_index.store(read, std::memory_order_release);
                const uint64_t now = segment.back().timestamp_ns;
                if (segment.size() >= kMaximumSegmentEvents ||
                    (now >= segment_started_ns && now - segment_started_ns >= kSegmentDurationNs)) {
                    Seal(segment);
                }
            }
            if (flush_requested.load(std::memory_order_acquire) &&
                read_index.load(std::memory_order_relaxed) >= flush_target_write.load(std::memory_order_acquire)) {
                flush_requested.store(false, std::memory_order_release);
                Seal(segment);
                flush_completed.fetch_add(1, std::memory_order_release);
            }
            if (stop_requested.load(std::memory_order_acquire) &&
                read_index.load(std::memory_order_relaxed) ==
                    write_index.load(std::memory_order_acquire)) {
                Seal(segment);
                break;
            }
            const timespec delay{0, kDrainPollNs};
            nanosleep(&delay, nullptr);
        }
    }

    void Seal(std::vector<PipelineEventV1>& segment) {
        if (segment.empty()) return;
        const size_t payload_bytes = segment.size() * sizeof(PipelineEventV1);
        PipelineSegmentHeaderV1 header{};
        header.magic = {'T', 'F', 'T', 'P', 'I', 'P', 'E', '1'};
        header.schema_version = 1;
        header.header_bytes = sizeof(PipelineSegmentHeaderV1);
        header.event_count = static_cast<uint32_t>(segment.size());
        header.segment_sequence = sequence;
        header.started_ns = segment_started_ns;
        header.ended_ns = segment.back().timestamp_ns;
        header.overwrite_count = overwrite_count.load(std::memory_order_relaxed);
        header.loss_count = loss_count.load(std::memory_order_relaxed);
        header.previous_segment_sha256 = previous_segment_sha256;
        header.payload_sha256 = Sha256(segment.data(), payload_bytes);

        std::array<uint8_t, 88> chain_input{};
        std::memcpy(chain_input.data(), header.previous_segment_sha256.data(), 32);
        std::memcpy(chain_input.data() + 32, header.payload_sha256.data(), 32);
        std::memcpy(chain_input.data() + 64, &header.segment_sequence, 8);
        std::memcpy(chain_input.data() + 72, &header.started_ns, 8);
        std::memcpy(chain_input.data() + 80, &header.ended_ns, 8);
        header.segment_sha256 = Sha256(chain_input.data(), chain_input.size());

        if (!WriteAll(descriptor, &header, sizeof(header)) ||
            !WriteAll(descriptor, segment.data(), payload_bytes)) {
            loss_count.fetch_add(segment.size(), std::memory_order_relaxed);
        } else {
            previous_segment_sha256 = header.segment_sha256;
            ++sequence;
        }
        segment.clear();
        segment_started_ns = MonotonicNowNs();
    }

    void FlushAndWait() {
        if (!enabled) return;
        const uint64_t target_write = write_index.load(std::memory_order_acquire);
        flush_target_write.store(target_write, std::memory_order_release);
        const uint64_t target = flush_completed.load(std::memory_order_acquire) + 1;
        flush_requested.store(true, std::memory_order_release);
        while (flush_completed.load(std::memory_order_acquire) < target) {
            const timespec delay{0, kDrainPollNs};
            nanosleep(&delay, nullptr);
        }
    }
};

thread_local std::unique_ptr<ThreadRecorder> g_recorder;
thread_local uint64_t g_transport_work_id = 0;
thread_local uint64_t g_present_lineage_id = 0;
thread_local uint32_t g_lineage_generation = 0;

ThreadRecorder* GetOrCreateRecorder() {
    if (!g_recorder) g_recorder = std::make_unique<ThreadRecorder>();
    return g_recorder.get();
}

}  // namespace

bool ParseOwnedProbeTransportLabel(const char* label, uint64_t* transport_work_id) {
    if (!label || !transport_work_id) return false;
    constexpr char prefix[] = "TFTMAC/";
    if (std::strncmp(label, prefix, sizeof(prefix) - 1) != 0) return false;
    const char* final_slash = std::strrchr(label, '/');
    if (!final_slash || final_slash == label || !final_slash[1]) return false;
    uint64_t value = 0;
    for (const char* cursor = final_slash + 1; *cursor; ++cursor) {
        if (*cursor < '0' || *cursor > '9') return false;
        const uint64_t digit = static_cast<uint64_t>(*cursor - '0');
        if (value > (std::numeric_limits<uint64_t>::max() - digit) / 10) return false;
        value = value * 10 + digit;
    }
    *transport_work_id = value;
    return true;
}

bool ParseOwnedProbeTimelineWorkId(
    uint32_t signal_semaphore_count,
    const void* p_next,
    uint64_t* transport_work_id) {
    if (signal_semaphore_count != 2 || !p_next || !transport_work_id) return false;
    constexpr uint32_t kVkStructureTypeTimelineSemaphoreSubmitInfo = 1000207003;

    struct GenericVkBaseInStructure {
        uint32_t sType;
        const GenericVkBaseInStructure* pNext;
    };
    static_assert(sizeof(GenericVkBaseInStructure) == 16, "GenericVkBaseInStructure ABI drift");
    static_assert(offsetof(GenericVkBaseInStructure, pNext) == 8, "GenericVkBaseInStructure pNext offset drift");

    struct GenericVkTimelineSemaphoreSubmitInfo {
        uint32_t sType;
        const void* pNext;
        uint32_t waitSemaphoreValueCount;
        const uint64_t* pWaitSemaphoreValues;
        uint32_t signalSemaphoreValueCount;
        const uint64_t* pSignalSemaphoreValues;
    };
    static_assert(sizeof(GenericVkTimelineSemaphoreSubmitInfo) == 48, "GenericVkTimelineSemaphoreSubmitInfo ABI drift");
    static_assert(offsetof(GenericVkTimelineSemaphoreSubmitInfo, signalSemaphoreValueCount) == 32, "signalSemaphoreValueCount offset drift");
    static_assert(offsetof(GenericVkTimelineSemaphoreSubmitInfo, pSignalSemaphoreValues) == 40, "pSignalSemaphoreValues offset drift");

    for (const auto* next = static_cast<const GenericVkBaseInStructure*>(p_next);
         next != nullptr;
         next = next->pNext) {
        if (next->sType == kVkStructureTypeTimelineSemaphoreSubmitInfo) {
            const auto* info = reinterpret_cast<const GenericVkTimelineSemaphoreSubmitInfo*>(next);
            if (info->signalSemaphoreValueCount == 2 &&
                info->pSignalSemaphoreValues != nullptr &&
                info->pSignalSemaphoreValues[0] == 0 &&
                info->pSignalSemaphoreValues[1] > 0) {
                *transport_work_id = info->pSignalSemaphoreValues[1];
                return true;
            }
            return false;
        }
    }
    return false;
}

void SetThreadTransportWorkId(uint64_t transport_work_id) {
    g_transport_work_id = transport_work_id;
}

bool InitializeCurrentThreadRecorder() { return GetOrCreateRecorder()->enabled; }

uint64_t MonotonicTimestampNS() { return MonotonicNowNs(); }

uint64_t CurrentThreadTransportWorkId() { return g_transport_work_id; }

void ClearThreadTransportWorkId() {
    g_transport_work_id = 0;
}

void SetThreadPresentLineage(uint64_t present_lineage_id, uint32_t generation) {
    g_present_lineage_id = present_lineage_id;
    g_lineage_generation = generation;
}

void ClearThreadPresentLineage() {
    g_present_lineage_id = 0;
    g_lineage_generation = 0;
}

void Record(
    EventKind kind,
    Boundary boundary,
    uint32_t source_site_id,
    uint64_t duration_ns,
    uint32_t queue_depth,
    uint16_t flags,
    const uint8_t* payload_sha256) {
    ThreadRecorder* recorder = GetOrCreateRecorder();
    if (!recorder->enabled) return;
    PipelineEventV1 event{};
    event.schema_version = 1;
    event.event_kind = static_cast<uint16_t>(kind);
    event.boundary = static_cast<uint16_t>(boundary);
    event.flags = flags;
    event.process_id = static_cast<uint32_t>(getpid());
    event.thread_id = CurrentThreadId();
    event.timestamp_ns = MonotonicNowNs();
    event.transport_work_id = g_transport_work_id;
    event.present_lineage_id = g_present_lineage_id;
    event.lineage_generation = g_lineage_generation;
    event.source_site_id = source_site_id;
    event.queue_depth = queue_depth;
    event.duration_ns = duration_ns;
    if (payload_sha256) std::memcpy(event.payload_sha256.data(), payload_sha256, 32);
    recorder->Append(event);
}

void FlushCurrentThread() {
    if (g_recorder) g_recorder->FlushAndWait();
}
uint64_t CurrentThreadOverwriteCount() {
    return g_recorder ? g_recorder->overwrite_count.load(std::memory_order_relaxed) : 0;
}
uint64_t CurrentThreadLossCount() {
    return g_recorder ? g_recorder->loss_count.load(std::memory_order_relaxed) : 0;
}

}  // namespace tftmac::causal
