import CryptoKit
import Foundation

struct PipelineLogSignals: Equatable, Sendable {
    var gfxstreamWarningCount = 0
    var asgStallCount = 0
    var vulkanErrorCount = 0
    var moltenVKWarningCount = 0
    var shaderErrorCount = 0
    var fenceTimeoutCount = 0

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(
            gfxstreamWarningCount: lhs.gfxstreamWarningCount + rhs.gfxstreamWarningCount,
            asgStallCount: lhs.asgStallCount + rhs.asgStallCount,
            vulkanErrorCount: lhs.vulkanErrorCount + rhs.vulkanErrorCount,
            moltenVKWarningCount: lhs.moltenVKWarningCount + rhs.moltenVKWarningCount,
            shaderErrorCount: lhs.shaderErrorCount + rhs.shaderErrorCount,
            fenceTimeoutCount: lhs.fenceTimeoutCount + rhs.fenceTimeoutCount
        )
    }
}

enum TelemetrySignalClassifier {
    /// Counts only lines that identify an actual memory-pressure victim.
    /// LMKD startup, socket, memevent, tracepoint, and policy messages are not kills.
    static func isConfirmedGuestMemoryKill(_ line: String) -> Bool {
        let lower = line.lowercased()

        if lower.contains("out of memory: killed process") {
            return true
        }

        guard lower.contains("lmkd") || lower.contains("lowmemorykiller") else {
            return false
        }

        return lower.contains("kill '")
            || lower.contains("killing '")
            || lower.contains("kill process ")
            || lower.contains("killing process ")
            || lower.contains("killed process ")
    }

    /// Counts only diagnostic lines that already carry a failure, warning,
    /// timeout, or stall word. Component names in normal startup/configuration
    /// receipts must not become fabricated pipeline failures.
    static func pipelineSignals(in line: String) -> PipelineLogSignals {
        let lower = line.lowercased()
        let warningOrFailure = lower.contains("warn")
            || lower.contains("error")
            || lower.contains("failed")
            || lower.contains("failure")
            || lower.contains("timeout")
            || lower.contains("timed out")
            || lower.contains("stall")
            || lower.contains("fatal")
        guard warningOrFailure else { return PipelineLogSignals() }

        return PipelineLogSignals(
            gfxstreamWarningCount: lower.contains("gfxstream") ? 1 : 0,
            asgStallCount: lower.contains("asg")
                && (lower.contains("stall") || lower.contains("timeout") || lower.contains("failed") || lower.contains("error")) ? 1 : 0,
            vulkanErrorCount: (lower.contains("vulkan") || lower.contains(" vk_"))
                && (lower.contains("error") || lower.contains("failed") || lower.contains("fatal") || lower.contains("timeout")) ? 1 : 0,
            moltenVKWarningCount: (lower.contains("moltenvk") || lower.contains("[mvk]")) ? 1 : 0,
            shaderErrorCount: lower.contains("shader")
                && (lower.contains("error") || lower.contains("failed") || lower.contains("fatal")) ? 1 : 0,
            fenceTimeoutCount: lower.contains("fence")
                && (lower.contains("timeout") || lower.contains("timed out") || lower.contains("stall") || lower.contains("failed")) ? 1 : 0
        )
    }
}

enum PipelineFindingState: String, Codable, Sendable {
    case rootNamed = "ROOT_NAMED"
    case rootCandidate = "ROOT_CANDIDATE"
    case unknown = "UNKNOWN"
    case unrealOrPreHostUnknown = "UNREAL_OR_PRE_HOST_UNKNOWN"
}

enum PipelineBoundary: UInt16, Codable, CaseIterable, Sendable {
    case guestProbeSubmit = 1
    case asgHostReceive = 2
    case gfxstreamDecode = 3
    case hostVulkanQueueLock = 4
    case hostVulkanSubmit = 5
    case moltenVKPipelineLookup = 6
    case moltenVKPipelineCreate = 7
    case moltenVKEnqueue = 8
    case metalCommit = 9
    case metalScheduled = 10
    case metalGPUStart = 11
    case metalGPUComplete = 12
    case colorBufferPublish = 13
    case sourceFramePublish = 14
    case surfaceFlingerPresent = 15

    var ownedComponent: String {
        switch self {
        case .guestProbeSubmit: "OWNED_PROBE"
        case .asgHostReceive: "ASG"
        case .gfxstreamDecode, .hostVulkanQueueLock, .hostVulkanSubmit: "GFXSTREAM"
        case .moltenVKPipelineLookup, .moltenVKPipelineCreate, .moltenVKEnqueue: "MOLTENVK"
        case .metalCommit, .metalScheduled, .metalGPUStart, .metalGPUComplete: "METAL"
        case .colorBufferPublish, .sourceFramePublish: "EMULATOR_PRESENTATION"
        case .surfaceFlingerPresent: "SURFACEFLINGER"
        }
    }
}

enum PipelineEventKind: UInt16, Codable, Sendable {
    case begin = 1
    case end = 2
    case instant = 3
    case loss = 4
}

/// Fixed-width, versioned causal event ABI. `encodedBinary()` is exactly 96
/// bytes and little-endian so separately built owned components can share it
/// without depending on Swift's in-memory layout.
struct PipelineEventV1: Equatable, Sendable {
    static let schemaVersion: UInt16 = 1
    static let binaryByteCount = 96

    let kind: PipelineEventKind
    let boundary: PipelineBoundary
    let flags: UInt16
    let processID: UInt32
    let threadID: UInt64
    let timestampNS: UInt64
    let transportWorkID: UInt64?
    let presentLineageID: UInt64?
    let generation: UInt32
    let sourceSiteID: UInt32
    let queueDepth: UInt32
    let durationNS: UInt64
    let payloadHash: SHA256Digest

    func encodedBinary() -> Data {
        var data = Data(capacity: Self.binaryByteCount)
        data.appendLittleEndian(Self.schemaVersion)
        data.appendLittleEndian(kind.rawValue)
        data.appendLittleEndian(boundary.rawValue)
        data.appendLittleEndian(flags)
        data.appendLittleEndian(processID)
        data.appendLittleEndian(threadID)
        data.appendLittleEndian(timestampNS)
        data.appendLittleEndian(transportWorkID ?? 0)
        data.appendLittleEndian(presentLineageID ?? 0)
        data.appendLittleEndian(generation)
        data.appendLittleEndian(sourceSiteID)
        data.appendLittleEndian(queueDepth)
        data.appendLittleEndian(durationNS)
        data.append(contentsOf: payloadHash)
        precondition(data.count == Self.binaryByteCount)
        return data
    }
}

struct FixedPipelineEventRing: Sendable {
    let capacity: Int
    private(set) var overwriteCount: UInt64 = 0
    private(set) var appendCount: UInt64 = 0
    private var storage: [PipelineEventV1?]

    init(capacity: Int = 256) {
        precondition(capacity > 0)
        self.capacity = capacity
        storage = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ event: PipelineEventV1) {
        let index = Int(appendCount % UInt64(capacity))
        if appendCount >= UInt64(capacity) { overwriteCount += 1 }
        storage[index] = event
        appendCount += 1
    }

    func orderedEvents() -> [PipelineEventV1] {
        let retained = min(Int(appendCount), capacity)
        guard retained > 0 else { return [] }
        let first = appendCount > UInt64(capacity) ? Int(appendCount % UInt64(capacity)) : 0
        return (0..<retained).compactMap { storage[(first + $0) % capacity] }
    }
}

struct PipelineSegmentSeal: Equatable, Sendable {
    let previousSHA256: String
    let payloadSHA256: String
    let segmentSHA256: String

    static func seal(payload: Data, previousSHA256: String?) -> Self {
        let previous = previousSHA256 ?? String(repeating: "0", count: 64)
        let payloadDigest = SHA256.hash(data: payload).hex
        let chain = Data((previous + payloadDigest).utf8)
        return Self(
            previousSHA256: previous,
            payloadSHA256: payloadDigest,
            segmentSHA256: SHA256.hash(data: chain).hex
        )
    }
}

struct PipelineDiagnosticFinding: Equatable, Sendable {
    let state: PipelineFindingState
    let boundary: PipelineBoundary?
    let owner: String?
    let confidence: Double
    let explicitUnknowns: [String]
}

enum PipelineCausalAnalyzer {
    static func analyze(
        events: [PipelineEventV1],
        eligibleFrameCount: Int,
        unambiguousLineageCount: Int,
        overwriteCount: UInt64,
        observerOverheadPercent: Double,
        officialTFT: Bool,
        lateBoundaryThresholdNS: UInt64 = 16_666_667
    ) -> PipelineDiagnosticFinding {
        if observerOverheadPercent > 5 {
            return unknown("OBSERVER_OVERHEAD_INVALID")
        }
        guard eligibleFrameCount > 0 else { return unknown("NO_ELIGIBLE_FRAMES") }
        let lineageCoverage = Double(unambiguousLineageCount) / Double(eligibleFrameCount)
        guard lineageCoverage >= 0.999 else { return unknown("LINEAGE_COVERAGE_BELOW_99_9_PERCENT") }
        guard overwriteCount == 0 else { return unknown("PIPELINE_EVENT_LOSS") }

        let identified = events.filter { $0.transportWorkID != nil }
        if identified.isEmpty {
            return officialTFT
                ? PipelineDiagnosticFinding(
                    state: .unrealOrPreHostUnknown,
                    boundary: nil,
                    owner: nil,
                    confidence: 0,
                    explicitUnknowns: ["NO_GUEST_SUBMISSION_IDENTITY_AT_FIRST_HOST_HOOK"]
                )
                : unknown("TRANSPORT_WORK_ID_NOT_PRESERVED")
        }
        let grouped = Dictionary(grouping: identified, by: { $0.transportWorkID! })
        let firstLate = grouped.values.compactMap { lineage in
            lineage
                .filter { $0.durationNS >= lateBoundaryThresholdNS }
                .min { lhs, rhs in
                    lhs.boundary.rawValue == rhs.boundary.rawValue
                        ? lhs.timestampNS < rhs.timestampNS
                        : lhs.boundary.rawValue < rhs.boundary.rawValue
                }?
                .boundary
        }
        guard firstLate.count >= 2 else { return unknown("INSUFFICIENT_REPLICATED_LATE_LINEAGES") }
        let counts = Dictionary(grouping: firstLate, by: { $0 }).mapValues(\.count)
        guard let winner = counts.max(by: { $0.value < $1.value }) else {
            return unknown("NO_FIRST_DIVERGENT_BOUNDARY")
        }
        let confidence = Double(winner.value) / Double(firstLate.count)
        if winner.value >= 3, confidence >= 0.8 {
            return PipelineDiagnosticFinding(
                state: .rootNamed,
                boundary: winner.key,
                owner: winner.key.ownedComponent,
                confidence: confidence,
                explicitUnknowns: []
            )
        }
        if winner.value >= 2, confidence >= 0.5 {
            return PipelineDiagnosticFinding(
                state: .rootCandidate,
                boundary: winner.key,
                owner: winner.key.ownedComponent,
                confidence: confidence,
                explicitUnknowns: ["REPLICATION_THRESHOLD_NOT_MET"]
            )
        }
        return unknown("NO_REPLICATED_FIRST_BOUNDARY")
    }

    private static func unknown(_ reason: String) -> PipelineDiagnosticFinding {
        PipelineDiagnosticFinding(
            state: .unknown,
            boundary: nil,
            owner: nil,
            confidence: 0,
            explicitUnknowns: [reason]
        )
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}

private extension SHA256Digest {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
