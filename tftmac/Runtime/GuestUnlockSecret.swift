import AppKit
import Foundation
import LocalAuthentication
import Security

struct TFTMACGuestUnlockSecret: Equatable, Sendable {
    private let utf8Digits: Data

    init?(pin: String) {
        guard Self.isValid(pin: pin) else { return nil }
        utf8Digits = Data(pin.utf8)
    }

    init?(keychainData: Data) {
        guard let pin = String(data: keychainData, encoding: .utf8), Self.isValid(pin: pin) else {
            return nil
        }
        utf8Digits = keychainData
    }

    static func isValid(pin: String) -> Bool {
        (4...16).contains(pin.count) && pin.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
    }

    var keychainData: Data { utf8Digits }

    func transientPIN() throws -> String {
        guard let pin = String(data: utf8Digits, encoding: .utf8) else {
            throw TFTMACGuestUnlockSecretError.invalidStoredSecret
        }
        return pin
    }
}

enum TFTMACGuestUnlockSecretError: LocalizedError {
    case cancelled
    case invalidStoredSecret
    case keychain(OSStatus)

    var isAuthorizationDenied: Bool {
        guard case .keychain(let status) = self else { return false }
        return status == errSecInteractionNotAllowed || status == errSecAuthFailed
    }

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Automatic Android unlock setup was cancelled. TFTMAC did not start."
        case .invalidStoredSecret:
            return "The saved Android unlock PIN is invalid. Remove the TFTMAC Android Unlock item from Keychain and relaunch."
        case .keychain(let status):
            return "macOS Keychain could not store or retrieve the Android unlock PIN (status \(status))."
        }
    }
}

@MainActor
enum TFTMACGuestUnlockSecretStore {
    // Control's v2 item is frozen as part of the protected stable launcher.
    // DEV deliberately owns a different item so its code ACL can never collide
    // with or mutate Control's Keychain authorization history.
    nonisolated private static let controlService = "com.flashls1.tftmac.android-unlock.v2"
    // DEV uses its own item. v2 is created by the signed DEV core so future
    // reads match the current designated requirement without an ACL rewrite.
    nonisolated private static let devService = "com.flashls1.tftmac.dev.android-unlock.v2"
    nonisolated private static let legacyDevService = "com.flashls1.tftmac.dev.android-unlock.v1"
    nonisolated private static let account = "android-user-0"

    nonisolated private static var devRuntimeKeychainURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TFTMAC/Modes/advanced_diagnostics/State/dev-unlock.keychain-db")
    }

    nonisolated static func service(for runtimeMode: TFTMACRuntimeMode) -> String {
        switch runtimeMode {
        case .advancedDiagnostics:
            return devService
        case .turbo2:
            // This namespace does not access or migrate any existing item.
            return "com.flashls1.tftmac.turbo2.android-unlock.v1"
        case .control, .candidate:
            return controlService
        }
    }

    nonisolated static func loadIfPresent(
        runtimeMode: TFTMACRuntimeMode
    ) throws -> TFTMACGuestUnlockSecret? {
        try load(service: service(for: runtimeMode))
    }

    nonisolated static func deleteIfPresent(
        runtimeMode: TFTMACRuntimeMode
    ) throws {
        let status = SecItemDelete(baseQuery(service: service(for: runtimeMode)) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TFTMACGuestUnlockSecretError.keychain(status)
        }
    }

    static func saveForSetup(
        _ secret: TFTMACGuestUnlockSecret,
        runtimeMode: TFTMACRuntimeMode
    ) throws {
        try save(secret, service: service(for: runtimeMode), accessibility: nil)
    }

    static func loadOrPrompt(
        applicationName: String,
        runtimeMode: TFTMACRuntimeMode
    ) throws -> TFTMACGuestUnlockSecret {
        // Personal DEV provisioning remains outside Git. Control and bundles
        // without this existing resource retain their Keychain behavior.
        if runtimeMode == .advancedDiagnostics,
           let resource = Bundle.main.url(forResource: "DEVGuestPIN", withExtension: "txt"),
           let pin = try? String(contentsOf: resource, encoding: .utf8),
           let supplied = TFTMACGuestUnlockSecret(pin: pin.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return supplied
        }
        let service = service(for: runtimeMode)
        let stored: TFTMACGuestUnlockSecret?
        do {
            stored = try load(service: service)
        } catch let error as TFTMACGuestUnlockSecretError
                    where runtimeMode == .advancedDiagnostics && error.isAuthorizationDenied {
            // The DEV item is held in a dedicated local keychain. This
            // fallback is only for the diagnostic route when the login
            // keychain ACL refuses noninteractive access; it never prompts
            // and never emits the PIN.
            stored = try loadFromDedicatedRuntimeKeychain()
        }
        switch stored {
        case .some(let secret):
            return secret
        case .none:
            if runtimeMode == .advancedDiagnostics,
               let legacy = try loadLegacyDEVIfAuthorized() {
                // Read the legacy item once, then retire it after the new
                // core-owned item has been written. Normal launches never
                // touch the legacy ACL again.
                try save(legacy, service: service, accessibility: nil)
                try? delete(service: legacyDevService)
                return legacy
            } else if runtimeMode == .advancedDiagnostics {
                // If the old ACL cannot be read without authorization, ask
                // for the Android PIN once and create the new item from this
                // signed core. This avoids an Apple-password prompt loop.
                let secret = try prompt(applicationName: applicationName)
                try save(secret, service: service, accessibility: nil)
                return secret
            }
            let secret = try prompt(applicationName: applicationName)
            try save(
                secret,
                service: service,
                accessibility: runtimeMode == .advancedDiagnostics ? nil : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            )
            return secret
        }
    }

    nonisolated private static func baseQuery(service: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }

    nonisolated private static func load(service: String) throws -> TFTMACGuestUnlockSecret? {
        try withKeychainInteractionDisabled {
            var query = baseQuery(service: service)
            query[kSecMatchLimit] = kSecMatchLimitOne
            query[kSecReturnData] = true
            // Never let a background experiment disappear behind an invisible
            // SecurityAgent authorization sheet. Missing access fails closed
            // and is handled by the DEV migration path below.
            let authentication = LAContext()
            authentication.interactionNotAllowed = true
            query[kSecUseAuthenticationContext] = authentication
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound { return nil }
            guard status == errSecSuccess, let data = item as? Data else {
                throw TFTMACGuestUnlockSecretError.keychain(status)
            }
            guard let secret = TFTMACGuestUnlockSecret(keychainData: data) else {
                throw TFTMACGuestUnlockSecretError.invalidStoredSecret
            }
            return secret
        }
    }

    private static func loadLegacyDEVIfAuthorized() throws -> TFTMACGuestUnlockSecret? {
        do {
            return try load(service: legacyDevService)
        } catch let error as TFTMACGuestUnlockSecretError where error.isAuthorizationDenied {
            return nil
        }
    }

    nonisolated private static func loadFromDedicatedRuntimeKeychain() throws -> TFTMACGuestUnlockSecret? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password", "-w",
            "-a", account,
            "-s", devService,
            devRuntimeKeychainURL.path
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let pin = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return TFTMACGuestUnlockSecret(pin: pin)
    }

    private static func save(
        _ secret: TFTMACGuestUnlockSecret,
        service: String,
        accessibility: CFString?
    ) throws {
        var add = baseQuery(service: service)
        add[kSecValueData] = secret.keychainData
        add[kSecAttrLabel] = "TFTMAC Android Unlock"
        if let accessibility {
            add[kSecAttrAccessible] = accessibility
        }
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [CFString: Any] = [kSecValueData: secret.keychainData]
            let updateStatus = SecItemUpdate(baseQuery(service: service) as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw TFTMACGuestUnlockSecretError.keychain(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw TFTMACGuestUnlockSecretError.keychain(status)
        }
    }

    private static func delete(service: String) throws {
        let status = try withKeychainInteractionDisabled {
            SecItemDelete(baseQuery(service: service) as CFDictionary)
        }
        guard status == errSecSuccess else {
            throw TFTMACGuestUnlockSecretError.keychain(status)
        }
    }

    nonisolated private static func withKeychainInteractionDisabled<T>(_ operation: () throws -> T) throws -> T {
        var wasAllowed = DarwinBoolean(true)
        let getStatus = SecKeychainGetUserInteractionAllowed(&wasAllowed)
        guard getStatus == errSecSuccess else {
            throw TFTMACGuestUnlockSecretError.keychain(getStatus)
        }
        let setStatus = SecKeychainSetUserInteractionAllowed(false)
        guard setStatus == errSecSuccess else {
            throw TFTMACGuestUnlockSecretError.keychain(setStatus)
        }
        defer { _ = SecKeychainSetUserInteractionAllowed(wasAllowed.boolValue) }
        return try operation()
    }

    private static func prompt(applicationName: String) throws -> TFTMACGuestUnlockSecret {
        while true {
            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
            field.placeholderString = "Android PIN"

            let alert = NSAlert()
            alert.messageText = "Set Up Automatic Android Unlock"
            alert.informativeText = "Enter the Android device PIN once. \(applicationName) stores it only in your local macOS Keychain and uses it only for the emulator lock screen."
            alert.alertStyle = .informational
            alert.accessoryView = field
            alert.addButton(withTitle: "Save Securely")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = field

            guard alert.runModal() == .alertFirstButtonReturn else {
                throw TFTMACGuestUnlockSecretError.cancelled
            }
            if let secret = TFTMACGuestUnlockSecret(pin: field.stringValue) {
                field.stringValue = ""
                return secret
            }
            field.stringValue = ""
            let invalid = NSAlert()
            invalid.messageText = "Invalid Android PIN"
            invalid.informativeText = "Use 4 to 16 digits. The value was not saved."
            invalid.alertStyle = .warning
            invalid.runModal()
        }
    }
}
