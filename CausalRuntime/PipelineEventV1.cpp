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
#include <limits>

namespace tftmac::causal {
namespace {

constexpr size_t kCapacity = 256;
constexpr uint64_t kSegmentDurationNs = 60ULL * 1000ULL * 1000ULL * 1000ULL;

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
    size_t count = 0;
    uint64_t overwrite_count = 0;
    uint64_t loss_count = 0;
    uint64_t sequence = 0;
    uint64_t segment_started_ns = 0;
    uint64_t transport_work_id = 0;
    uint64_t present_lineage_id = 0;
    uint32_t lineage_generation = 0;
    std::array<uint8_t, 32> previous_segment_sha256{};
    int descriptor = -1;
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
    }

    ~ThreadRecorder() {
        Flush();
        if (descriptor >= 0) close(descriptor);
    }

    void Append(const PipelineEventV1& event) {
        if (!enabled) return;
        if (count == kCapacity) Flush();
        if (count == kCapacity) {
            ++overwrite_count;
            return;
        }
        events[count++] = event;
        if (event.timestamp_ns - segment_started_ns >= kSegmentDurationNs) Flush();
    }

    void Flush() {
        if (!enabled || count == 0) return;
        const size_t payload_bytes = count * sizeof(PipelineEventV1);
        PipelineSegmentHeaderV1 header{};
        header.magic = {'T', 'F', 'T', 'P', 'I', 'P', 'E', '1'};
        header.schema_version = 1;
        header.header_bytes = sizeof(PipelineSegmentHeaderV1);
        header.event_count = static_cast<uint32_t>(count);
        header.segment_sequence = sequence;
        header.started_ns = segment_started_ns;
        header.ended_ns = events[count - 1].timestamp_ns;
        header.overwrite_count = overwrite_count;
        header.loss_count = loss_count;
        header.previous_segment_sha256 = previous_segment_sha256;
        header.payload_sha256 = Sha256(events, payload_bytes);

        std::array<uint8_t, 88> chain_input{};
        std::memcpy(chain_input.data(), header.previous_segment_sha256.data(), 32);
        std::memcpy(chain_input.data() + 32, header.payload_sha256.data(), 32);
        std::memcpy(chain_input.data() + 64, &header.segment_sequence, 8);
        std::memcpy(chain_input.data() + 72, &header.started_ns, 8);
        std::memcpy(chain_input.data() + 80, &header.ended_ns, 8);
        header.segment_sha256 = Sha256(chain_input.data(), chain_input.size());

        if (!WriteAll(descriptor, &header, sizeof(header)) ||
            !WriteAll(descriptor, events, payload_bytes)) {
            ++loss_count;
        } else {
            previous_segment_sha256 = header.segment_sha256;
            ++sequence;
        }
        count = 0;
        segment_started_ns = MonotonicNowNs();
    }
};

thread_local ThreadRecorder g_recorder;

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

void SetThreadTransportWorkId(uint64_t transport_work_id) {
    g_recorder.transport_work_id = transport_work_id;
}

void ClearThreadTransportWorkId() {
    g_recorder.transport_work_id = 0;
}

void SetThreadPresentLineage(uint64_t present_lineage_id, uint32_t generation) {
    g_recorder.present_lineage_id = present_lineage_id;
    g_recorder.lineage_generation = generation;
}

void ClearThreadPresentLineage() {
    g_recorder.present_lineage_id = 0;
    g_recorder.lineage_generation = 0;
}

void Record(
    EventKind kind,
    Boundary boundary,
    uint32_t source_site_id,
    uint64_t duration_ns,
    uint32_t queue_depth,
    uint16_t flags,
    const uint8_t* payload_sha256) {
    if (!g_recorder.enabled) return;
    PipelineEventV1 event{};
    event.schema_version = 1;
    event.event_kind = static_cast<uint16_t>(kind);
    event.boundary = static_cast<uint16_t>(boundary);
    event.flags = flags;
    event.process_id = static_cast<uint32_t>(getpid());
    event.thread_id = CurrentThreadId();
    event.timestamp_ns = MonotonicNowNs();
    event.transport_work_id = g_recorder.transport_work_id;
    event.present_lineage_id = g_recorder.present_lineage_id;
    event.lineage_generation = g_recorder.lineage_generation;
    event.source_site_id = source_site_id;
    event.queue_depth = queue_depth;
    event.duration_ns = duration_ns;
    if (payload_sha256) std::memcpy(event.payload_sha256.data(), payload_sha256, 32);
    g_recorder.Append(event);
}

void FlushCurrentThread() { g_recorder.Flush(); }
uint64_t CurrentThreadOverwriteCount() { return g_recorder.overwrite_count; }
uint64_t CurrentThreadLossCount() { return g_recorder.loss_count; }

}  // namespace tftmac::causal
