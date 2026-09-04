#include "PipelineEventV1.h"

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <unistd.h>

int main() {
    using tftmac::causal::ParseOwnedProbeTransportLabel;
    using tftmac::causal::ParseOwnedProbeTimelineWorkId;
    uint64_t value = 0;
    assert(sizeof(tftmac::causal::PipelineEventV1) == 96);
    assert(ParseOwnedProbeTransportLabel("TFTMAC/control/stable_descriptor_draw/184467", &value));
    assert(value == 184467);
    assert(!ParseOwnedProbeTransportLabel("TFTMAC/control/stable_descriptor_draw/not-a-number", &value));
    assert(!ParseOwnedProbeTransportLabel("Riot/control/stable_descriptor_draw/1", &value));
    assert(!ParseOwnedProbeTransportLabel("TFTMAC/control/stable_descriptor_draw/18446744073709551616", &value));

    struct MockTimelineSubmitInfo {
        uint32_t sType = 1000207003;
        const void* pNext = nullptr;
        uint32_t waitSemaphoreValueCount = 0;
        const uint64_t* pWaitSemaphoreValues = nullptr;
        uint32_t signalSemaphoreValueCount = 2;
        const uint64_t* pSignalSemaphoreValues = nullptr;
    };
    uint64_t signal_vals[2] = {0, 42};
    MockTimelineSubmitInfo info;
    info.pSignalSemaphoreValues = signal_vals;
    uint64_t work_id = 0;
    assert(ParseOwnedProbeTimelineWorkId(2, &info, &work_id));
    assert(work_id == 42);

    // Negative test cases:
    assert(!ParseOwnedProbeTimelineWorkId(1, &info, &work_id));
    assert(!ParseOwnedProbeTimelineWorkId(2, nullptr, &work_id));
    assert(!ParseOwnedProbeTimelineWorkId(2, &info, nullptr));
    info.sType = 12345;
    assert(!ParseOwnedProbeTimelineWorkId(2, &info, &work_id));
    info.sType = 1000207003;
    info.signalSemaphoreValueCount = 1;
    assert(!ParseOwnedProbeTimelineWorkId(2, &info, &work_id));
    info.signalSemaphoreValueCount = 2;
    signal_vals[0] = 1;
    assert(!ParseOwnedProbeTimelineWorkId(2, &info, &work_id));
    signal_vals[0] = 0;
    signal_vals[1] = 0;
    assert(!ParseOwnedProbeTimelineWorkId(2, &info, &work_id));

    const auto directory = std::filesystem::temp_directory_path() /
        ("tftmac-pipeline-event-test-" + std::to_string(getpid()));
    assert(std::filesystem::create_directory(directory));
    assert(setenv("TFTMAC_PIPELINE_EVENT_V1", "1", 1) == 0);
    assert(setenv("TFTMAC_PIPELINE_EVENTS_DIR", directory.c_str(), 1) == 0);
    assert(tftmac::causal::InitializeCurrentThreadRecorder());
    tftmac::causal::SetThreadTransportWorkId(44);
    for (uint32_t index = 0; index < 257; ++index) {
        tftmac::causal::Record(
            tftmac::causal::EventKind::kInstant,
            tftmac::causal::Boundary::kGfxstreamDecode,
            1001,
            index,
            index % 3);
    }
    tftmac::causal::FlushCurrentThread();
    assert(tftmac::causal::CurrentThreadOverwriteCount() == 0);
    assert(tftmac::causal::CurrentThreadLossCount() == 0);

    std::filesystem::path segment_path;
    for (const auto& entry : std::filesystem::directory_iterator(directory)) {
        if (entry.path().extension() == ".bin") segment_path = entry.path();
    }
    assert(!segment_path.empty());
    std::ifstream stream(segment_path, std::ios::binary);
    tftmac::causal::PipelineSegmentHeaderV1 first{};
    stream.read(reinterpret_cast<char*>(&first), sizeof(first));
    const std::array<char, 8> expected_magic{'T', 'F', 'T', 'P', 'I', 'P', 'E', '1'};
    assert(first.magic == expected_magic);
    assert(first.event_count == 257);
    assert(first.loss_count == 0);
    stream.close();
    std::filesystem::remove(segment_path);
    std::filesystem::remove(directory);
    return 0;
}
