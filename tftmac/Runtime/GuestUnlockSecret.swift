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
    nonisolated private static let devService = "com.flashls1.tftmac.dev.android-unlock.v1"
    private static let account = "android-user-0"

    nonisolated static func service(for runtimeMode: TFTMACRuntimeMode) -> String {
        switch runtimeMode {
        case .advancedDiagnostics:
            return devService
        case .control, .candidate:
            return controlService
        }
    }

    static func loadOrPrompt(
        applicationName: String,
        runtimeMode: TFTMACRuntimeMode
    ) throws -> TFTMACGuestUnlockSecret {
        let service = service(for: runtimeMode)
        switch try load(service: service) {
        case .some(let secret):
            return secret
        case .none:
            let secret = try prompt(applicationName: applicationName)
            try save(secret, service: service)
            return secret
        }
    }

    private static func baseQuery(service: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }

    private static func load(service: String) throws -> TFTMACGuestUnlockSecret? {
        var query = baseQuery(service: service)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true
        // Never let a background experiment disappear behind an invisible
        // SecurityAgent authorization sheet. Missing access fails closed and
        // is reported by the app instead of blocking the runner indefinitely.
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

    private static func save(_ secret: TFTMACGuestUnlockSecret, service: String) throws {
        var add = baseQuery(service: service)
        add[kSecValueData] = secret.keychainData
        add[kSecAttrLabel] = "TFTMAC Android Unlock"
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
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
