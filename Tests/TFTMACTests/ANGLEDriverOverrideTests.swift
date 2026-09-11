import CryptoKit
import Foundation
import XCTest

final class ANGLEDriverOverrideTests: XCTestCase {
    private func fixture(_ run: (ANGLEDriverOverride, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        var header = Data(repeating: 0, count: 64)
        header.replaceSubrange(0..<6, with: [0x7f, 0x45, 0x4c, 0x46, 2, 1])
        header[16] = 3
        header[18] = 183
        let sha = SHA256.hash(data: header).map { String(format: "%02x", $0) }.joined()
        let libraries = try ANGLEDriverOverride.libraryNames.map { name in
            let file = directory.appendingPathComponent(name)
            try header.write(to: file)
            return ANGLEDriverOverride.Library(name: name, path: file.path, sha256: sha)
        }
        try run(ANGLEDriverOverride(schema: 1, variant: "reference", angleRevision: ANGLEDriverOverride.revision,
                                   reuseEnabled: false, captureFrames: 0, viewDiagnosticsEnabled: nil, libraries: libraries), directory)
    }

    func testManifestRequiresPinnedRevisionCompleteLibrarySetAndCompatibleVariant() throws {
        try fixture { valid, _ in
            XCTAssertNoThrow(try valid.validate())
            var json: [String: Any] = ["schema": 1, "variant": "reference", "angleRevision": valid.angleRevision,
                "reuseEnabled": false, "captureFrames": 0,
                "libraries": valid.libraries.map { ["name": $0.name, "path": $0.path, "sha256": $0.sha256] }]
            let legacy = try JSONDecoder().decode(ANGLEDriverOverride.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertNil(legacy.viewDiagnosticsEnabled)
            json["viewDiagnosticsEnabled"] = true
            let observed = try JSONDecoder().decode(ANGLEDriverOverride.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertEqual(observed.viewDiagnosticsEnabled, true)
            XCTAssertNoThrow(try observed.validate())
            for invalid in [
                ANGLEDriverOverride(schema: 2, variant: "reference", angleRevision: valid.angleRevision, reuseEnabled: false, captureFrames: 0, viewDiagnosticsEnabled: nil, libraries: valid.libraries),
                ANGLEDriverOverride(schema: 1, variant: "reference", angleRevision: "main", reuseEnabled: false, captureFrames: 0, viewDiagnosticsEnabled: nil, libraries: valid.libraries),
                ANGLEDriverOverride(schema: 1, variant: "reference", angleRevision: valid.angleRevision, reuseEnabled: true, captureFrames: 0, viewDiagnosticsEnabled: nil, libraries: valid.libraries),
                ANGLEDriverOverride(schema: 1, variant: "reuse", angleRevision: valid.angleRevision, reuseEnabled: false, captureFrames: 3, viewDiagnosticsEnabled: nil, libraries: valid.libraries),
                ANGLEDriverOverride(schema: 1, variant: "capture", angleRevision: valid.angleRevision, reuseEnabled: false, captureFrames: 301, viewDiagnosticsEnabled: nil, libraries: valid.libraries),
                ANGLEDriverOverride(schema: 1, variant: "reference", angleRevision: valid.angleRevision, reuseEnabled: false, captureFrames: 0, viewDiagnosticsEnabled: nil, libraries: [valid.libraries[0], valid.libraries[0], valid.libraries[2]])
            ] { XCTAssertThrowsError(try invalid.validate()) }
        }
    }

    func testLibraryReplacementAndWrongArchitectureAreRejected() throws {
        try fixture { valid, _ in
            let first = valid.libraries[0]
            var bytes = try Data(contentsOf: URL(fileURLWithPath: first.path))
            bytes[18] = 62 // x86_64 cannot enter this Android arm64 transaction.
            try bytes.write(to: URL(fileURLWithPath: first.path))
            XCTAssertThrowsError(try valid.validate())
            let wrongArchitecture = ANGLEDriverOverride.Library(name: first.name, path: first.path,
                sha256: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
            let wrong = ANGLEDriverOverride(schema: 1, variant: "reference", angleRevision: valid.angleRevision,
                reuseEnabled: false, captureFrames: 0, viewDiagnosticsEnabled: nil, libraries: [wrongArchitecture] + valid.libraries.dropFirst())
            XCTAssertThrowsError(try wrong.validate())
        }
    }

    func testLoadedReceiptRequiresSessionPIDAndEveryRequestedHash() throws {
        try fixture { manifest, _ in
            let session = "2026-09-06T01-53-34.768Z-" + UUID().uuidString.lowercased()
            XCTAssertTrue(ANGLEDriverOverride.validSessionIdentifier(session))
            XCTAssertFalse(ANGLEDriverOverride.validSessionIdentifier(session + ";"))
            XCTAssertFalse(ANGLEDriverOverride.validSessionIdentifier("2026-09-06-no-session-UUID"))
            let valid = Data("LOADED_VERIFIED pid=123 session=\(session)\n".utf8) + manifest.expectedHashes()
            XCTAssertEqual(try manifest.verifyLoadedReceipt(valid, session: session), 123)
            XCTAssertThrowsError(try manifest.verifyLoadedReceipt(valid, session: UUID().uuidString))
            XCTAssertThrowsError(try manifest.verifyLoadedReceipt(Data(valid.dropLast(10)), session: session))
            let missing = Data("LOADED_VERIFICATION_FAILED timeout\n".utf8)
            XCTAssertThrowsError(try manifest.verifyLoadedReceipt(missing, session: session))
        }
    }
}
