import Foundation

struct EmulatorFrame: @unchecked Sendable {
    let pixels: Data
    let width: Int
    let height: Int
    let sequence: UInt32
    let emulatorTimestampMicroseconds: UInt64
    let receivedMonotonicNanoseconds: UInt64
}

enum FrameContractError: LocalizedError, Equatable {
    case inactiveDisplay
    case invalidDisplayOverride(String)
    case wrongDimensions(width: Int, height: Int)
    case wrongByteCount(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .inactiveDisplay:
            return "The Android display is inactive."
        case .invalidDisplayOverride(let value):
            return "Unsupported advanced-diagnostics display override: \(value). Use 2560x1440 or 1920x1080."
        case .wrongDimensions(let width, let height):
            return "Expected a \(FrameContract.width)×\(FrameContract.height) Android frame, received \(width)×\(height)."
        case .wrongByteCount(let expected, let actual):
            return "Expected \(expected) RGBA bytes, received \(actual)."
        }
    }
}

enum FrameContract {
    private static let supportedAdvancedDiagnosticDisplays: [String: (width: Int, height: Int, densityDPI: Int)] = [
        "2560x1440": (2560, 1440, 416),
        "1920x1080": (1920, 1080, 416)
    ]

    private static func parsedDisplayOverride(_ value: String?) -> (width: Int, height: Int, densityDPI: Int)? {
        guard let value, let display = supportedAdvancedDiagnosticDisplays[value] else { return nil }
        return display
    }

    // One launch-selected geometry owns guest pixels, Metal textures and mouse mapping.
    static func display(
        forRuntimeMode mode: String?,
        requestedOverride: String? = ProcessInfo.processInfo.environment["TFTMAC_DEV_DISPLAY"]
    ) -> (width: Int, height: Int, densityDPI: Int) {
        guard mode == "advanced_diagnostics" else { return (1920, 1080, 320) }
        return parsedDisplayOverride(requestedOverride) ?? (2560, 1440, 416)
    }

    static func validatedDisplay(
        forRuntimeMode mode: String?,
        requestedOverride: String? = ProcessInfo.processInfo.environment["TFTMAC_DEV_DISPLAY"]
    ) throws -> (width: Int, height: Int, densityDPI: Int) {
        guard mode == "advanced_diagnostics" else { return display(forRuntimeMode: mode, requestedOverride: nil) }
        guard requestedOverride == nil || parsedDisplayOverride(requestedOverride) != nil else {
            throw FrameContractError.invalidDisplayOverride(requestedOverride ?? "")
        }
        return display(forRuntimeMode: mode, requestedOverride: requestedOverride)
    }

    private static let selectedDisplay = display(forRuntimeMode: ProcessInfo.processInfo.environment["TFTMAC_RUNTIME_MODE"])
    static let width = selectedDisplay.width
    static let height = selectedDisplay.height
    static let bytesPerPixel = 4
    static let expectedByteCount = width * height * bytesPerPixel

    static func validate(
        width: Int, height: Int, byteCount: Int,
        runtimeMode: String? = ProcessInfo.processInfo.environment["TFTMAC_RUNTIME_MODE"],
        requestedOverride: String? = ProcessInfo.processInfo.environment["TFTMAC_DEV_DISPLAY"]
    ) throws {
        let expected = display(forRuntimeMode: runtimeMode, requestedOverride: requestedOverride)
        let expectedByteCount = expected.width * expected.height * bytesPerPixel
        guard width > 0, height > 0 else { throw FrameContractError.inactiveDisplay }
        guard width == expected.width, height == expected.height else {
            throw FrameContractError.wrongDimensions(width: width, height: height)
        }
        guard byteCount == expectedByteCount else {
            throw FrameContractError.wrongByteCount(expected: expectedByteCount, actual: byteCount)
        }
    }
}

struct FrameMailboxSnapshot: Sendable {
    let receivedFrames: UInt64
    let replacedBeforePresentation: UInt64
    let sequenceDrops: UInt64
    let latestSequence: UInt32?
    let latestReceiveMonotonicNanoseconds: UInt64?
}

final class LatestFrameMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = [EmulatorFrame]()
    private let buffersDisplayJitter: Bool
    private let maximumPendingAgeNS: UInt64 = 33_333_334
    private var receivedFrames: UInt64 = 0
    private var replacedBeforePresentation: UInt64 = 0
    private var sequenceDrops: UInt64 = 0
    private var previousSequence: UInt32?
    private var latestReceiveMonotonicNanoseconds: UInt64?

    init(buffersDisplayJitter: Bool = false) {
        self.buffersDisplayJitter = buffersDisplayJitter
    }

    func publish(_ frame: EmulatorFrame) {
        lock.lock()
        defer { lock.unlock() }
        receivedFrames &+= 1
        let capacity = buffersDisplayJitter ? 2 : 1
        if pending.count == capacity {
            pending.removeFirst()
            replacedBeforePresentation &+= 1
        }
        if let previousSequence, frame.sequence > previousSequence &+ 1 {
            sequenceDrops &+= UInt64(frame.sequence - previousSequence - 1)
        }
        previousSequence = frame.sequence
        latestReceiveMonotonicNanoseconds = frame.receivedMonotonicNanoseconds
        pending.append(frame)
    }

    func takeForPresentation(nowMonotonicNS: UInt64 = DispatchTime.now().uptimeNanoseconds) -> EmulatorFrame? {
        lock.lock()
        defer { lock.unlock() }
        // Preserve short arrival bursts across consecutive display ticks, but skip older
        // queued content after a stall. Never wait to fill the buffer before displaying.
        if pending.count > 1, let oldest = pending.first,
           nowMonotonicNS > oldest.receivedMonotonicNanoseconds,
           nowMonotonicNS - oldest.receivedMonotonicNanoseconds > maximumPendingAgeNS {
            pending.removeFirst()
            replacedBeforePresentation &+= 1
        }
        return pending.isEmpty ? nil : pending.removeFirst()
    }

    func snapshot() -> FrameMailboxSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return FrameMailboxSnapshot(
            receivedFrames: receivedFrames,
            replacedBeforePresentation: replacedBeforePresentation,
            sequenceDrops: sequenceDrops,
            latestSequence: previousSequence,
            latestReceiveMonotonicNanoseconds: latestReceiveMonotonicNanoseconds
        )
    }
}
