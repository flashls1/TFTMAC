import Foundation
import CryptoKit
import Darwin

enum NativeClockSampleError: Error, Equatable {
    case identity
    case domain
    case chronology
    case inconsistentBounds
    case incompleteBatch
    case transport(String)
}

struct NativeClockBatch: Sendable {
    let epoch: String
    let bootID: String
    let index: UInt64
    let samples: [NativeClockSample]
    let rawURL: URL

    static func parse(_ data: Data, epoch: String, count: Int) throws -> [NativeClockSample] {
        guard let text = String(data: data, encoding: .utf8), data.count < 131_072,
              count > 0, count <= 64 else { throw NativeClockSampleError.incompleteBatch }
        let lines = text.split(whereSeparator: \.isNewline)
        guard lines.count == count else { throw NativeClockSampleError.incompleteBatch }
        var samples: [NativeClockSample] = []
        for (index, line) in lines.enumerated() {
            let sample = try NativeClockSample.parse(Data(line.utf8), expectedEpoch: epoch,
                                                     expectedSequence: UInt64(index + 1))
            if let previous = samples.last, sample.hostT0NS < previous.hostT3NS {
                throw NativeClockSampleError.chronology
            }
            samples.append(sample)
        }
        return samples
    }
}

/// Owned, boot-scoped native clock endpoint. All subprocess work runs on the
/// diagnostics worker; the input channel does not call or wait for this object.
final class NativeClockSession {
    typealias Command = (_ arguments: [String], _ timeout: TimeInterval) throws -> String
    private let adb: Command
    private let client: Command
    private let directory: URL
    private let guestDirectory: String
    private var guestDirectoryCreated = false
    private var guestPID: Int32?
    private var hostPort: UInt16?
    private var batchIndex: UInt64 = 0
    let epoch = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    private(set) var bootID = ""

    init(resources: URL, captureDirectory: URL, adb: @escaping Command,
         client: @escaping Command) throws {
        self.adb = adb
        self.client = client
        directory = captureDirectory.appendingPathComponent("native-clock-\(epoch)", isDirectory: true)
        guestDirectory = "/data/local/tmp/tftmac-clock-\(epoch)"
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        do {
            let manifest = try JSONDecoder().decode([String: String].self,
                from: Data(contentsOf: resources.appendingPathComponent("manifest.json")))
            for name in ["tftmac-clock-host", "tftmac-clock-android"] {
                let data = try Data(contentsOf: resources.appendingPathComponent(name))
                let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard manifest[name] == sha else { throw NativeClockSampleError.transport("helper identity") }
            }
            guard try shell(["id", "-u"]) == "2000" else {
                throw NativeClockSampleError.transport("guest clock requires normal shell privileges")
            }
            bootID = try shell(["cat", "/proc/sys/kernel/random/boot_id"])
            guard UUID(uuidString: bootID) != nil else { throw NativeClockSampleError.transport("guest boot identity") }
            let provenance: [String: Any] = ["schema": 1, "clock_epoch": epoch,
                "guest_boot_id": bootID, "helper_sha256": manifest,
                "host_clock": "MACH_ABSOLUTE", "guest_clock": "CLOCK_MONOTONIC",
                "long_interval_drift_bound_proven": false]
            try Self.writePrivate(JSONSerialization.data(withJSONObject: provenance, options: [.sortedKeys]),
                                  to: directory.appendingPathComponent("provenance.json"))
            _ = try shell(["mkdir", "-m", "700", guestDirectory])
            guestDirectoryCreated = true
            _ = try adb(["push", resources.appendingPathComponent("tftmac-clock-android").path,
                         guestDirectory + "/clock"], 20)
            _ = try shell(["chmod", "700", guestDirectory + "/clock"])
            let copied = try shell(["sha256sum", guestDirectory + "/clock"]).split(separator: " ").first
            guard copied.map(String.init) == manifest["tftmac-clock-android"] else {
                throw NativeClockSampleError.transport("guest helper identity")
            }
            let parts = [guestDirectory + "/clock", "server-guest", "49351", String(epoch.prefix(16)),
                         String(epoch.suffix(16))].map(Self.quote).joined(separator: " ")
            // No application credentials or environment are placed in this command.
            _ = try adb(["shell", "nohup \(parts) >\(Self.quote(guestDirectory + "/ready")) 2>\(Self.quote(guestDirectory + "/stderr")) </dev/null & echo $! >\(Self.quote(guestDirectory + "/pid"))"], 10)
            guestPID = Int32(try shell(["cat", guestDirectory + "/pid"]))
            guard guestPID != nil else { throw NativeClockSampleError.transport("guest producer identity") }
            var ready = false
            for _ in 0..<20 {
                let text = try shell(["cat", guestDirectory + "/ready"])
                if let data = text.data(using: .utf8),
                   let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   object["state"] as? String == "CLOCK_SERVER_READY",
                   object["pid"] as? Int32 == guestPID,
                   object["port"] as? Int == 49351,
                   object["bind_address"] as? String == "0.0.0.0" { ready = true; break }
                Thread.sleep(forTimeInterval: 0.05)
            }
            guard ready else { throw NativeClockSampleError.transport("guest producer missing") }
            let port = try Self.availableLoopbackPort()
            let response = try adb(["emu", "redir", "add", "tcp:\(port):49351"], 5)
            guard response.contains("OK"), !response.contains("KO") else {
                throw NativeClockSampleError.transport("native forward rejected")
            }
            hostPort = port
        } catch {
            let failures = close()
            try? Self.writePrivate(Data(failures.joined(separator: "\n").utf8),
                                   to: directory.appendingPathComponent("setup-cleanup.txt"))
            throw error
        }
    }

    func sample() throws -> NativeClockBatch {
        guard let hostPort else { throw NativeClockSampleError.transport("session closed") }
        batchIndex += 1
        let rawURL = directory.appendingPathComponent("batch-\(batchIndex).jsonl")
        let text = try client(["client", "\(hostPort)", String(epoch.prefix(16)), String(epoch.suffix(16)),
                               "8", "1"], 5)
        let data = Data(text.utf8)
        // Preserve the exact private wire output before attempting normalization.
        try Self.writePrivate(data, to: rawURL)
        let persisted = try Data(contentsOf: rawURL)
        guard persisted == data else { throw NativeClockSampleError.transport("raw artifact identity changed") }
        let seal: [String: Any] = ["schema": 1, "clock_epoch": epoch, "guest_boot_id": bootID,
            "batch_sequence": batchIndex, "raw_file": rawURL.lastPathComponent,
            "byte_count": data.count,
            "sha256": SHA256.hash(data: persisted).map { String(format: "%02x", $0) }.joined()]
        try Self.writePrivate(JSONSerialization.data(withJSONObject: seal, options: [.sortedKeys]),
                              to: rawURL.appendingPathExtension("seal.json"))
        let samples = try NativeClockBatch.parse(data, epoch: epoch, count: 8)
        return NativeClockBatch(epoch: epoch, bootID: bootID, index: batchIndex,
                                samples: samples, rawURL: rawURL)
    }

    @discardableResult func close() -> [String] {
        var failures: [String] = []
        if let port = hostPort {
            do {
                let response = try adb(["emu", "redir", "del", "tcp:\(port)"], 5)
                guard response.contains("OK"), !response.contains("KO") else {
                    throw NativeClockSampleError.transport("forward removal rejected")
                }
                hostPort = nil
            } catch { failures.append("forward: \(error)") }
        }
        if let pid = guestPID {
            do {
                guard try shell(["cat", "/proc/sys/kernel/random/boot_id"]) == bootID else {
                    throw NativeClockSampleError.transport("guest boot changed; termination withheld")
                }
                let cmdline = try shell(["sh", "-c", "if test -d /proc/\(pid); then cat /proc/\(pid)/cmdline; else echo TFTMAC_CLOCK_EXITED; fi"])
                let tokens = cmdline.split(separator: "\0").map(String.init)
                if cmdline != "TFTMAC_CLOCK_EXITED" {
                    guard tokens.first == guestDirectory + "/clock", tokens.contains(String(epoch.prefix(16))),
                      tokens.contains(String(epoch.suffix(16))) else {
                        throw NativeClockSampleError.transport("producer ownership changed; termination withheld")
                    }
                    _ = try shell(["kill", "-TERM", "\(pid)"])
                    var exited = false
                    for _ in 0..<20 {
                        let state = try shell(["sh", "-c", "if test -d /proc/\(pid); then echo running; else echo stopped; fi"])
                        if state == "stopped" { exited = true; break }
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                    guard exited else { throw NativeClockSampleError.transport("guest producer exit unconfirmed") }
                }
                guestPID = nil
            } catch { failures.append("guest producer: \(error)") }
        }
        if guestDirectoryCreated, guestPID == nil {
            do {
                guard try shell(["cat", "/proc/sys/kernel/random/boot_id"]) == bootID else {
                    throw NativeClockSampleError.transport("guest boot changed; directory removal withheld")
                }
                _ = try shell(["rm", "-rf", guestDirectory])
                guestDirectoryCreated = false
            } catch { failures.append("guest directory: \(error)") }
        }
        return failures
    }

    private func shell(_ arguments: [String]) throws -> String {
        try adb(["shell", arguments.map(Self.quote).joined(separator: " ")], 5)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func writePrivate(_ data: Data, to url: URL) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil,
                                            attributes: [.posixPermissions: 0o600]) else {
            throw NativeClockSampleError.transport("raw artifact creation failed")
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    private static func availableLoopbackPort() throws -> UInt16 {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw NativeClockSampleError.transport("host socket") }
        defer { Darwin.close(descriptor) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { raw in
                guard Darwin.bind(descriptor, raw, size) == 0 else { return Int32(-1) }
                return getsockname(descriptor, raw, &size)
            }
        }
        guard result == 0 else { throw NativeClockSampleError.transport("host port reservation") }
        return UInt16(bigEndian: address.sin_port)
    }
}

/// A native four-timestamp exchange. Precision describes this exchange only;
/// extrapolation across an unsampled interval needs its own drift evidence.
struct NativeClockSample: Decodable, Equatable, Sendable {
    let schema: Int
    let state: String
    let sessionID: String
    let sequence: UInt64
    let hostT0NS: UInt64
    let guestT1NS: UInt64
    let guestT2NS: UInt64
    let hostT3NS: UInt64
    let offsetLowerNS: Int64
    let offsetUpperNS: Int64
    let uncertaintyNS: UInt64
    let hostClock: String
    let guestClock: String

    enum CodingKeys: String, CodingKey {
        case schema, state, sequence
        case sessionID = "session_id"
        case hostT0NS = "host_t0_ns", guestT1NS = "guest_t1_ns"
        case guestT2NS = "guest_t2_ns", hostT3NS = "host_t3_ns"
        case offsetLowerNS = "offset_lower_ns", offsetUpperNS = "offset_upper_ns"
        case uncertaintyNS = "uncertainty_ns"
        case hostClock = "host_clock", guestClock = "guest_clock"
    }

    static func parse(_ data: Data, expectedEpoch: String, expectedSequence: UInt64) throws -> Self {
        let sample = try JSONDecoder().decode(Self.self, from: data)
        guard sample.schema == 1, sample.sessionID == expectedEpoch,
              expectedEpoch.count == 32, expectedEpoch.allSatisfy(\.isHexDigit),
              sample.sequence == expectedSequence, expectedSequence > 0 else {
            throw NativeClockSampleError.identity
        }
        guard sample.hostClock == "MACH_ABSOLUTE", sample.guestClock == "CLOCK_MONOTONIC" else {
            throw NativeClockSampleError.domain
        }
        guard [sample.hostT0NS, sample.guestT1NS, sample.guestT2NS, sample.hostT3NS]
                .allSatisfy({ $0 > 0 && $0 <= UInt64(Int64.max) }),
              sample.hostT3NS >= sample.hostT0NS, sample.guestT2NS >= sample.guestT1NS,
              sample.hostT3NS - sample.hostT0NS <= 2_000_000_000,
              sample.guestT2NS - sample.guestT1NS <= sample.hostT3NS - sample.hostT0NS else {
            throw NativeClockSampleError.chronology
        }
        let lower = Int64(sample.guestT2NS) - Int64(sample.hostT3NS)
        let upper = Int64(sample.guestT1NS) - Int64(sample.hostT0NS)
        // Chronology bounds this subtraction by the two-second exchange limit.
        let uncertainty = UInt64(upper - lower + 1) / 2
        guard sample.offsetLowerNS == lower, sample.offsetUpperNS == upper,
              sample.uncertaintyNS == uncertainty,
              sample.state == (uncertainty <= 500_000 ? "CLOCK_PRECISE" : "CLOCK_UNCERTAIN") else {
            throw NativeClockSampleError.inconsistentBounds
        }
        return sample
    }

    var preciseAtSample: Bool { uncertaintyNS <= 500_000 }
    var hostMidpointNS: UInt64 { hostT0NS + (hostT3NS - hostT0NS) / 2 }
    var roundTripNS: UInt64 { hostT3NS - hostT0NS }
}
