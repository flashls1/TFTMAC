import CryptoKit
import Foundation

enum AVDTransactionRestoreDecision: Equatable, Sendable {
    case alreadyOriginal
    case restoreBackup
}

enum AVDTransactionGuardError: LocalizedError, Equatable, Sendable {
    case conflictingCurrentConfiguration
    case unexpectedRecoveryPath
    case invalidRecoveryJournal
    case invalidRecoveryBackup
    case recoveryReadbackFailed

    var errorDescription: String? {
        switch self {
        case .conflictingCurrentConfiguration:
            return "The AVD config changed after TFTMAC applied its profile; automatic restore stopped without overwriting it."
        case .unexpectedRecoveryPath:
            return "The interrupted AVD transaction names a path outside TFTMAC's exact config and capture roots; recovery stopped safely."
        case .invalidRecoveryJournal:
            return "The interrupted AVD transaction journal is unreadable or invalid; recovery stopped safely."
        case .invalidRecoveryBackup:
            return "The interrupted AVD backup does not match the original runtime authority; recovery stopped safely."
        case .recoveryReadbackFailed:
            return "The restored AVD configuration failed readback; its recovery journal was retained."
        }
    }
}

enum AVDTransactionGuard {
    // Caller must hold the runtime lease and have verified emulator absence.
    @discardableResult
    static func recover(
        configURL: URL, stateRoot: URL, captureRoot: URL,
        expectedOriginalSHA256: String?
    ) throws -> Bool {
        let markerURL = stateRoot.appendingPathComponent("avd-config-transaction.json")
        guard FileManager.default.fileExists(atPath: markerURL.path) else { return false }
        guard let data = try? Data(contentsOf: markerURL),
              let marker = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              marker["schema"] as? Int == 1,
              let config = marker["config"] as? String,
              let backup = marker["backup"] as? String,
              let original = marker["original_sha256"] as? String,
              let applied = marker["applied_sha256"] as? String else {
            throw AVDTransactionGuardError.invalidRecoveryJournal
        }
        let backupURL = URL(fileURLWithPath: backup)
        try validateRecoveryPaths(markerConfigURL: URL(fileURLWithPath: config), expectedConfigURL: configURL,
                                  backupURL: backupURL, captureRoot: captureRoot)
        let backupData = try Data(contentsOf: backupURL)
        guard digest(backupData) == original,
              expectedOriginalSHA256 == nil || original == expectedOriginalSHA256 else {
            throw AVDTransactionGuardError.invalidRecoveryBackup
        }
        let decision = try restoreDecision(currentSHA256: digest(Data(contentsOf: configURL)),
                                           originalSHA256: original, appliedSHA256: applied)
        if decision == .restoreBackup { try backupData.write(to: configURL, options: .atomic) }
        guard digest(try Data(contentsOf: configURL)) == original else {
            throw AVDTransactionGuardError.recoveryReadbackFailed
        }
        try FileManager.default.removeItem(at: markerURL)
        return true
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func restoreDecision(
        currentSHA256: String,
        originalSHA256: String,
        appliedSHA256: String
    ) throws -> AVDTransactionRestoreDecision {
        if currentSHA256 == originalSHA256 { return .alreadyOriginal }
        guard currentSHA256 == appliedSHA256 else {
            throw AVDTransactionGuardError.conflictingCurrentConfiguration
        }
        return .restoreBackup
    }

    static func validateRecoveryPaths(
        markerConfigURL: URL,
        expectedConfigURL: URL,
        backupURL: URL,
        captureRoot: URL
    ) throws {
        let markerConfig = markerConfigURL.standardizedFileURL.resolvingSymlinksInPath()
        let expectedConfig = expectedConfigURL.standardizedFileURL.resolvingSymlinksInPath()
        let backup = backupURL.standardizedFileURL.resolvingSymlinksInPath()
        let captures = captureRoot.standardizedFileURL.resolvingSymlinksInPath()
        let capturesPrefix = captures.path.hasSuffix("/") ? captures.path : captures.path + "/"
        guard markerConfig.path == expectedConfig.path,
              backup.path.hasPrefix(capturesPrefix),
              backup.lastPathComponent == "avd-config.before.ini" else {
            throw AVDTransactionGuardError.unexpectedRecoveryPath
        }
    }
}
