import Foundation
import CryptoKit

/// Exercises the app's exact collector against the selected local DEV guest.
/// Faults affect only each test's nonce-owned endpoint and private output files.
@main struct NativeClockSessionIntegrationTest {
    static func run(_ executable: URL, _ arguments: [String], _ timeout: TimeInterval,
                    checked: Bool = true) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        deadline.cancel()
        guard !checked || process.terminationStatus == 0 else {
            throw NativeClockSampleError.transport("test command failed: \(process.terminationStatus)")
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 6, args[3] == "5041", args[4] == "emulator-5586" else {
            throw NativeClockSampleError.transport("usage: test resources adb 5041 emulator-5586 new-output-directory")
        }
        let resources = URL(fileURLWithPath: args[1], isDirectory: true)
        let adb = URL(fileURLWithPath: args[2])
        let prefix = ["-H", "127.0.0.1", "-P", args[3], "-s", args[4]]
        let output = URL(fileURLWithPath: args[5], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        let adbCommand: NativeClockSession.Command = { arguments, timeout in
            try run(adb, prefix + arguments, timeout)
        }
        var receipts: [[String: Any]] = []
        for fault in ["none", "missing_producer", "lost_event", "parser_failure", "artifact_write"] {
            let directory = output.appendingPathComponent(fault, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                   attributes: [.posixPermissions: 0o700])
            let session = try NativeClockSession(resources: resources, captureDirectory: directory,
                adb: adbCommand, client: { arguments, timeout in
                    let raw = try run(resources.appendingPathComponent("tftmac-clock-host"),
                                      arguments, timeout, checked: false)
                    if fault == "lost_event" {
                        return raw.split(whereSeparator: \.isNewline).dropLast().joined(separator: "\n") + "\n"
                    }
                    if fault == "parser_failure" {
                        var lines = raw.split(whereSeparator: \.isNewline).map(String.init)
                        guard lines.count == 8 else { throw NativeClockSampleError.incompleteBatch }
                        lines[3] = "{invalid-json"
                        return lines.joined(separator: "\n") + "\n"
                    }
                    return raw
                })
            let clockDirectory = directory.appendingPathComponent("native-clock-\(session.epoch)")
            let rawURL = clockDirectory.appendingPathComponent("batch-1.jsonl")
            var failure: String?
            var returnedSamples = 0
            do {
                if fault == "artifact_write" {
                    // A directory at the output filename makes the real write fail.
                    try FileManager.default.createDirectory(at: rawURL, withIntermediateDirectories: false)
                }
                if fault == "missing_producer" {
                    let guestDirectory = "/data/local/tmp/tftmac-clock-\(session.epoch)"
                    let pid = try adbCommand(["shell", "cat", guestDirectory + "/pid"], 5)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard Int32(pid) != nil else { throw NativeClockSampleError.identity }
                    let tokens = try adbCommand(["shell", "cat", "/proc/\(pid)/cmdline"], 5)
                        .split(separator: "\0").map(String.init)
                    guard tokens.first == guestDirectory + "/clock",
                          tokens.contains(String(session.epoch.prefix(16))),
                          tokens.contains(String(session.epoch.suffix(16))) else {
                        throw NativeClockSampleError.identity
                    }
                    _ = try adbCommand(["shell", "kill", "-TERM", pid], 5)
                    Thread.sleep(forTimeInterval: 0.1)
                }
                returnedSamples = try session.sample().samples.count
            } catch { failure = String(describing: error) }
            let cleanup = session.close()
            var rawVerified = false
            if let raw = try? Data(contentsOf: rawURL),
               let sealData = try? Data(contentsOf: rawURL.appendingPathExtension("seal.json")),
               let seal = try JSONSerialization.jsonObject(with: sealData) as? [String: Any] {
                rawVerified = seal["sha256"] as? String == SHA256.hash(data: raw)
                    .map { String(format: "%02x", $0) }.joined()
                    && seal["byte_count"] as? Int == raw.count
            }
            let expectedFailure = fault != "none"
            let pass = expectedFailure == (failure != nil) && cleanup.isEmpty
                && (fault == "artifact_write" || rawVerified)
                && (expectedFailure ? returnedSamples == 0 : returnedSamples == 8)
            receipts.append(["fault": fault, "state": pass ? "PASS" : "FAIL",
                "failure": failure as Any? ?? NSNull(), "returned_samples": returnedSamples,
                "sealed_raw_verified": rawVerified, "cleanup_errors": cleanup,
                "clock_epoch": session.epoch, "guest_boot_id": session.bootID])
        }
        let pass = receipts.allSatisfy { $0["state"] as? String == "PASS" }
        let receipt: [String: Any] = ["schema": 1, "state": pass ? "CLOCK_COLLECTOR_FAULT_TESTS_PASS" : "CLOCK_COLLECTOR_FAULT_TESTS_FAIL",
            "coverage": "native clock collector only; full pipeline readiness and observer overhead remain separate gates",
            "cases": receipts]
        let data = try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
        let receiptURL = output.appendingPathComponent("receipt.json")
        try data.write(to: receiptURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: receiptURL.path)
        print(String(decoding: data, as: UTF8.self))
        if !pass { Foundation.exit(1) }
    }
}
