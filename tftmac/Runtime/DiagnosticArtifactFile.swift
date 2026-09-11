import CryptoKit
import Foundation

enum DiagnosticArtifactFile {
    static func persistStartupFailure(_ message: String, applicationSupport: URL) throws -> URL {
        let root = applicationSupport.appendingPathComponent("State/StartupFailures", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let url = root.appendingPathComponent("\(UUID().uuidString.lowercased()).json")
        let data = try JSONSerialization.data(withJSONObject: [
            "schema": 1, "utc": ISO8601DateFormatter().string(from: Date()),
            "pid": ProcessInfo.processInfo.processIdentifier,
            "error": message, "stage": "startup_or_runtime", "first_specific_failure": true
        ], options: [.prettyPrinted, .sortedKeys])
        guard FileManager.default.createFile(atPath: url.path, contents: nil,
                                             attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        guard try Data(contentsOf: url) == data else { throw Failure.rawIdentityChanged }
        return url
    }

    struct Seal: Sendable {
        let url: URL
        let byteCount: Int64
        let sha256: String
    }

    enum Failure: Error, Equatable {
        case emptyRawCapture
        case rawIdentityChanged
        case malformedSummary
    }

    static func seal(_ url: URL) throws -> Seal {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard !data.isEmpty else { throw Failure.emptyRawCapture }
        return Seal(url: url, byteCount: Int64(data.count), sha256: digest(data))
    }

    static func verify(_ seal: Seal) throws {
        let data = try Data(contentsOf: seal.url, options: .mappedIfSafe)
        guard data.count == seal.byteCount, digest(data) == seal.sha256 else {
            throw Failure.rawIdentityChanged
        }
    }

    static func normalize(
        _ raw: Seal,
        parser: (URL) throws -> Data,
        writer: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
    ) throws -> (url: URL, data: Data, sha256: String) {
        try verify(raw)
        let parsed = try parser(raw.url)
        let summary = try validatedSummary(parsed)
        try verify(raw)
        let output = raw.url.appendingPathExtension("normalized.csv")
        // Every failure leaves the sealed raw artifact available for offline recovery.
        try writer(summary, output)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
        return (output, summary, digest(summary))
    }

    private static func validatedSummary(_ data: Data) throws -> Data {
        let expected = ["trace_start_ns", "trace_end_ns", "process_rows", "thread_rows",
                        "scheduler_slices", "counter_rows", "surfaceflinger_slices", "tft_process_rows"]
        let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
        let headers = lines.indices.filter { index in
            lines[index].split(separator: ",", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" \t"))
            } == expected
        }
        guard headers.count == 1, let header = headers.first, header + 1 < lines.count else {
            throw Failure.malformedSummary
        }
        let values = lines[header + 1].split(separator: ",", omittingEmptySubsequences: false)
            .map { Int64($0.trimmingCharacters(in: .whitespaces)) }
        guard values.count == expected.count, values.allSatisfy({ ($0 ?? -1) >= 0 }),
              let start = values[0], let end = values[1], end > start else {
            throw Failure.malformedSummary
        }
        return Data((lines[header] + "\n" + lines[header + 1] + "\n").utf8)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
