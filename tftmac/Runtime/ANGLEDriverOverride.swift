import CryptoKit
import Foundation

struct ANGLEDriverOverride: Decodable {
    struct Library: Decodable {
        let name: String
        let path: String
        let sha256: String
    }
    let schema: Int
    let variant: String
    let angleRevision: String
    let reuseEnabled: Bool
    let captureFrames: Int
    let viewDiagnosticsEnabled: Bool?
    let libraries: [Library]

    static let libraryNames = ["libEGL_angle.so", "libGLESv2_angle.so", "libGLESv1_CM_angle.so"]
    static let revision = "1166eec4c0b125e9e945196acfc549983ef72b18"

    static func validSessionIdentifier(_ value: String) -> Bool {
        // DEV uses an ISO timestamp with ':' replaced by '-', followed by a UUID.
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.")
        return (36...80).contains(value.count) && value.allSatisfy { allowed.contains($0) }
            && UUID(uuidString: String(value.suffix(36))) != nil
    }

    enum Failure: Error, Equatable {
        case manifestContract
        case libraryIdentity(String)
        case loadedIdentity
    }

    static func load(_ url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        guard data.count <= 32_768 else { throw Failure.manifestContract }
        let manifest = try JSONDecoder().decode(Self.self, from: data)
        try manifest.validate()
        return manifest
    }

    func validate() throws {
        guard schema == 1, angleRevision == Self.revision,
              ["reference", "reuse", "capture"].contains(variant),
              (!reuseEnabled || variant != "reference"),
              (0...300).contains(captureFrames),
              (captureFrames == 0 || variant == "capture"),
              libraries.count == Self.libraryNames.count,
              Set(libraries.map(\.name)) == Set(Self.libraryNames) else {
            throw Failure.manifestContract
        }
        for library in libraries {
            guard library.path.hasPrefix("/"), library.sha256.count == 64,
                  library.sha256.allSatisfy(\.isHexDigit) else { throw Failure.manifestContract }
            let url = URL(fileURLWithPath: library.path)
            let size = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard size.isRegularFile == true, let bytes = size.fileSize, bytes > 0,
                  bytes <= 64 * 1024 * 1024 else {
                throw Failure.libraryIdentity(library.name)
            }
            let data = try Data(contentsOf: url)
            guard data.count >= 64, Array(data.prefix(6)) == [0x7f, 0x45, 0x4c, 0x46, 2, 1],
                  data[16] == 3, data[17] == 0, data[18] == 183, data[19] == 0,
                  Self.sha(data) == library.sha256 else {
                throw Failure.libraryIdentity(library.name)
            }
        }
    }

    func expectedHashes() -> Data {
        Data(Self.libraryNames.map { name in
            let library = libraries.first { $0.name == name }!
            return "\(library.sha256) \(name)\n"
        }.joined().utf8)
    }

    func verifyLoadedReceipt(_ data: Data, session: String) throws -> Int32 {
        let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
        guard lines.count == 4 else { throw Failure.loadedIdentity }
        let fields = lines[0].split(separator: " ")
        guard fields.count == 3, fields[0] == "LOADED_VERIFIED",
              fields[1].hasPrefix("pid="), let pid = Int32(fields[1].dropFirst(4)), pid > 0,
              fields[2] == "session=\(session)",
              Data((lines.dropFirst().joined(separator: "\n") + "\n").utf8) == expectedHashes() else {
            throw Failure.loadedIdentity
        }
        return pid
    }

    private static func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
