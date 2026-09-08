import Foundation
import Security

final class RiotLoginInteractionGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    func observeManualInput() { lock.lock(); generation &+= 1; lock.unlock() }
    func snapshot() -> UInt64 { lock.lock(); defer { lock.unlock() }; return generation }
}

struct RiotCredentials: Sendable, CustomStringConvertible {
    let username: String
    private let passwordBytes: Data
    var description: String { "RiotCredentials(redacted)" }

    init(username: String, passwordBytes: Data) throws {
        guard !username.isEmpty, !passwordBytes.isEmpty,
              String(data: passwordBytes, encoding: .utf8) != nil else {
            throw RiotLoginError.invalidCredential
        }
        self.username = username
        self.passwordBytes = passwordBytes
    }

    func transientPassword() -> String { String(decoding: passwordBytes, as: UTF8.self) }
}

enum RiotLoginError: LocalizedError {
    case keychain(OSStatus), invalidCredential, unrecognizedForm, focusChanged, inputUnavailable
    var errorDescription: String? {
        switch self {
        case .keychain(let code): "Saved Riot sign-in could not read its DEV Keychain item (status \(code)). Manual sign-in remains available."
        case .invalidCredential: "The saved Riot account is missing or invalid. Manual sign-in remains available."
        case .unrecognizedForm: "Saved Riot sign-in stopped because the expected form is not ready. Manual sign-in remains available."
        case .focusChanged: "Saved Riot sign-in stopped because field focus or form contents changed. Manual sign-in remains available."
        case .inputUnavailable: "Saved Riot sign-in stopped because authenticated input is unavailable."
        }
    }
}

enum RiotCredentialStore {
    static let service = "com.flashls1.tftmac.dev.riot-login.v1"
    static let rememberKey = "TFTMACDEVRememberRiotLogin"
    static var remember: Bool {
        get { UserDefaults.standard.object(forKey: rememberKey) == nil || UserDefaults.standard.bool(forKey: rememberKey) }
        set { UserDefaults.standard.set(newValue, forKey: rememberKey) }
    }

    static func load() throws -> RiotCredentials {
        // DEV must never block startup on SecurityAgent. The item's ACL is the
        // authority; an ACL miss fails immediately and leaves manual sign-in
        // available instead of showing a prompt on every launch.
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword, kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitOne, kSecReturnAttributes: true, kSecReturnData: true,
            kSecUseAuthenticationUI: kSecUseAuthenticationUIFail
        ] as CFDictionary, &result)
        guard status == errSecSuccess else { throw RiotLoginError.keychain(status) }
        guard let item = result as? [String: Any],
              let username = item[kSecAttrAccount as String] as? String,
              let password = item[kSecValueData as String] as? Data else { throw RiotLoginError.invalidCredential }
        return try RiotCredentials(username: username, passwordBytes: password)
    }
}

struct RiotLoginForm: Sendable {
    struct Field: Sendable {
        let x: Int32, y: Int32
        let focused: Bool
        let text: String
    }
    let username: Field
    let password: Field
    let submit: Field
    let submitEnabled: Bool

    // The live Riot WebView supplies no resource IDs. Require its exact labels,
    // package, two editable roles and named submit button; never infer by position alone.
    static func parse(_ data: Data) throws -> Self {
        let collector = Nodes()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = collector
        guard data.count <= 1_048_576, parser.parse() else { throw RiotLoginError.unrecognizedForm }
        let nodes = collector.values
        let labels = Set(nodes.filter { $0["class"] != "android.widget.EditText" }.compactMap { $0["text"] })
        guard labels.contains("Sign In"), labels.contains("USERNAME"), labels.contains("PASSWORD"),
              !labels.contains(where: { label in
                  let text = label.lowercased()
                  return ["incorrect", "invalid credentials", "captcha", "verification code", "two-factor"].contains(where: text.contains)
              }) else { throw RiotLoginError.unrecognizedForm }
        let edits = nodes.filter { $0["class"] == "android.widget.EditText" }
        let usernames = edits.filter { $0["password"] == "false" }
        let passwords = edits.filter { $0["password"] == "true" }
        let buttons = nodes.filter { $0["class"] == "android.widget.Button" && $0["text"] == "Sign in" }
        guard edits.count == 2, usernames.count == 1, passwords.count == 1, buttons.count == 1 else {
            throw RiotLoginError.unrecognizedForm
        }
        for node in edits + buttons {
            guard node["package"] == "com.riotgames.league.teamfighttactics", node["clickable"] == "true" else {
                throw RiotLoginError.unrecognizedForm
            }
        }
        guard edits.allSatisfy({ $0["enabled"] == "true" && $0["focusable"] == "true" }) else {
            throw RiotLoginError.unrecognizedForm
        }
        return try Self(username: field(usernames[0]), password: field(passwords[0]),
                        submit: field(buttons[0]), submitEnabled: buttons[0]["enabled"] == "true")
    }

    private static func field(_ node: [String: String]) throws -> Field {
        let bounds = node["bounds", default: ""]
        let parts = bounds.split(whereSeparator: { !$0.isNumber }).compactMap { Int32($0) }
        guard parts.count == 4, parts[0] < parts[2], parts[1] < parts[3],
              parts[2] <= 8192, parts[3] <= 8192, !bounds.contains("-") else { throw RiotLoginError.unrecognizedForm }
        return Field(x: (parts[0] + parts[2]) / 2, y: (parts[1] + parts[3]) / 2,
                     focused: node["focused"] == "true", text: node["text", default: ""])
    }

    private final class Nodes: NSObject, XMLParserDelegate {
        var values: [[String: String]] = []
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String]) {
            if elementName == "node" { values.append(attributeDict) }
        }
    }
}
