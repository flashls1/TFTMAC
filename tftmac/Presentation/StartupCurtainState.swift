import Foundation

enum StartupCurtainEligibility: Equatable, Sendable {
    case tftGameActivity
    case riotLogin
}

enum StartupCurtainState: Equatable, Sendable {
    case covered
    case eligible(reason: StartupCurtainEligibility, baselineSequence: UInt32?)
    case revealed
    case failed(message: String)

    var isVisuallyCovered: Bool {
        switch self {
        case .covered, .eligible, .failed: true
        case .revealed: false
        }
    }
}

struct StartupCurtainReducer: Sendable {
    private(set) var state: StartupCurtainState = .covered
    private(set) var consumerCurtainEnabled = true

    mutating func configure(workload: TFTMACRuntimeWorkload) {
        guard !isTerminal else { return }
        consumerCurtainEnabled = workload == .officialTFT
        state = consumerCurtainEnabled ? .covered : .revealed
    }

    mutating func observeGameFrameStatus(
        _ status: GameFrameTelemetryStatus,
        currentPresentedSequence: UInt32?
    ) {
        guard consumerCurtainEnabled, !isTerminal else { return }
        switch status {
        case .available:
            becomeEligible(.tftGameActivity, baselineSequence: currentPresentedSequence)
        case .unavailable(.loginPromptActive):
            becomeEligible(.riotLogin, baselineSequence: currentPresentedSequence)
        case .unavailable:
            if case .eligible = state {
                state = .covered
            }
        }
    }

    mutating func sourceFramePresented(_ sequence: UInt32) {
        guard consumerCurtainEnabled,
              case .eligible(_, let baselineSequence) = state else { return }
        if let baselineSequence, sequence <= baselineSequence { return }
        state = .revealed
    }

    mutating func fail(_ message: String) {
        guard consumerCurtainEnabled, !isTerminal else { return }
        state = .failed(message: message)
    }

    mutating func timeoutElapsed() {
        // Deliberately non-revealing. Startup elapsed time is never authority
        // to expose Android/SystemUI/PIN content.
    }

    private var isTerminal: Bool {
        switch state {
        case .revealed, .failed: true
        case .covered, .eligible: false
        }
    }

    private mutating func becomeEligible(
        _ reason: StartupCurtainEligibility,
        baselineSequence: UInt32?
    ) {
        if case .eligible(let currentReason, _) = state, currentReason == reason {
            return
        }
        state = .eligible(reason: reason, baselineSequence: baselineSequence)
    }
}
