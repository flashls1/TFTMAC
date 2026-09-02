#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace tftmac::causal {

enum class EventKind : uint16_t {
    kBegin = 1,
    kEnd = 2,
    kInstant = 3,
    kLoss = 4,
};

enum class Boundary : uint16_t {
    kGuestProbeSubmit = 1,
    kAsgHostReceive = 2,
    kGfxstreamDecode = 3,
    kHostVulkanQueueLock = 4,
    kHostVulkanSubmit = 5,
    kMoltenVKPipelineLookup = 6,
    kMoltenVKPipelineCreate = 7,
    kMoltenVKEnqueue = 8,
    kMetalCommit = 9,
    kMetalScheduled = 10,
    kMetalGpuStart = 11,
    kMetalGpuComplete = 12,
    kColorBufferPublish = 13,
    kSourceFramePublish = 14,
    kSurfaceFlingerPresent = 15,
};

#pragma pack(push, 1)
struct PipelineEventV1 {
    uint16_t schema_version;
    uint16_t event_kind;
    uint16_t boundary;
    uint16_t flags;
    uint32_t process_id;
    uint64_t thread_id;
    uint64_t timestamp_ns;
    uint64_t transport_work_id;
    uint64_t present_lineage_id;
    uint32_t lineage_generation;
    uint32_t source_site_id;
    uint32_t queue_depth;
    uint64_t duration_ns;
    std::array<uint8_t, 32> payload_sha256;
};

struct PipelineSegmentHeaderV1 {
    std::array<char, 8> magic;
    uint16_t schema_version;
    uint16_t header_bytes;
    uint32_t event_count;
    uint64_t segment_sequence;
    uint64_t started_ns;
    uint64_t ended_ns;
    uint64_t overwrite_count;
    uint64_t loss_count;
    std::array<uint8_t, 32> previous_segment_sha256;
    std::array<uint8_t, 32> payload_sha256;
    std::array<uint8_t, 32> segment_sha256;
};
#pragma pack(pop)

static_assert(sizeof(PipelineEventV1) == 96, "PipelineEventV1 ABI drift");

// Exact parser for labels emitted by the owned probe:
// TFTMAC/<profile>/<workload>/<unsigned-decimal-frame-id>
bool ParseOwnedProbeTransportLabel(const char* label, uint64_t* transport_work_id);

void SetThreadTransportWorkId(uint64_t transport_work_id);
void ClearThreadTransportWorkId();
void SetThreadPresentLineage(uint64_t present_lineage_id, uint32_t generation);
void ClearThreadPresentLineage();

// The append path is fixed-capacity and allocation-free. Recording is disabled
// unless TFTMAC_PIPELINE_EVENTS_DIR names an existing private directory and
// TFTMAC_PIPELINE_EVENT_V1=1 is present in the emulator-host environment.
void Record(
    EventKind kind,
    Boundary boundary,
    uint32_t source_site_id,
    uint64_t duration_ns = 0,
    uint32_t queue_depth = 0,
    uint16_t flags = 0,
    const uint8_t* payload_sha256 = nullptr);

void FlushCurrentThread();
uint64_t CurrentThreadOverwriteCount();
uint64_t CurrentThreadLossCount();

}  // namespace tftmac::causal
