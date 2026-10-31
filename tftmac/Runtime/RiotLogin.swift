import Foundation

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
    case credentialFile, invalidCredential, unrecognizedForm, focusChanged, inputUnavailable
    var errorDescription: String? {
        switch self {
        case .credentialFile: "Saved Riot sign-in could not read the local DEV credential file. Manual sign-in remains available."
        case .invalidCredential: "The saved Riot account is missing or invalid. Manual sign-in remains available."
        case .unrecognizedForm: "Saved Riot sign-in stopped because the expected form is not ready. Manual sign-in remains available."
        case .focusChanged: "Saved Riot sign-in stopped because field focus or form contents changed. Manual sign-in remains available."
        case .inputUnavailable: "Saved Riot sign-in stopped because authenticated input is unavailable."
        }
    }
}

enum RiotCredentialStore {
    static let rememberKey = "TFTMACDEVRememberRiotLogin"
    private static let credentialDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        .appendingPathComponent("Library/Application Support/TFTMAC DEV", isDirectory: true)
    private static let credentialURL = credentialDirectory.appendingPathComponent("riot-login.json")
    static var remember: Bool {
        get { UserDefaults.standard.object(forKey: rememberKey) == nil || UserDefaults.standard.bool(forKey: rememberKey) }
        set { UserDefaults.standard.set(newValue, forKey: rememberKey) }
    }

    static func load() throws -> RiotCredentials {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: credentialURL.path)
        } catch {
            throw RiotLoginError.credentialFile
        }
        guard let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o077 == 0,
              let data = try? Data(contentsOf: credentialURL, options: [.mappedIfSafe]),
              data.count <= 16_384 else { throw RiotLoginError.credentialFile }
        struct FileCredentials: Decodable {
            let username: String
            let password: String
        }
        let file: FileCredentials
        do {
            file = try JSONDecoder().decode(FileCredentials.self, from: data)
        } catch {
            throw RiotLoginError.credentialFile
        }
        return try RiotCredentials(username: file.username, passwordBytes: Data(file.password.utf8))
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
enum GooglePlayListingState: String, Sendable, Equatable {
    case authRequired = "AUTH_REQUIRED"
    case updateAvailable = "UPDATE_AVAILABLE"
    case installAvailable = "INSTALL_AVAILABLE"
    case inProgress = "IN_PROGRESS"
    case current = "CURRENT"
    case unresolved = "UNRESOLVED"
}

struct RiotPackageAuthority {
    static func installerPackageName(from output: String) -> String? {
        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            if let range = line.range(of: "installerPackageName=") {
                let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty || value == "null" ? nil : value
            }
            if let range = line.range(of: "Installer package name:", options: [.caseInsensitive]) {
                let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty || value == "null" ? nil : value
            }
            if let range = line.range(of: "installer=", options: [.caseInsensitive]) {
                let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty || value == "null" ? nil : value
            }
        }
        return nil
    }

    static func googlePlayListingState(from xml: String) -> GooglePlayListingState {
        let lower = xml.lowercased()
        if lower.range(of: #"(?:text|content-desc)="(?:sign in|add account|verify[^"]*account|choose an account|google account|authentication\s+is\s+required[^"]*|re[- ]?enter[^"]*credentials)""#, options: .regularExpression) != nil {
            return .authRequired
        }
        if lower.range(of: #"(?:text|content-desc)="update""#, options: .regularExpression) != nil { return .updateAvailable }
        if lower.range(of: #"(?:text|content-desc)="install""#, options: .regularExpression) != nil { return .installAvailable }
        if lower.range(of: #"(?:text|content-desc)="(?:pending|installing|downloading|cancel|[^"]*%)""#, options: .regularExpression) != nil { return .inProgress }
        if lower.range(of: #"(?:text|content-desc)="(?:open|play)""#, options: .regularExpression) != nil { return .current }
        return .unresolved
    }

    static func actionCenter(in xml: String, label: String) -> (x: Int32, y: Int32)? {
        guard let nodeRegex = try? NSRegularExpression(pattern: #"<node\b[^>]*>"#, options: [.caseInsensitive]),
              let boundsRegex = try? NSRegularExpression(pattern: #"bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]""#) else { return nil }
        let ns = xml as NSString
        for match in nodeRegex.matches(in: xml, range: NSRange(location: 0, length: ns.length)) {
            let node = ns.substring(with: match.range)
            let escaped = NSRegularExpression.escapedPattern(for: label)
            guard node.range(of: #"(?:text|content-desc)=""# + escaped + #"""#, options: [.regularExpression, .caseInsensitive]) != nil else { continue }
            let nodeNS = node as NSString
            guard let b = boundsRegex.firstMatch(in: node, range: NSRange(location: 0, length: nodeNS.length)), b.numberOfRanges == 5 else { continue }
            let x1 = Int32(nodeNS.substring(with: b.range(at: 1))) ?? 0
            let y1 = Int32(nodeNS.substring(with: b.range(at: 2))) ?? 0
            let x2 = Int32(nodeNS.substring(with: b.range(at: 3))) ?? 0
            let y2 = Int32(nodeNS.substring(with: b.range(at: 4))) ?? 0
            return ((x1 + x2) / 2, (y1 + y2) / 2)
        }
        return nil
    }
}
