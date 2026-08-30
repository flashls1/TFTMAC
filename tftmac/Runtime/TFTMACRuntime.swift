import AppKit
import CryptoKit
import Darwin
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import SQLite3
import SwiftProtobuf

struct TFTMACRuntimePaths: Sendable {
    let sdkRoot: URL
    let emulator: URL
    let adb: URL
    let avdHome: URL
    let avdDirectory: URL
    let avdConfig: URL
    let hostApplication: URL
    let applicationSupport: URL

    static func discover() throws -> Self {
        let manager = FileManager.default
        let runtimeRoot = URL(fileURLWithPath: "/Volumes/MAC MINI M4/TFTMAC/Runtime", isDirectory: true)
        let sdkCandidates = ["SDK", "sdk"].map { runtimeRoot.appendingPathComponent($0, isDirectory: true) }
        guard let sdkRoot = sdkCandidates.first(where: {
            manager.isExecutableFile(atPath: $0.appendingPathComponent("emulator/emulator").path)
                && manager.isExecutableFile(atPath: $0.appendingPathComponent("platform-tools/adb").path)
        }) else {
            throw TFTMACRuntimeError("The proven Android runtime is not mounted at /Volumes/MAC MINI M4/TFTMAC/Runtime.")
        }

        let avdCandidates = ["AVD", "avd"].map { runtimeRoot.appendingPathComponent($0, isDirectory: true) }
        guard let avdHome = avdCandidates.first(where: {
            manager.fileExists(atPath: $0.appendingPathComponent("TFT_Ultra_Tablet.ini").path)
        }) else {
            throw TFTMACRuntimeError("The TFT_Ultra_Tablet AVD is missing from the proven runtime.")
        }
        let avdINI = avdHome.appendingPathComponent("TFT_Ultra_Tablet.ini")
        let iniText = try String(contentsOf: avdINI, encoding: .utf8)
        guard let avdPath = iniText.split(whereSeparator: \.isNewline)
            .first(where: { $0.hasPrefix("path=") })?
            .dropFirst("path=".count), !avdPath.isEmpty else {
            throw TFTMACRuntimeError("TFT_Ultra_Tablet.ini does not identify its AVD directory.")
        }
        let avdDirectory = URL(fileURLWithPath: String(avdPath), isDirectory: true)
        let avdConfig = avdDirectory.appendingPathComponent("config.ini")
        guard manager.fileExists(atPath: avdConfig.path) else {
            throw TFTMACRuntimeError("The TFT_Ultra_Tablet config.ini is missing.")
        }

        guard let resourceURL = Bundle.main.resourceURL else {
            throw TFTMACRuntimeError("TFTMAC.app has no Resources directory.")
        }
        let hostApplication = resourceURL.appendingPathComponent("TFTMAC Emulator Host.app", isDirectory: true)
        guard manager.fileExists(atPath: hostApplication.path) else {
            throw TFTMACRuntimeError("TFTMAC Emulator Host.app is missing from the application bundle.")
        }
        let applicationSupport = manager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TFTMAC", isDirectory: true)
        return Self(
            sdkRoot: sdkRoot,
            emulator: sdkRoot.appendingPathComponent("emulator/emulator"),
            adb: sdkRoot.appendingPathComponent("platform-tools/adb"),
            avdHome: avdHome,
            avdDirectory: avdDirectory,
            avdConfig: avdConfig,
            hostApplication: hostApplication,
            applicationSupport: applicationSupport
        )
    }
}

struct EmulatorControllerDiscovery: Sendable {
    let processIdentifier: Int32
    let port: Int
    let token: String
    let recordPath: String
}

struct MouseInput: Sendable {
    let x: Int32
    let y: Int32
    let buttons: Int32
}

struct KeyboardInput: Sendable {
    let text: String?
    let key: String?
}

private enum EmulatorInput: Sendable {
    case mouse(MouseInput)
    case keyboard(KeyboardInput)
}

struct PresentationSample: Sendable {
    let presentedFrames: UInt64
    let presentationFPS: Double
    let sourceFPS: Double
    let mailbox: FrameMailboxSnapshot
    let lastPresentedSequence: UInt32?
    let sampledMonotonicNanoseconds: UInt64
}

private struct FrameVisualSample: Sendable {
    let sampleCount: Int
    let meanLuma: Double
    let nonBlackFraction: Double
    let minimumRGB: Int
    let maximumRGB: Int
    let minimumAlpha: Int
    let maximumAlpha: Int
    let contentSHA256: String?
}

private struct FrameIntervalWindow: Sendable {
    let startedMonotonicNS: UInt64
    let endedMonotonicNS: UInt64
    let frameCount: Int
    let sequenceDropCount: UInt64
    let meanIntervalMS: Double?
    let p95IntervalMS: Double?
    let maximumIntervalMS: Double?
}

private struct GuestMemorySample: Sendable {
    let totalKiB: Int64
    let availableKiB: Int64
    let swapTotalKiB: Int64?
    let swapFreeKiB: Int64?
}

private struct SurfaceFlingerSample: Sendable {
    let renderRateHz: Double?
    let totalMissedFrames: Int64?
    let hwcMissedFrames: Int64?
    let gpuMissedFrames: Int64?
    let tftRequestedRateHz: Double?
}

private struct AudioFlingerSample: Sendable {
    let activeOutput: Bool
    let sampleRateHz: Int?
    let stereoOutput: Bool
    let activeTracks: Int?
    let partialUnderruns: Int64?
    let emptyUnderruns: Int64?
}

private struct LogcatAggregate: Sendable {
    let byteStart: UInt64
    let byteEnd: UInt64
    let skippedBytes: UInt64
    let lineCount: Int
    let anrCount: Int
    let inputTimeoutCount: Int
    let fatalCount: Int
    let memoryKillCount: Int
    let choreographerSkipCount: Int
    let angleWarningCount: Int
    let vulkanWarningCount: Int
    let audioErrorCount: Int
}

struct TFTMACRuntimeError: LocalizedError, Sendable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private enum SQLiteValue: Sendable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case null
}

final class TFTMACNativeTelemetry: @unchecked Sendable {
    let sessionIdentifier: String
    let captureDirectory: URL

    private let queue = DispatchQueue(label: "com.flashls1.tftmac.telemetry")
    private var database: OpaquePointer?
    private var eventLog: FileHandle?
    private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(profile: TFTMACRuntimeProfile, applicationSupport: URL) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        sessionIdentifier = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-") + "-" + UUID().uuidString.lowercased()
        captureDirectory = applicationSupport.appendingPathComponent("Captures/\(sessionIdentifier)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: captureDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let logURL = captureDirectory.appendingPathComponent("native-events.jsonl")
        FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        eventLog = try FileHandle(forWritingTo: logURL)

        let databaseURL = captureDirectory.appendingPathComponent("TFTMAC_NATIVE_RUNTIME.sqlite")
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            throw TFTMACRuntimeError("The native SQL telemetry database could not be opened.")
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: databaseURL.path)
        try executeSchema()
        try execute(
            "INSERT INTO sessions(session_id, started_utc, status, profile_id) VALUES(?, ?, 'STARTING', ?)",
            [.text(sessionIdentifier), .text(Self.utcNow()), .text(profile.identifier)]
        )
        recordEvent("LOGGER_INITIALIZED", payload: [
            "database": databaseURL.lastPathComponent,
            "rawEventLog": logURL.lastPathComponent,
            "loggerStartsBeforeEmulator": true
        ])
    }

    deinit {
        queue.sync {
            try? eventLog?.close()
            if let database { sqlite3_close(database) }
            database = nil
        }
    }

    func recordReceipt(key: String, value: String, source: String, confidence: String) {
        enqueue {
            try self.execute(
                "INSERT INTO runtime_receipts(session_id, receipt_key, receipt_value, source, confidence, observed_utc) VALUES(?, ?, ?, ?, ?, ?)",
                [.text(self.sessionIdentifier), .text(key), .text(value), .text(source), .text(confidence), .text(Self.utcNow())]
            )
        }
    }

    func markRunning() {
        enqueue {
            try self.execute(
                "UPDATE sessions SET status = 'RUNNING' WHERE session_id = ? AND ended_utc IS NULL",
                [.text(self.sessionIdentifier)]
            )
        }
    }

    func recordEvent(_ kind: String, payload: [String: Any] = [:]) {
        let payloadText = Self.json(payload)
        let utc = Self.utcNow()
        let monotonic = DispatchTime.now().uptimeNanoseconds
        let lineData = Data((Self.json([
            "session_id": sessionIdentifier,
            "observed_utc": utc,
            "monotonic_ns": String(monotonic),
            "kind": kind,
            "payload": payload
        ]) + "\n").utf8)
        enqueue {
            try self.execute(
                "INSERT INTO events(session_id, observed_utc, monotonic_ns, kind, payload_json) VALUES(?, ?, ?, ?, ?)",
                [.text(self.sessionIdentifier), .text(utc), .integer(Int64(bitPattern: monotonic)), .text(kind), .text(payloadText)]
            )
            try self.eventLog?.write(contentsOf: lineData)
        }
    }

    fileprivate func recordFrameReceived(
        _ frame: EmulatorFrame,
        transport: String,
        sequenceDropCount: UInt64,
        visual: FrameVisualSample
    ) {
        enqueue {
            try self.execute(
                "INSERT INTO frame_samples(session_id, sequence, emulator_timestamp_us, received_monotonic_ns, width, height, byte_count, transport, sequence_drop_count, visual_sample_count, mean_luma, nonblack_fraction, minimum_rgb, maximum_rgb, minimum_alpha, maximum_alpha, content_sha256) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier), .integer(Int64(frame.sequence)),
                    .integer(Int64(bitPattern: frame.emulatorTimestampMicroseconds)),
                    .integer(Int64(bitPattern: frame.receivedMonotonicNanoseconds)),
                    .integer(Int64(frame.width)), .integer(Int64(frame.height)),
                    .integer(Int64(frame.pixels.count)), .text(transport),
                    .integer(Int64(bitPattern: sequenceDropCount)),
                    .integer(Int64(visual.sampleCount)), .real(visual.meanLuma),
                    .real(visual.nonBlackFraction), .integer(Int64(visual.minimumRGB)),
                    .integer(Int64(visual.maximumRGB)), .integer(Int64(visual.minimumAlpha)),
                    .integer(Int64(visual.maximumAlpha)), visual.contentSHA256.map(SQLiteValue.text) ?? .null
                ]
            )
        }
    }

    fileprivate func recordFrameIntervalWindow(_ sample: FrameIntervalWindow) {
        enqueue {
            try self.execute(
                "INSERT INTO frame_interval_windows(session_id, started_monotonic_ns, ended_monotonic_ns, frame_count, sequence_drop_count, mean_interval_ms, p95_interval_ms, maximum_interval_ms) VALUES(?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier),
                    .integer(Int64(bitPattern: sample.startedMonotonicNS)),
                    .integer(Int64(bitPattern: sample.endedMonotonicNS)),
                    .integer(Int64(sample.frameCount)),
                    .integer(Int64(bitPattern: sample.sequenceDropCount)),
                    sample.meanIntervalMS.map(SQLiteValue.real) ?? .null,
                    sample.p95IntervalMS.map(SQLiteValue.real) ?? .null,
                    sample.maximumIntervalMS.map(SQLiteValue.real) ?? .null
                ]
            )
        }
    }

    func recordPresentation(_ sample: PresentationSample) {
        enqueue {
            try self.execute(
                "INSERT INTO presentation_samples(session_id, sampled_monotonic_ns, presented_frames, presentation_fps, source_fps, received_frames, mailbox_replacements, sequence_drops, last_sequence) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier), .integer(Int64(bitPattern: sample.sampledMonotonicNanoseconds)),
                    .integer(Int64(bitPattern: sample.presentedFrames)), .real(sample.presentationFPS), .real(sample.sourceFPS),
                    .integer(Int64(bitPattern: sample.mailbox.receivedFrames)),
                    .integer(Int64(bitPattern: sample.mailbox.replacedBeforePresentation)),
                    .integer(Int64(bitPattern: sample.mailbox.sequenceDrops)),
                    sample.lastPresentedSequence.map { .integer(Int64($0)) } ?? .null
                ]
            )
        }
    }

    func recordResourceSample(emulatorPID: Int32, emulatorCPU: Double?, emulatorRSSKiB: Int64?, gamePID: Int32?, topActivity: String) {
        enqueue {
            try self.execute(
                "INSERT INTO resource_samples(session_id, observed_utc, monotonic_ns, emulator_pid, emulator_cpu_percent, emulator_rss_kib, game_pid, top_activity) VALUES(?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier), .text(Self.utcNow()),
                    .integer(Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)),
                    .integer(Int64(emulatorPID)), emulatorCPU.map(SQLiteValue.real) ?? .null,
                    emulatorRSSKiB.map(SQLiteValue.integer) ?? .null,
                    gamePID.map { .integer(Int64($0)) } ?? .null, .text(topActivity)
                ]
            )
        }
    }

    fileprivate func recordGuestMemory(_ sample: GuestMemorySample) {
        enqueue {
            try self.execute(
                "INSERT INTO guest_memory_samples(session_id, observed_utc, monotonic_ns, total_kib, available_kib, swap_total_kib, swap_free_kib) VALUES(?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier), .text(Self.utcNow()),
                    .integer(Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)),
                    .integer(sample.totalKiB), .integer(sample.availableKiB),
                    sample.swapTotalKiB.map(SQLiteValue.integer) ?? .null,
                    sample.swapFreeKiB.map(SQLiteValue.integer) ?? .null
                ]
            )
        }
    }

    fileprivate func recordClockSync(hostT0NS: UInt64, guestUptimeNS: UInt64, hostT1NS: UInt64) {
        let midpoint = hostT0NS &+ ((hostT1NS &- hostT0NS) / 2)
        enqueue {
            try self.execute(
                "INSERT INTO clock_sync_samples(session_id, observed_utc, host_t0_ns, guest_uptime_ns, host_t1_ns, host_midpoint_ns, round_trip_ns, host_minus_guest_ns) VALUES(?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier), .text(Self.utcNow()),
                    .integer(Int64(bitPattern: hostT0NS)), .integer(Int64(bitPattern: guestUptimeNS)),
                    .integer(Int64(bitPattern: hostT1NS)), .integer(Int64(bitPattern: midpoint)),
                    .integer(Int64(bitPattern: hostT1NS &- hostT0NS)),
                    .integer(Int64(bitPattern: midpoint &- guestUptimeNS))
                ]
            )
        }
    }

    fileprivate func recordSurfaceFlinger(_ sample: SurfaceFlingerSample, label: String) {
        enqueue {
            try self.execute(
                "INSERT INTO surfaceflinger_samples(session_id, observed_utc, monotonic_ns, sample_label, render_rate_hz, total_missed_frames, hwc_missed_frames, gpu_missed_frames, tft_requested_rate_hz) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier), .text(Self.utcNow()),
                    .integer(Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)), .text(label),
                    sample.renderRateHz.map(SQLiteValue.real) ?? .null,
                    sample.totalMissedFrames.map(SQLiteValue.integer) ?? .null,
                    sample.hwcMissedFrames.map(SQLiteValue.integer) ?? .null,
                    sample.gpuMissedFrames.map(SQLiteValue.integer) ?? .null,
                    sample.tftRequestedRateHz.map(SQLiteValue.real) ?? .null
                ]
            )
        }
    }

    fileprivate func recordAudioFlinger(_ sample: AudioFlingerSample, label: String) {
        enqueue {
            try self.execute(
                "INSERT INTO audio_samples(session_id, observed_utc, monotonic_ns, sample_label, backend, active_output, sample_rate_hz, stereo_output, active_tracks, partial_underruns, empty_underruns) VALUES(?, ?, ?, ?, 'coreaudio', ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier), .text(Self.utcNow()),
                    .integer(Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)), .text(label),
                    .integer(sample.activeOutput ? 1 : 0),
                    sample.sampleRateHz.map { .integer(Int64($0)) } ?? .null,
                    .integer(sample.stereoOutput ? 1 : 0),
                    sample.activeTracks.map { .integer(Int64($0)) } ?? .null,
                    sample.partialUnderruns.map(SQLiteValue.integer) ?? .null,
                    sample.emptyUnderruns.map(SQLiteValue.integer) ?? .null
                ]
            )
        }
    }

    fileprivate func recordLogcatAggregate(_ sample: LogcatAggregate) {
        enqueue {
            try self.execute(
                "INSERT INTO logcat_aggregates(session_id, observed_utc, monotonic_ns, byte_start, byte_end, skipped_bytes, line_count, anr_count, input_timeout_count, fatal_count, memory_kill_count, choreographer_skip_count, angle_warning_count, vulkan_warning_count, audio_error_count) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(self.sessionIdentifier), .text(Self.utcNow()),
                    .integer(Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)),
                    .integer(Int64(bitPattern: sample.byteStart)), .integer(Int64(bitPattern: sample.byteEnd)),
                    .integer(Int64(bitPattern: sample.skippedBytes)), .integer(Int64(sample.lineCount)),
                    .integer(Int64(sample.anrCount)), .integer(Int64(sample.inputTimeoutCount)),
                    .integer(Int64(sample.fatalCount)), .integer(Int64(sample.memoryKillCount)),
                    .integer(Int64(sample.choreographerSkipCount)), .integer(Int64(sample.angleWarningCount)),
                    .integer(Int64(sample.vulkanWarningCount)), .integer(Int64(sample.audioErrorCount))
                ]
            )
        }
    }

    func recordGameProcessTransition(previousPID: Int32?, currentPID: Int32?) {
        enqueue {
            let now = Self.utcNow()
            let monotonic = Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)
            if let previousPID {
                try self.execute(
                    "UPDATE game_process_sessions SET ended_utc = ?, ended_monotonic_ns = ? WHERE session_id = ? AND game_pid = ? AND ended_utc IS NULL",
                    [.text(now), .integer(monotonic), .text(self.sessionIdentifier), .integer(Int64(previousPID))]
                )
            }
            if let currentPID {
                try self.execute(
                    "INSERT INTO game_process_sessions(session_id, game_pid, started_utc, started_monotonic_ns) VALUES(?, ?, ?, ?)",
                    [.text(self.sessionIdentifier), .integer(Int64(currentPID)), .text(now), .integer(monotonic)]
                )
            }
        }
    }

    fileprivate func recordInput(_ input: EmulatorInput) {
        let values: [SQLiteValue]
        switch input {
        case .mouse(let mouse):
            values = [
                .text(sessionIdentifier), .integer(Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)),
                .text("mouse"), .integer(Int64(mouse.x)), .integer(Int64(mouse.y)),
                .integer(Int64(mouse.buttons)), .null, .null
            ]
        case .keyboard(let keyboard):
            values = [
                .text(sessionIdentifier), .integer(Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)),
                .text("keyboard"), .null, .null, .null,
                keyboard.text.map { .integer(Int64($0.count)) } ?? .null,
                keyboard.key.map(SQLiteValue.text) ?? .null
            ]
        }
        enqueue {
            try self.execute(
                "INSERT INTO input_samples(session_id, monotonic_ns, input_kind, x, y, buttons, character_count, special_key) VALUES(?, ?, ?, ?, ?, ?, ?, ?)",
                values
            )
        }
    }

    func finish(status: String) {
        queue.sync {
            let now = Self.utcNow()
            let monotonic = Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)
            try? self.execute(
                "UPDATE game_process_sessions SET ended_utc = ?, ended_monotonic_ns = ? WHERE session_id = ? AND ended_utc IS NULL",
                [.text(now), .integer(monotonic), .text(self.sessionIdentifier)]
            )
            try? self.execute(
                "UPDATE sessions SET ended_utc = ?, status = ? WHERE session_id = ?",
                [.text(now), .text(status), .text(self.sessionIdentifier)]
            )
            try? self.eventLog?.synchronize()
        }
    }

    private func executeSchema() throws {
        let schema = """
        PRAGMA journal_mode=WAL;
        PRAGMA synchronous=NORMAL;
        PRAGMA foreign_keys=ON;
        CREATE TABLE IF NOT EXISTS sessions(
          session_id TEXT PRIMARY KEY,
          started_utc TEXT NOT NULL,
          ended_utc TEXT,
          status TEXT NOT NULL,
          profile_id TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS runtime_receipts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          receipt_key TEXT NOT NULL,
          receipt_value TEXT NOT NULL,
          source TEXT NOT NULL,
          confidence TEXT NOT NULL,
          observed_utc TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS events(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          observed_utc TEXT NOT NULL,
          monotonic_ns INTEGER NOT NULL,
          kind TEXT NOT NULL,
          payload_json TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS frame_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          sequence INTEGER NOT NULL,
          emulator_timestamp_us INTEGER NOT NULL,
          received_monotonic_ns INTEGER NOT NULL,
          width INTEGER NOT NULL,
          height INTEGER NOT NULL,
          byte_count INTEGER NOT NULL,
          transport TEXT NOT NULL,
          sequence_drop_count INTEGER NOT NULL,
          visual_sample_count INTEGER NOT NULL,
          mean_luma REAL NOT NULL,
          nonblack_fraction REAL NOT NULL,
          minimum_rgb INTEGER NOT NULL,
          maximum_rgb INTEGER NOT NULL,
          minimum_alpha INTEGER NOT NULL,
          maximum_alpha INTEGER NOT NULL,
          content_sha256 TEXT
        );
        CREATE TABLE IF NOT EXISTS presentation_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          sampled_monotonic_ns INTEGER NOT NULL,
          presented_frames INTEGER NOT NULL,
          presentation_fps REAL NOT NULL,
          source_fps REAL NOT NULL,
          received_frames INTEGER NOT NULL,
          mailbox_replacements INTEGER NOT NULL,
          sequence_drops INTEGER NOT NULL,
          last_sequence INTEGER
        );
        CREATE TABLE IF NOT EXISTS frame_interval_windows(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          started_monotonic_ns INTEGER NOT NULL,
          ended_monotonic_ns INTEGER NOT NULL,
          frame_count INTEGER NOT NULL,
          sequence_drop_count INTEGER NOT NULL,
          mean_interval_ms REAL,
          p95_interval_ms REAL,
          maximum_interval_ms REAL
        );
        CREATE TABLE IF NOT EXISTS resource_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          observed_utc TEXT NOT NULL,
          monotonic_ns INTEGER NOT NULL,
          emulator_pid INTEGER NOT NULL,
          emulator_cpu_percent REAL,
          emulator_rss_kib INTEGER,
          game_pid INTEGER,
          top_activity TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS guest_memory_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          observed_utc TEXT NOT NULL,
          monotonic_ns INTEGER NOT NULL,
          total_kib INTEGER NOT NULL,
          available_kib INTEGER NOT NULL,
          swap_total_kib INTEGER,
          swap_free_kib INTEGER
        );
        CREATE TABLE IF NOT EXISTS clock_sync_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          observed_utc TEXT NOT NULL,
          host_t0_ns INTEGER NOT NULL,
          guest_uptime_ns INTEGER NOT NULL,
          host_t1_ns INTEGER NOT NULL,
          host_midpoint_ns INTEGER NOT NULL,
          round_trip_ns INTEGER NOT NULL,
          host_minus_guest_ns INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS surfaceflinger_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          observed_utc TEXT NOT NULL,
          monotonic_ns INTEGER NOT NULL,
          sample_label TEXT NOT NULL,
          render_rate_hz REAL,
          total_missed_frames INTEGER,
          hwc_missed_frames INTEGER,
          gpu_missed_frames INTEGER,
          tft_requested_rate_hz REAL
        );
        CREATE TABLE IF NOT EXISTS audio_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          observed_utc TEXT NOT NULL,
          monotonic_ns INTEGER NOT NULL,
          sample_label TEXT NOT NULL,
          backend TEXT NOT NULL,
          active_output INTEGER NOT NULL,
          sample_rate_hz INTEGER,
          stereo_output INTEGER NOT NULL,
          active_tracks INTEGER,
          partial_underruns INTEGER,
          empty_underruns INTEGER
        );
        CREATE TABLE IF NOT EXISTS logcat_aggregates(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          observed_utc TEXT NOT NULL,
          monotonic_ns INTEGER NOT NULL,
          byte_start INTEGER NOT NULL,
          byte_end INTEGER NOT NULL,
          skipped_bytes INTEGER NOT NULL,
          line_count INTEGER NOT NULL,
          anr_count INTEGER NOT NULL,
          input_timeout_count INTEGER NOT NULL,
          fatal_count INTEGER NOT NULL,
          memory_kill_count INTEGER NOT NULL,
          choreographer_skip_count INTEGER NOT NULL,
          angle_warning_count INTEGER NOT NULL,
          vulkan_warning_count INTEGER NOT NULL,
          audio_error_count INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS game_process_sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          game_pid INTEGER NOT NULL,
          started_utc TEXT NOT NULL,
          started_monotonic_ns INTEGER NOT NULL,
          ended_utc TEXT,
          ended_monotonic_ns INTEGER
        );
        CREATE TABLE IF NOT EXISTS input_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          monotonic_ns INTEGER NOT NULL,
          input_kind TEXT NOT NULL,
          x INTEGER,
          y INTEGER,
          buttons INTEGER,
          character_count INTEGER,
          special_key TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_events_kind_time ON events(kind, monotonic_ns);
        CREATE INDEX IF NOT EXISTS idx_frames_time ON frame_samples(received_monotonic_ns);
        CREATE INDEX IF NOT EXISTS idx_frame_windows_time ON frame_interval_windows(started_monotonic_ns);
        CREATE INDEX IF NOT EXISTS idx_resources_time ON resource_samples(monotonic_ns);
        CREATE INDEX IF NOT EXISTS idx_guest_memory_time ON guest_memory_samples(monotonic_ns);
        CREATE INDEX IF NOT EXISTS idx_surfaceflinger_time ON surfaceflinger_samples(monotonic_ns);
        CREATE INDEX IF NOT EXISTS idx_audio_time ON audio_samples(monotonic_ns);
        CREATE INDEX IF NOT EXISTS idx_logcat_time ON logcat_aggregates(monotonic_ns);
        CREATE INDEX IF NOT EXISTS idx_inputs_time ON input_samples(monotonic_ns);
        """
        guard sqlite3_exec(database, schema, nil, nil, nil) == SQLITE_OK else {
            throw TFTMACRuntimeError("The native SQL telemetry schema could not be created.")
        }
    }

    private func enqueue(_ operation: @escaping @Sendable () throws -> Void) {
        queue.async {
            do { try operation() }
            catch { fputs("TFTMAC telemetry error: \(error.localizedDescription)\n", stderr) }
        }
    }

    private func execute(_ sql: String, _ values: [SQLiteValue]) throws {
        guard let database else { throw TFTMACRuntimeError("The telemetry database is closed.") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw TFTMACRuntimeError("SQLite could not prepare a telemetry statement.")
        }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .integer(let value): sqlite3_bind_int64(statement, index, value)
            case .real(let value): sqlite3_bind_double(statement, index, value)
            case .text(let value): sqlite3_bind_text(statement, index, value, -1, transientDestructor)
            case .null: sqlite3_bind_null(statement, index)
            }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TFTMACRuntimeError("SQLite could not write a telemetry record.")
        }
    }

    private static func utcNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func json(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

private final class NativeFrameAdmissionState: @unchecked Sendable {
    private let lock = NSLock()
    private let mailbox: LatestFrameMailbox
    private let telemetry: TFTMACNativeTelemetry
    private var previousSequence: UInt32?
    private var admittedFirstFrame = false
    private var windowStartedNS: UInt64?
    private var previousReceivedNS: UInt64?
    private var windowFrameCount = 0
    private var windowSequenceDrops: UInt64 = 0
    private var windowIntervalsNS = [UInt64]()

    init(mailbox: LatestFrameMailbox, telemetry: TFTMACNativeTelemetry) {
        self.mailbox = mailbox
        self.telemetry = telemetry
    }

    func admit(_ image: Android_Emulation_Control_Image) throws -> Bool {
        let width = Int(image.format.width == 0 ? image.width : image.format.width)
        let height = Int(image.format.height == 0 ? image.height : image.format.height)
        guard width > 0, height > 0 else { return false }
        guard image.format.format == .rgba8888 else {
            throw TFTMACRuntimeError("The emulator returned a non-RGBA8888 frame.")
        }
        try FrameContract.validate(width: width, height: height, byteCount: image.image.count)

        let receivedNS = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        let sequenceDrops: UInt64
        if let previousSequence, image.seq > previousSequence &+ 1 {
            sequenceDrops = UInt64(image.seq - previousSequence - 1)
        } else {
            sequenceDrops = 0
        }
        previousSequence = image.seq
        let isFirstFrame = !admittedFirstFrame
        admittedFirstFrame = true
        if windowStartedNS == nil { windowStartedNS = receivedNS }
        if let previousReceivedNS { windowIntervalsNS.append(receivedNS &- previousReceivedNS) }
        previousReceivedNS = receivedNS
        windowFrameCount += 1
        windowSequenceDrops &+= sequenceDrops
        var completedWindow: FrameIntervalWindow?
        if let started = windowStartedNS, receivedNS &- started >= 1_000_000_000 {
            let sorted = windowIntervalsNS.sorted()
            let mean = sorted.isEmpty ? nil : Double(sorted.reduce(0, &+)) / Double(sorted.count) / 1_000_000
            let p95Index = sorted.isEmpty ? 0 : min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)
            completedWindow = FrameIntervalWindow(
                startedMonotonicNS: started,
                endedMonotonicNS: receivedNS,
                frameCount: windowFrameCount,
                sequenceDropCount: windowSequenceDrops,
                meanIntervalMS: mean,
                p95IntervalMS: sorted.isEmpty ? nil : Double(sorted[p95Index]) / 1_000_000,
                maximumIntervalMS: sorted.last.map { Double($0) / 1_000_000 }
            )
            windowStartedNS = receivedNS
            windowFrameCount = 0
            windowSequenceDrops = 0
            windowIntervalsNS.removeAll(keepingCapacity: true)
        }
        lock.unlock()

        let checkpoint = isFirstFrame || image.seq.isMultiple(of: 60)

        let frame = EmulatorFrame(
            pixels: image.image,
            width: width,
            height: height,
            sequence: image.seq,
            emulatorTimestampMicroseconds: image.timestampUs,
            receivedMonotonicNanoseconds: receivedNS
        )
        mailbox.publish(frame)
        if let completedWindow { telemetry.recordFrameIntervalWindow(completedWindow) }
        guard checkpoint else { return isFirstFrame }
        let visual = Self.sampleVisualContent(image.image, includeHash: true)
        telemetry.recordFrameReceived(frame, transport: "raw_grpc_rgba8888", sequenceDropCount: sequenceDrops, visual: visual)
        let visualPayload: [String: Any] = [
            "visual_sample_count": visual.sampleCount,
            "mean_luma": visual.meanLuma,
            "nonblack_fraction": visual.nonBlackFraction,
            "minimum_rgb": visual.minimumRGB,
            "maximum_rgb": visual.maximumRGB,
            "minimum_alpha": visual.minimumAlpha,
            "maximum_alpha": visual.maximumAlpha,
            "content_sha256": visual.contentSHA256 ?? NSNull()
        ]
        if isFirstFrame {
            var payload: [String: Any] = [
                "width": width, "height": height, "bytes": image.image.count,
                "sequence": image.seq, "bottom_up": true,
                "pixel_format": "RGBA8888",
                "rotation": image.format.rotation.rotation.rawValue
            ]
            payload.merge(visualPayload) { current, _ in current }
            telemetry.recordEvent("FIRST_NATIVE_FRAME", payload: payload)
        } else if checkpoint {
            var payload = visualPayload
            payload["sequence"] = image.seq
            payload["emulator_timestamp_us"] = String(image.timestampUs)
            telemetry.recordEvent("FRAME_VISUAL_CHECKPOINT", payload: payload)
        }
        return isFirstFrame
    }

    private static func sampleVisualContent(_ data: Data, includeHash: Bool) -> FrameVisualSample {
        let pixelCount = data.count / FrameContract.bytesPerPixel
        let step = max(1, pixelCount / 4096)
        var sampleCount = 0
        var lumaSum = 0.0
        var nonBlackCount = 0
        var minimumRGB = 255
        var maximumRGB = 0
        var minimumAlpha = 255
        var maximumAlpha = 0

        data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            var pixel = 0
            while pixel < pixelCount {
                let offset = pixel * FrameContract.bytesPerPixel
                let red = Int(bytes[offset])
                let green = Int(bytes[offset + 1])
                let blue = Int(bytes[offset + 2])
                let alpha = Int(bytes[offset + 3])
                minimumRGB = Swift.min(minimumRGB, Swift.min(red, Swift.min(green, blue)))
                maximumRGB = Swift.max(maximumRGB, Swift.max(red, Swift.max(green, blue)))
                minimumAlpha = min(minimumAlpha, alpha)
                maximumAlpha = max(maximumAlpha, alpha)
                lumaSum += (0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)) / 255.0
                if max(red, green, blue) > 4 { nonBlackCount += 1 }
                sampleCount += 1
                pixel += step
            }
        }

        let divisor = Double(max(sampleCount, 1))
        let digest = includeHash
            ? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            : nil
        return FrameVisualSample(
            sampleCount: sampleCount,
            meanLuma: lumaSum / divisor,
            nonBlackFraction: Double(nonBlackCount) / divisor,
            minimumRGB: minimumRGB,
            maximumRGB: maximumRGB,
            minimumAlpha: minimumAlpha,
            maximumAlpha: maximumAlpha,
            contentSHA256: digest
        )
    }
}

actor TFTMACRuntimeService {
    typealias StatusHandler = @MainActor @Sendable (String, Bool) -> Void

    private let profile: TFTMACRuntimeProfile
    private let mailbox: LatestFrameMailbox
    private let status: StatusHandler
    private var telemetry: TFTMACNativeTelemetry?
    private var paths: TFTMACRuntimePaths?
    private var openProcess: Process?
    private var logcatProcess: Process?
    private var logcatOutputHandle: FileHandle?
    private var logcatErrorHandle: FileHandle?
    private var logcatReadOffset: UInt64 = 0
    private var runtimeLease: TFTMACRuntimeLease?
    private var expectedSessionMarker: String?
    private var discovery: EmulatorControllerDiscovery?
    private var inputContinuation: AsyncStream<EmulatorInput>.Continuation?
    private var avdTransaction: AVDConfigurationTransaction?
    private var stopping = false

    init(profile: TFTMACRuntimeProfile, mailbox: LatestFrameMailbox, status: @escaping StatusHandler) {
        self.profile = profile
        self.mailbox = mailbox
        self.status = status
    }

    func run() async throws {
        let applicationSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TFTMAC", isDirectory: true)
        let telemetry = try TFTMACNativeTelemetry(profile: profile, applicationSupport: applicationSupport)
        self.telemetry = telemetry
        await status("Starting Android through the native Mac app host…", false)

        do {
            let paths = try TFTMACRuntimePaths.discover()
            self.paths = paths
            let stateRoot = paths.applicationSupport.appendingPathComponent("State", isDirectory: true)
            runtimeLease = try TFTMACRuntimeLease.acquire(stateRoot: stateRoot)
            telemetry.recordEvent("RUNTIME_LEASE_ACQUIRED", payload: [
                "lease": "State/native-runtime.lease",
                "pid": ProcessInfo.processInfo.processIdentifier,
                "exclusive": true
            ])
            try assertRuntimeUnoccupied(telemetry: telemetry)
            try recoverInterruptedAVDTransaction(paths: paths)
            recordFrozenReceipts(telemetry: telemetry, paths: paths)
            avdTransaction = try prepareAVD(paths: paths, telemetry: telemetry)
            try startADBServer(paths: paths, telemetry: telemetry)
            let launchStarted = Date()
            try launchEmulatorHost(paths: paths, telemetry: telemetry)
            let discovery = try await waitForDiscovery(paths: paths, captureDirectory: telemetry.captureDirectory, after: launchStarted)
            self.discovery = discovery
            telemetry.recordEvent("EMULATOR_CONTROLLER_DISCOVERED", payload: [
                "pid": discovery.processIdentifier,
                "grpc_port": discovery.port,
                "record": discovery.recordPath,
                "token_persisted": false
            ])

            let (inputStream, continuation) = AsyncStream.makeStream(of: EmulatorInput.self, bufferingPolicy: .bufferingNewest(256))
            inputContinuation = continuation
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { [profile, mailbox] in
                    try await Self.runController(
                        discovery: discovery,
                        profile: profile,
                        mailbox: mailbox,
                        telemetry: telemetry,
                        inputStream: inputStream,
                        status: self.status
                    )
                }
                group.addTask {
                    try await self.waitForBootAndLaunchGame(paths: paths, telemetry: telemetry)
                }
                group.addTask {
                    try await self.sampleRuntime(paths: paths, telemetry: telemetry, emulatorPID: discovery.processIdentifier)
                }
                _ = try await group.next()
                group.cancelAll()
            }
            if !stopping { throw TFTMACRuntimeError("The native emulator session ended unexpectedly.") }
        } catch {
            if stopping || error is CancellationError {
                telemetry.recordEvent("RUNTIME_STOP_REQUESTED", payload: ["reason": "application_termination"])
                await cleanup(status: "STOPPED")
                return
            }
            telemetry.recordEvent("RUNTIME_FAILED", payload: [
                "error": error.localizedDescription,
                "diagnostic": String(describing: error),
                "type": String(reflecting: type(of: error))
            ])
            await cleanup(status: stopping ? "STOPPED" : "FAILED")
            if !stopping { await status(error.localizedDescription, true) }
            throw error
        }
        await cleanup(status: "STOPPED")
    }

    func sendMouse(_ input: MouseInput) {
        telemetry?.recordInput(.mouse(input))
        inputContinuation?.yield(.mouse(input))
    }

    func sendKeyboard(_ input: KeyboardInput) {
        telemetry?.recordInput(.keyboard(input))
        inputContinuation?.yield(.keyboard(input))
    }

    func recordPresentation(_ sample: PresentationSample) {
        telemetry?.recordPresentation(sample)
    }

    func recordMarker(_ marker: String) {
        let allowed = ["MATCH_ENTRY", "COMBAT_START", "VISIBLE_STUTTER", "MATCH_END"]
        guard allowed.contains(marker) else { return }
        telemetry?.recordEvent(marker, payload: [
            "source": "native_menu",
            "profile_id": profile.identifier,
            "host_monotonic_timestamp": true
        ])
    }

    func recordSettingsChange(previous: TFTMACRuntimeProfile, next: TFTMACRuntimeProfile) {
        telemetry?.recordEvent("NEXT_LAUNCH_PROFILE_SAVED", payload: [
            "active_profile_id": profile.identifier,
            "previous_saved_profile_id": previous.identifier,
            "next_profile_id": next.identifier,
            "next_vcpu": next.vCPU,
            "next_ram_mib": next.ramMiB,
            "next_refresh_hz": next.refreshHz,
            "next_asg_draw_flush_interval": next.asgDrawFlushInterval,
            "applies_after_restart": true
        ])
    }

    func stop() async {
        guard !stopping else { return }
        stopping = true
        await status("Sealing SQL telemetry and stopping Android…", false)
        inputContinuation?.finish()
        if let paths,
           let ownedPID = discovery?.processIdentifier,
           Self.processMatchesLaunchedIdentity(ownedPID, sessionMarker: expectedSessionMarker) {
            telemetry?.recordEvent("EMULATOR_STOP_SIGNAL_SENT", payload: [
                "pid": ownedPID,
                "serial": "emulator-5582",
                "method": "adb emu kill",
                "ownership_verified": true
            ])
            _ = try? Self.runCommand(
                paths.adb,
                ["-P", "5038", "-s", "emulator-5582", "emu", "kill"],
                environment: Self.adbEnvironment(paths: paths),
                timeout: 15
            )
        }
    }

    private func cleanup(status finalStatus: String) async {
        inputContinuation?.finish()
        inputContinuation = nil
        var emulatorExitConfirmed = true
        if let paths {
            let ownedPID = discovery?.processIdentifier ?? expectedSessionMarker.flatMap(Self.findOwnedEmulatorPID)
            let ownedProcessExists = ownedPID.map(Self.processExists) ?? false
            let ownsRunningEmulator = ownedPID.map {
                ownedProcessExists && Self.processMatchesLaunchedIdentity($0, sessionMarker: expectedSessionMarker)
            } ?? false
            if ownsRunningEmulator {
                recordDiagnosticSnapshot(paths: paths, telemetry: telemetry, label: "session_end")
            }
            stopLogcatCapture()
            if let ownedPID, ownsRunningEmulator {
                _ = try? Self.runCommand(
                    paths.adb,
                    ["-P", "5038", "-s", "emulator-5582", "emu", "kill"],
                    environment: Self.adbEnvironment(paths: paths),
                    timeout: 15
                )
                emulatorExitConfirmed = await waitForOwnedEmulatorExit(ownedPID)
            } else if let ownedPID, ownedProcessExists {
                emulatorExitConfirmed = false
                telemetry?.recordEvent("EMULATOR_KILL_WITHHELD", payload: [
                    "pid": ownedPID,
                    "reason": "process no longer matches this session ownership marker"
                ])
            } else if ownedPID != nil {
                emulatorExitConfirmed = true
            }
            telemetry?.recordEvent(
                emulatorExitConfirmed ? "EMULATOR_EXIT_CONFIRMED" : "EMULATOR_EXIT_TIMEOUT",
                payload: ["pid": ownedPID ?? 0, "serial": "emulator-5582", "owned": ownsRunningEmulator]
            )
        }
        if openProcess?.isRunning == true { openProcess?.terminate() }
        openProcess = nil
        var avdRestoreConfirmed = avdTransaction == nil
        if let transaction = avdTransaction {
            do {
                guard emulatorExitConfirmed else {
                    throw TFTMACRuntimeError("AVD restore was withheld because the emulator exit was not confirmed.")
                }
                guard !Self.anyEmulatorUsingSharedAVD() else {
                    throw TFTMACRuntimeError("AVD restore was withheld because another TFT_Ultra_Tablet process is active.")
                }
                try transaction.restore()
                avdRestoreConfirmed = true
                telemetry?.recordEvent("AVD_CONFIG_RESTORED", payload: ["sha256": transaction.originalSHA256])
            } catch {
                telemetry?.recordEvent("AVD_CONFIG_RESTORE_FAILED", payload: ["error": error.localizedDescription])
            }
        }
        avdTransaction = nil
        let sealedStatus = finalStatus == "STOPPED" && emulatorExitConfirmed && avdRestoreConfirmed ? "STOPPED" : "FAILED"
        telemetry?.finish(status: sealedStatus)
        runtimeLease?.release()
        runtimeLease = nil
        await status(sealedStatus == "STOPPED" ? "TFTMAC stopped cleanly." : "TFTMAC needs attention.", sealedStatus == "FAILED")
    }

    private func startLogcatCapture(paths: TFTMACRuntimePaths, telemetry: TFTMACNativeTelemetry) throws {
        guard logcatProcess == nil else { return }
        let outputURL = telemetry.captureDirectory.appendingPathComponent("logcat.raw.txt")
        let errorURL = telemetry.captureDirectory.appendingPathComponent("logcat.stderr.log")
        let sessionStartSelector = try Self.adb(
            paths: paths,
            ["shell", "date '+%m-%d %H:%M:%S.%3N'"],
            timeout: 10
        ).output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.firstRegexText("^([0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3})$", in: sessionStartSelector) != nil else {
            throw TFTMACRuntimeError("Android did not provide a valid session boundary for local logcat capture.")
        }
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        FileManager.default.createFile(atPath: errorURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        let process = Process()
        process.executableURL = paths.adb
        process.arguments = ["-P", "5038", "-s", "emulator-5582", "logcat", "-v", "threadtime", "-T", sessionStartSelector]
        process.environment = Self.adbEnvironment(paths: paths)
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        do {
            try process.run()
        } catch {
            try? outputHandle.close()
            try? errorHandle.close()
            throw error
        }
        logcatProcess = process
        logcatOutputHandle = outputHandle
        logcatErrorHandle = errorHandle
        logcatReadOffset = 0
        telemetry.recordEvent("LOGCAT_CAPTURE_STARTED", payload: [
            "format": "threadtime",
            "raw_file": outputURL.lastPathComponent,
            "stderr_file": errorURL.lastPathComponent,
            "raw_content_local_only": true,
            "raw_content_sensitive": true,
            "raw_content_excluded_from_sql": true,
            "session_start_selector": sessionStartSelector,
            "initial_backlog_lines_requested": 0,
            "process_pid": process.processIdentifier
        ])
    }

    private func stopLogcatCapture() {
        guard let process = logcatProcess else { return }
        if process.isRunning {
            process.terminate()
            let deadline = Date().addingTimeInterval(2)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
        }
        try? logcatOutputHandle?.synchronize()
        try? logcatErrorHandle?.synchronize()
        try? logcatOutputHandle?.close()
        try? logcatErrorHandle?.close()
        telemetry?.recordEvent("LOGCAT_CAPTURE_STOPPED", payload: [
            "termination_status": process.terminationStatus,
            "final_read_offset": String(logcatReadOffset)
        ])
        logcatProcess = nil
        logcatOutputHandle = nil
        logcatErrorHandle = nil
    }

    private func waitForOwnedEmulatorExit(_ processIdentifier: Int32) async -> Bool {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if !Self.processExists(processIdentifier) { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    private func assertRuntimeUnoccupied(telemetry: TFTMACNativeTelemetry) throws {
        let processOutput = (try? Self.runCommand(
            URL(fileURLWithPath: "/bin/ps"),
            ["-axo", "pid=,command="],
            timeout: 10
        ).output) ?? ""
        let emulatorConflicts = processOutput.split(whereSeparator: \.isNewline).filter { line in
            line.contains("qemu-system-aarch64")
                && (line.contains("@TFT_Ultra_Tablet") || line.contains("-port 5582") || line.contains("-grpc 8554"))
        }
        let listenerOutput = (try? Self.runCommand(
            URL(fileURLWithPath: "/usr/sbin/lsof"),
            ["-nP", "-iTCP:5582", "-iTCP:8554", "-sTCP:LISTEN"],
            timeout: 10
        ).output) ?? ""
        let listeners = listenerOutput.split(whereSeparator: \.isNewline).dropFirst()
        guard emulatorConflicts.isEmpty && listeners.isEmpty else {
            throw TFTMACRuntimeError("The shared TFT_Ultra_Tablet runtime or ports 5582/8554 are already in use. Close the existing emulator before launching TFTMAC.")
        }
        telemetry.recordEvent("RUNTIME_OWNERSHIP_PREFLIGHT_PASSED", payload: [
            "avd": "TFT_Ultra_Tablet",
            "console_port": 5582,
            "controller_port": 8554,
            "existing_emulator_count": 0,
            "existing_listener_count": 0
        ])
    }

    private func recordFrozenReceipts(telemetry: TFTMACNativeTelemetry, paths: TFTMACRuntimePaths) {
        let receipts: [(String, String, String, String)] = [
            ("engine", "Unreal Engine", "user_locked_fact", "LOCKED"),
            ("runtime_profile_id", profile.identifier, "validated native preferences", "DIRECT"),
            ("launcher_method", "/usr/bin/open -n -W --env ... --args ...", "Mactician donor architecture", "DIRECT"),
            ("adb_server_port", "5038", "known-good donor", "DIRECT"),
            ("emulator_console_port", "5582", "known-good donor", "DIRECT"),
            ("adb_serial", "emulator-5582", "known-good donor", "DIRECT"),
            ("controller_port", "\(profile.controllerPort)", "native authenticated controller", "REQUESTED"),
            ("adb_vendor_keys", "ABSENT", "launch environment contract", "DIRECT"),
            ("avd", "TFT_Ultra_Tablet", "installed runtime", "DIRECT"),
            ("resolution", "\(profile.width)x\(profile.height)", "5 GiB gameplay evidence", "DIRECT"),
            ("density_dpi", "\(profile.densityDPI)", "5 GiB gameplay evidence", "DIRECT"),
            ("refresh_hz", "\(profile.refreshHz)", "5 GiB gameplay evidence", "DIRECT"),
            ("vcpu", "\(profile.vCPU)", "5 GiB gameplay evidence", "DIRECT"),
            ("ram_mib", "\(profile.ramMiB)", "latest retained 5 GiB runs", "STRONG"),
            ("gpu_mode", profile.gpuMode, "playable baseline", "DIRECT"),
            ("audio_backend", profile.audioBackend, "audio health receipt", "DIRECT"),
            ("graphics_transport_requested", profile.graphicsTransport, "playable baseline", "REQUESTED"),
            ("angle_enabled_requested", profile.angleEnabledFeatures, "playable baseline", "REQUESTED"),
            ("angle_disabled_requested", profile.angleDisabledFeatures, "playable baseline", "REQUESTED"),
            ("frame_transport", "raw_grpc_rgba8888", "native admission path", "DIRECT"),
            ("raw_logcat_policy", "LOCAL_SENSITIVE_SESSION_SCOPED_NOT_FOR_SHARING", "privacy contract", "LOCKED"),
            ("sdk_root", paths.sdkRoot.path, "filesystem discovery", "DIRECT")
        ]
        for receipt in receipts {
            telemetry.recordReceipt(key: receipt.0, value: receipt.1, source: receipt.2, confidence: receipt.3)
        }
    }

    private func startADBServer(paths: TFTMACRuntimePaths, telemetry: TFTMACNativeTelemetry) throws {
        let result = try Self.runCommand(
            paths.adb,
            ["-P", "5038", "start-server"],
            environment: Self.adbEnvironment(paths: paths),
            timeout: 30
        )
        guard result.status == 0 else {
            throw TFTMACRuntimeError("ADB server 5038 could not start: \(result.output.suffix(1200))")
        }
        telemetry.recordEvent("ADB_SERVER_STARTED", payload: [
            "port": 5038,
            "serial": "emulator-5582",
            "adb_vendor_keys_present": false,
            "output": result.output.suffix(2000).description
        ])
    }

    private func launchEmulatorHost(paths: TFTMACRuntimePaths, telemetry: TFTMACNativeTelemetry) throws {
        let stdout = telemetry.captureDirectory.appendingPathComponent("emulator.stdout.log")
        let stderr = telemetry.captureDirectory.appendingPathComponent("emulator.stderr.log")
        FileManager.default.createFile(atPath: stdout.path, contents: nil)
        FileManager.default.createFile(atPath: stderr.path, contents: nil)
        for root in Self.controllerDiscoveryRoots(paths: paths) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        expectedSessionMarker = "androidboot.tftmac.session=\(telemetry.sessionIdentifier)"
        var arguments = [
            "-n", "-W",
            "--env", "TFT_EMULATOR=\(paths.emulator.path)",
            "--env", "TFT_ADB_SERVER_PORT=5038",
            "--env", "ANDROID_ADB_SERVER_PORT=5038",
            "--env", "ADB_MDNS_AUTO_CONNECT=",
            "--env", "ADB_SERVER_SOCKET=",
            "--env", "ANDROID_ADB_SERVER_ADDRESS=",
            "--env", "ANDROID_SDK_ROOT=\(paths.sdkRoot.path)",
            "--env", "ANDROID_AVD_HOME=\(paths.avdHome.path)",
            "--env", "ANDROID_EMULATOR_USE_SYSTEM_LIBS=0",
            "--env", "ANGLE_FEATURE_OVERRIDES_ENABLED=\(profile.angleEnabledFeatures)",
            "--env", "ANGLE_FEATURE_OVERRIDES_DISABLED=\(profile.angleDisabledFeatures)",
            "--env", "MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS=0",
            "--env", "MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE=64",
            "--env", "MVK_CONFIG_FAST_MATH_ENABLED=1",
            "--env", "TFT_HOST_STDOUT=\(stdout.path)",
            "--env", "TFT_HOST_STDERR=\(stderr.path)",
            paths.hostApplication.path,
            "--args",
            "@TFT_Ultra_Tablet", "-id", "TFTMAC", "-port", "5582",
            "-gpu", profile.gpuMode, "-audio", profile.audioBackend,
            "-feature", "GLESDynamicVersion,Vulkan,GuestAngle,-GLPipeChecksum,VulkanBatchedDescriptorSetUpdate,AsyncComposeSupport,VirtioGpuFenceContexts",
            "-append-userspace-opt", "androidboot.opengles.version=196610",
            "-append-userspace-opt", "androidboot.tftmac.graphics_profile=tftmac",
            "-append-userspace-opt", expectedSessionMarker!,
            "-skin", "\(profile.width)x\(profile.height)",
            "-vsync-rate", "\(profile.refreshHz)",
            "-dns-server", "1.1.1.1,8.8.8.8",
            "-cores", "\(profile.vCPU)", "-memory", "\(profile.ramMiB)",
            "-no-hidpi-scaling", "-no-snapshot", "-no-metrics", "-no-boot-anim",
            "-crash-report-mode", "disabled", "-qt-hide-window",
            "-grpc", "\(profile.controllerPort)", "-grpc-use-token",
            "-idle-grpc-timeout", "300"
        ]
        if let zone = TimeZone.current.identifier.addingPercentEncoding(withAllowedCharacters: .alphanumerics), !zone.isEmpty {
            arguments += ["-timezone", TimeZone.current.identifier]
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "ADB_VENDOR_KEYS")
        process.environment = environment
        try process.run()
        openProcess = process
        telemetry.recordEvent("EMULATOR_HOST_LAUNCHED", payload: [
            "method": "/usr/bin/open",
            "flags": ["-n", "-W", "--env", "--args"],
            "host_application": paths.hostApplication.path,
            "open_pid": process.processIdentifier,
            "adb_vendor_keys_present": false,
            "controller_discovery_roots": Self.controllerDiscoveryRoots(paths: paths).map(\.path),
            "emulator_arguments": Array(arguments.suffix(from: arguments.firstIndex(of: "--args") ?? arguments.startIndex).dropFirst())
        ])
    }

    private func waitForDiscovery(paths: TFTMACRuntimePaths, captureDirectory: URL, after launchStarted: Date) async throws -> EmulatorControllerDiscovery {
        let logURL = captureDirectory.appendingPathComponent("emulator.stdout.log")
        let deadline = Date().addingTimeInterval(90)
        var candidates = [URL]()
        while Date() < deadline {
            try Task.checkCancellation()
            if let log = try? String(contentsOf: logURL, encoding: .utf8) {
                for line in log.split(whereSeparator: \.isNewline) {
                    guard let range = line.range(of: "Advertising in:") else { continue }
                    let path = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    if !path.isEmpty {
                        let candidate = URL(fileURLWithPath: path)
                        if !candidates.contains(candidate) { candidates.append(candidate) }
                    }
                }
            }
            for root in Self.controllerDiscoveryRoots(paths: paths) {
                if let files = try? FileManager.default.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for file in files where file.lastPathComponent.hasPrefix("pid_") && file.pathExtension == "ini" {
                        if !candidates.contains(file) { candidates.append(file) }
                    }
                }
            }
            for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
                let modified = try? candidate.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                guard modified == nil || modified! >= launchStarted.addingTimeInterval(-2) else { continue }
                guard let text = try? String(contentsOf: candidate, encoding: .utf8) else { continue }
                let values = Self.parseINI(text)
                guard let rawPort = values["grpc.port"], let port = Int(rawPort), port > 0,
                      let token = values["grpc.token"], !token.isEmpty else { continue }
                let name = candidate.deletingPathExtension().lastPathComponent
                let pidText = name.dropFirst("pid_".count).prefix(while: \.isNumber)
                guard let pid = Int32(pidText), Self.processMatchesLaunchedIdentity(pid, sessionMarker: expectedSessionMarker) else { continue }
                return EmulatorControllerDiscovery(processIdentifier: pid, port: port, token: token, recordPath: candidate.path)
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw TFTMACRuntimeError("The emulator did not publish its authenticated controller endpoint.")
    }

    private func waitForBootAndLaunchGame(paths: TFTMACRuntimePaths, telemetry: TFTMACNativeTelemetry) async throws {
        await status("Waiting for the proven ADB identity on emulator-5582…", false)
        var lastState = "missing"
        var previouslyLoggedState: String?
        while !stopping {
            try Task.checkCancellation()
            let result = try? Self.runCommand(
                paths.adb,
                ["-P", "5038", "-s", "emulator-5582", "get-state"],
                environment: Self.adbEnvironment(paths: paths),
                timeout: 10
            )
            let diagnostic = result?.output.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if result?.status == 0 && diagnostic == "device" {
                lastState = "device"
            } else if diagnostic.localizedCaseInsensitiveContains("unauthorized") {
                lastState = "unauthorized"
            } else if diagnostic.localizedCaseInsensitiveContains("offline") {
                lastState = "offline"
            } else {
                lastState = "missing"
            }
            if lastState != previouslyLoggedState {
                telemetry.recordEvent("ADB_STATE_CHANGED", payload: [
                    "previous_state": previouslyLoggedState ?? "none",
                    "current_state": lastState,
                    "serial": "emulator-5582",
                    "diagnostic": String(diagnostic.prefix(800))
                ])
                if lastState == "unauthorized" {
                    telemetry.recordEvent("ADB_UNAUTHORIZED_OBSERVED", payload: [
                        "serial": "emulator-5582",
                        "authorization_is_user_controlled": true
                    ])
                    await status("ADB authorization required — press Fn-F12 if Android is asleep, unlock it, then choose Always allow and Allow.", false)
                } else if lastState == "offline" {
                    await status("Android is booting; ADB is temporarily offline…", false)
                } else if lastState == "missing" {
                    await status("Waiting for emulator-5582 to appear on ADB 5038…", false)
                }
                previouslyLoggedState = lastState
            }
            if lastState == "device" { break }
            try await Task.sleep(for: .seconds(1))
        }
        try Task.checkCancellation()
        guard lastState == "device" else {
            throw TFTMACRuntimeError("ADB emulator-5582 did not authorize in the logged-in Mac session (last state: \(lastState)).")
        }
        telemetry.recordEvent("ADB_DEVICE_AUTHORIZED", payload: ["port": 5038, "serial": "emulator-5582"])
        try startLogcatCapture(paths: paths, telemetry: telemetry)

        let bootDeadline = Date().addingTimeInterval(300)
        var bootCompleted = false
        while Date() < bootDeadline {
            try Task.checkCancellation()
            let booted = try Self.adb(paths: paths, ["shell", "getprop", "sys.boot_completed"], timeout: 10).output
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if booted == "1" {
                bootCompleted = true
                break
            }
            try await Task.sleep(for: .seconds(1))
        }
        guard bootCompleted else {
            throw TFTMACRuntimeError("Android did not finish booting before the five-minute deadline.")
        }
        _ = try? Self.adb(paths: paths, ["shell", "input", "keyevent", "KEYCODE_WAKEUP"], timeout: 10)
        _ = try? Self.adb(paths: paths, ["shell", "settings", "put", "global", "stay_on_while_plugged_in", "7"], timeout: 10)
        var manualUnlockRequired = false
        while !stopping {
            try Task.checkCancellation()
            let user = try Self.adb(paths: paths, ["shell", "dumpsys", "user"], timeout: 15).output
            if user.contains("RUNNING_UNLOCKED") { break }
            if !manualUnlockRequired {
                manualUnlockRequired = true
                telemetry.recordEvent("GUEST_SECURE_UNLOCK_REQUIRED", payload: [
                    "user": 0,
                    "pin_entry": "manual_only",
                    "credential_logged": false
                ])
                await status("Android is securely locked. Click here, type your Android PIN, then press Return. TFTMAC never stores it.", false)
            }
            try await Task.sleep(for: .seconds(1))
        }
        try Task.checkCancellation()
        telemetry.recordEvent("GUEST_UNLOCKED", payload: [
            "user": 0,
            "manual_unlock_was_required": manualUnlockRequired
        ])
        let package = "com.riotgames.league.teamfighttactics"
        let packageDump = try Self.adb(paths: paths, ["shell", "dumpsys", "package", package], timeout: 30).output
        guard packageDump.contains("Package [\(package)]") || packageDump.contains("versionName=") else {
            throw TFTMACRuntimeError("Official TFT is not installed. Open Google Play in Android and install Teamfight Tactics.")
        }
        let installer = try? Self.adb(paths: paths, ["shell", "cmd", "package", "get-install-source", package], timeout: 15).output
        telemetry.recordEvent("OFFICIAL_TFT_PACKAGE_RECEIPT", payload: [
            "package": package,
            "installer_output": installer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown",
            "version_line": packageDump.split(whereSeparator: \.isNewline).first(where: { $0.contains("versionName=") }).map(String.init) ?? "unknown"
        ])
        try await Task.sleep(for: .milliseconds(750))
        guard logcatProcess?.isRunning == true,
              Self.fileSize(telemetry.captureDirectory.appendingPathComponent("logcat.raw.txt")) > 0 else {
            throw TFTMACRuntimeError("The required local logcat recorder did not become healthy before TFT launch.")
        }
        telemetry.recordEvent("LOGGER_HEALTH_GATE_PASSED", payload: [
            "logcat_growing": true,
            "resource_sampler_active": true,
            "sql_database": "TFTMAC_NATIVE_RUNTIME.sqlite"
        ])
        recordDiagnosticSnapshot(paths: paths, telemetry: telemetry, label: "before_tft_launch")

        let resolved = try? Self.adb(
            paths: paths,
            ["shell", "cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", package],
            timeout: 20
        ).output.split(whereSeparator: \.isNewline).last.map(String.init)
        var launched = false
        for component in [resolved, "\(package)/com.epicgames.unreal.SplashActivity", "\(package)/com.epicgames.unreal.GameActivity"].compactMap({ $0 }) {
            let result = try? Self.adb(paths: paths, ["shell", "am", "start", "-W", "-n", component], timeout: 45)
            if result?.status == 0 {
                launched = true
                telemetry.recordEvent("TFT_LAUNCH_REQUESTED", payload: ["component": component])
                break
            }
        }
        guard launched else { throw TFTMACRuntimeError("Android could not launch the official TFT activity.") }
        telemetry.recordEvent("TFT_READY_FOR_USER", payload: [
            "engine": "Unreal Engine",
            "resolution": "1920x1080",
            "refresh_hz": profile.refreshHz,
            "audio_backend": "coreaudio",
            "profile_id": profile.identifier
        ])
        telemetry.markRunning()
        await status("", false)
        while !stopping {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(1))
        }
    }

    private func sampleRuntime(paths: TFTMACRuntimePaths, telemetry: TFTMACNativeTelemetry, emulatorPID: Int32) async throws {
        var previousGamePID: Int32?
        var sampleIndex = 0
        while !stopping {
            try Task.checkCancellation()
            let ps = try? Self.runCommand(
                URL(fileURLWithPath: "/bin/ps"),
                ["-o", "%cpu=,rss=", "-p", "\(emulatorPID)"],
                timeout: 10
            ).output.trimmingCharacters(in: .whitespacesAndNewlines)
            let pieces = ps?.split(whereSeparator: \.isWhitespace) ?? []
            let cpu = pieces.first.flatMap { Double($0) }
            let rss = pieces.dropFirst().first.flatMap { Int64($0) }
            let pidText = try? Self.adb(paths: paths, ["shell", "pidof", "com.riotgames.league.teamfighttactics"], timeout: 10).output
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let gamePID = pidText?.split(separator: " ").first.flatMap { Int32($0) }
            let activity = try? Self.adb(paths: paths, ["shell", "dumpsys", "activity", "activities"], timeout: 15).output
                .split(whereSeparator: \.isNewline)
                .first(where: { $0.contains("mResumedActivity") || $0.contains("topResumedActivity") })
                .map(String.init) ?? "unknown"
            telemetry.recordResourceSample(
                emulatorPID: emulatorPID,
                emulatorCPU: cpu,
                emulatorRSSKiB: rss,
                gamePID: gamePID,
                topActivity: activity ?? "unknown"
            )
            if let memoryOutput = try? Self.adb(paths: paths, ["shell", "cat", "/proc/meminfo"], timeout: 10).output,
               let memory = Self.parseGuestMemory(memoryOutput) {
                telemetry.recordGuestMemory(memory)
            }
            let logcatURL = telemetry.captureDirectory.appendingPathComponent("logcat.raw.txt")
            if let aggregate = Self.readLogcatAggregate(url: logcatURL, from: &logcatReadOffset) {
                telemetry.recordLogcatAggregate(aggregate)
            }
            if gamePID != previousGamePID {
                let previousValue: Any = previousGamePID.map { NSNumber(value: $0) } ?? NSNull()
                let currentValue: Any = gamePID.map { NSNumber(value: $0) } ?? NSNull()
                telemetry.recordEvent(gamePID == nil ? "TFT_PROCESS_ENDED" : "TFT_PROCESS_STARTED", payload: [
                    "previous_pid": previousValue,
                    "current_pid": currentValue
                ])
                telemetry.recordGameProcessTransition(previousPID: previousGamePID, currentPID: gamePID)
                previousGamePID = gamePID
            }
            if sampleIndex.isMultiple(of: 6) {
                recordClockSync(paths: paths, telemetry: telemetry)
                if gamePID != nil {
                    recordDiagnosticSnapshot(paths: paths, telemetry: telemetry, label: "gameplay_periodic")
                }
            }
            sampleIndex += 1
            try await Task.sleep(for: .seconds(5))
        }
    }

    private func recordClockSync(paths: TFTMACRuntimePaths, telemetry: TFTMACNativeTelemetry) {
        let hostT0 = DispatchTime.now().uptimeNanoseconds
        guard let output = try? Self.adb(paths: paths, ["shell", "cat", "/proc/uptime"], timeout: 10).output,
              let seconds = output.split(whereSeparator: \.isWhitespace).first.flatMap({ Double($0) }) else { return }
        let hostT1 = DispatchTime.now().uptimeNanoseconds
        let guestNS = UInt64(max(0, seconds) * 1_000_000_000)
        telemetry.recordClockSync(hostT0NS: hostT0, guestUptimeNS: guestNS, hostT1NS: hostT1)
    }

    private func recordDiagnosticSnapshot(paths: TFTMACRuntimePaths, telemetry: TFTMACNativeTelemetry?, label: String) {
        guard let telemetry else { return }
        if let output = try? Self.adb(paths: paths, ["shell", "dumpsys", "SurfaceFlinger"], timeout: 20).output,
           let sample = Self.parseSurfaceFlinger(output) {
            telemetry.recordSurfaceFlinger(sample, label: label)
        }
        if let output = try? Self.adb(paths: paths, ["shell", "dumpsys", "media.audio_flinger"], timeout: 20).output,
           let sample = Self.parseAudioFlinger(output) {
            telemetry.recordAudioFlinger(sample, label: label)
        }
    }

    nonisolated private static func fileSize(_ url: URL) -> UInt64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return 0 }
        return size.uint64Value
    }

    nonisolated private static func parseGuestMemory(_ output: String) -> GuestMemorySample? {
        var values = [String: Int64]()
        for line in output.split(whereSeparator: \.isNewline) {
            let pair = line.split(separator: ":", maxSplits: 1)
            guard pair.count == 2,
                  let value = pair[1].split(whereSeparator: \.isWhitespace).first.flatMap({ Int64($0) }) else { continue }
            values[String(pair[0])] = value
        }
        guard let total = values["MemTotal"], let available = values["MemAvailable"] ?? values["MemFree"] else { return nil }
        return GuestMemorySample(
            totalKiB: total,
            availableKiB: available,
            swapTotalKiB: values["SwapTotal"],
            swapFreeKiB: values["SwapFree"]
        )
    }

    nonisolated private static func parseSurfaceFlinger(_ output: String) -> SurfaceFlingerSample? {
        let renderRate = firstRegexDouble("renderRate=([0-9.]+)\\s*Hz", in: output)
        let totalMissed = firstRegexInt("Total missed frame count:\\s*([0-9]+)", in: output)
        let hwcMissed = firstRegexInt("HWC missed frame count:\\s*([0-9]+)", in: output)
        let gpuMissed = firstRegexInt("GPU missed frame count:\\s*([0-9]+)", in: output)
        let requestedRates = regexDoubles(
            "com\\.riotgames\\.league\\.teamfighttactics[^\\n]*requestedFrameRate:\\s*\\{([0-9.]+)\\s*Hz",
            in: output
        )
        guard renderRate != nil || totalMissed != nil || hwcMissed != nil || gpuMissed != nil else { return nil }
        return SurfaceFlingerSample(
            renderRateHz: renderRate,
            totalMissedFrames: totalMissed,
            hwcMissedFrames: hwcMissed,
            gpuMissedFrames: gpuMissed,
            tftRequestedRateHz: requestedRates.max()
        )
    }

    nonisolated private static func parseAudioFlinger(_ output: String) -> AudioFlingerSample? {
        let chunks = output.components(separatedBy: "Output thread ")
        guard let activeChunk = chunks.first(where: { $0.contains("Standby: no") }) else {
            return output.contains("Output thread ")
                ? AudioFlingerSample(
                    activeOutput: false, sampleRateHz: nil, stereoOutput: false,
                    activeTracks: 0, partialUnderruns: nil, emptyUnderruns: nil
                )
                : nil
        }
        let sampleRate = firstRegexInt("Sample rate:\\s*([0-9]+)\\s*Hz", in: activeChunk).map(Int.init)
        let channelText = firstRegexText("Channel mask:[^\\n]*\\(([^)]*)\\)", in: activeChunk)?.lowercased() ?? ""
        let stereo = (channelText.contains("front-left") && channelText.contains("front-right"))
            || (channelText.contains("left") && channelText.contains("right"))
        let activeTracks = firstRegexInt("[0-9]+ Tracks of which ([0-9]+) are active", in: activeChunk).map(Int.init)
        return AudioFlingerSample(
            activeOutput: true,
            sampleRateHz: sampleRate,
            stereoOutput: stereo,
            activeTracks: activeTracks,
            partialUnderruns: firstRegexInt("underrun counters:\\s*partial=([0-9]+)", in: activeChunk),
            emptyUnderruns: firstRegexInt("underrun counters:[^\\n]*empty=([0-9]+)", in: activeChunk)
        )
    }

    nonisolated private static func readLogcatAggregate(url: URL, from offset: inout UInt64) -> LogcatAggregate? {
        let end = fileSize(url)
        guard end > offset else { return nil }
        let maximumReadBytes: UInt64 = 4 * 1024 * 1024
        let requestedStart = offset
        let actualStart = end - min(end - requestedStart, maximumReadBytes)
        let skipped = actualStart - requestedStart
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: actualStart)
            let data = try handle.read(upToCount: Int(end - actualStart)) ?? Data()
            offset = end
            let text = String(decoding: data, as: UTF8.self)
            let lines = text.split(whereSeparator: \.isNewline)
            var anr = 0
            var inputTimeout = 0
            var fatal = 0
            var memoryKill = 0
            var choreographer = 0
            var angleWarning = 0
            var vulkanWarning = 0
            var audioError = 0
            for rawLine in lines {
                let line = String(rawLine)
                let lower = line.lowercased()
                let warningOrError = lower.contains(" warning") || lower.contains(" error")
                    || lower.contains(" failed") || lower.contains(" fatal")
                    || line.contains(" W ") || line.contains(" E ")
                if lower.contains("anr in com.riotgames.league.teamfighttactics") { anr += 1 }
                if lower.contains("input dispatching timed out") || lower.contains("input timeout") { inputTimeout += 1 }
                if lower.contains("com.riotgames.league.teamfighttactics")
                    && (lower.contains("fatal exception") || lower.contains("fatal signal") || lower.contains("signal 11")) { fatal += 1 }
                if TelemetrySignalClassifier.isConfirmedGuestMemoryKill(line) { memoryKill += 1 }
                if lower.contains("choreographer") && lower.contains("skipped") { choreographer += 1 }
                if lower.contains("angle") && warningOrError { angleWarning += 1 }
                if lower.contains("vulkan") && warningOrError { vulkanWarning += 1 }
                if lower.contains("pcm_writei") && (warningOrError || lower.contains("underrun")) { audioError += 1 }
            }
            return LogcatAggregate(
                byteStart: actualStart, byteEnd: end, skippedBytes: skipped, lineCount: lines.count,
                anrCount: anr, inputTimeoutCount: inputTimeout, fatalCount: fatal,
                memoryKillCount: memoryKill, choreographerSkipCount: choreographer,
                angleWarningCount: angleWarning, vulkanWarningCount: vulkanWarning,
                audioErrorCount: audioError
            )
        } catch {
            return nil
        }
    }

    nonisolated private static func firstRegexInt(_ pattern: String, in text: String) -> Int64? {
        firstRegexText(pattern, in: text).flatMap(Int64.init)
    }

    nonisolated private static func firstRegexDouble(_ pattern: String, in text: String) -> Double? {
        firstRegexText(pattern, in: text).flatMap(Double.init)
    }

    nonisolated private static func firstRegexText(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    nonisolated private static func regexDoubles(_ pattern: String, in text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[range])
        }
    }

    nonisolated private static func runController(
        discovery: EmulatorControllerDiscovery,
        profile: TFTMACRuntimeProfile,
        mailbox: LatestFrameMailbox,
        telemetry: TFTMACNativeTelemetry,
        inputStream: AsyncStream<EmulatorInput>,
        status: @escaping StatusHandler
    ) async throws {
        let transport = try HTTP2ClientTransport.Posix(
            target: .ipv4(address: "127.0.0.1", port: discovery.port),
            transportSecurity: .plaintext
        )
        try await withGRPCClient(transport: transport) { grpc in
            let client = Android_Emulation_Control_EmulatorController.Client(wrapping: grpc)
            let metadata: GRPCCore.Metadata = ["authorization": "Bearer \(discovery.token)"]
            let statusRequest = GRPCCore.ClientRequest(
                message: SwiftProtobuf.Google_Protobuf_Empty(),
                metadata: metadata
            )
            let emulatorStatus: Android_Emulation_Control_EmulatorStatus = try await client.getStatus(
                request: statusRequest,
                serializer: GRPCProtobuf.ProtobufSerializer<SwiftProtobuf.Google_Protobuf_Empty>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Android_Emulation_Control_EmulatorStatus>()
            )
            guard emulatorStatus.version.contains("37.1.11") else {
                throw TFTMACRuntimeError("Unexpected Android Emulator version: \(emulatorStatus.version)")
            }
            telemetry.recordEvent("CONTROLLER_AUTHENTICATED", payload: [
                "version": emulatorStatus.version,
                "booted": emulatorStatus.booted,
                "cpu_cores": emulatorStatus.vmConfig.numberOfCpuCores,
                "ram_mib": emulatorStatus.vmConfig.ramSizeBytes / 1024 / 1024
            ])

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    var requestFormat = Android_Emulation_Control_ImageFormat()
                    requestFormat.format = .rgba8888
                    requestFormat.width = 0
                    requestFormat.height = 0
                    requestFormat.display = 0
                    let request = GRPCCore.ClientRequest(message: requestFormat, metadata: metadata)
                    var callOptions = GRPCCore.CallOptions.defaults
                    callOptions.waitForReady = true
                    // grpc-swift-nio-transport 2.9.1 wires maxRequestMessageBytes
                    // into the HTTP/2 stream decoder's payload ceiling, so the
                    // pinned transport requires both limits for an 8.3 MB frame.
                    callOptions.maxRequestMessageBytes = 16 * 1024 * 1024
                    callOptions.maxResponseMessageBytes = 16 * 1024 * 1024

                    let admission = NativeFrameAdmissionState(mailbox: mailbox, telemetry: telemetry)
                    let clock = ContinuousClock()
                    let firstFrameDeadline = clock.now.advanced(by: .seconds(120))
                    var initialImage: Android_Emulation_Control_Image?
                    var recordedFrameWait = false
                    while initialImage == nil {
                        do {
                            initialImage = try await client.getScreenshot(
                                request: request,
                                serializer: GRPCProtobuf.ProtobufSerializer<Android_Emulation_Control_ImageFormat>(),
                                deserializer: GRPCProtobuf.ProtobufDeserializer<Android_Emulation_Control_Image>(),
                                options: callOptions
                            )
                        } catch let error as GRPCCore.RPCError where error.code == .failedPrecondition {
                            if !recordedFrameWait {
                                telemetry.recordEvent("FIRST_NATIVE_FRAME_WAITING", payload: [
                                    "grpc_code": "failedPrecondition",
                                    "reason": error.message,
                                    "timeout_seconds": 120
                                ])
                                recordedFrameWait = true
                            }
                            guard clock.now < firstFrameDeadline else {
                                throw TFTMACRuntimeError("Timed out waiting for Android to post its first native frame.")
                            }
                            try await Task.sleep(for: .milliseconds(250))
                        }
                    }
                    guard let initialImage else {
                        throw TFTMACRuntimeError("Android did not return an initial native frame.")
                    }
                    _ = try admission.admit(initialImage)
                    try await client.streamScreenshot(
                        request: request,
                        serializer: GRPCProtobuf.ProtobufSerializer<Android_Emulation_Control_ImageFormat>(),
                        deserializer: GRPCProtobuf.ProtobufDeserializer<Android_Emulation_Control_Image>(),
                        options: callOptions
                    ) { response in
                        for try await image in response.messages {
                            try Task.checkCancellation()
                            _ = try admission.admit(image)
                        }
                        throw TFTMACRuntimeError("The authenticated screenshot stream ended unexpectedly.")
                    }
                }
                group.addTask {
                    for await input in inputStream {
                        try Task.checkCancellation()
                        switch input {
                        case .mouse(let mouse):
                            var event = Android_Emulation_Control_MouseEvent()
                            event.x = mouse.x
                            event.y = mouse.y
                            event.buttons = mouse.buttons
                            event.display = 0
                            let request = GRPCCore.ClientRequest(message: event, metadata: metadata)
                            _ = try await client.sendMouse(
                                request: request,
                                serializer: GRPCProtobuf.ProtobufSerializer<Android_Emulation_Control_MouseEvent>(),
                                deserializer: GRPCProtobuf.ProtobufDeserializer<SwiftProtobuf.Google_Protobuf_Empty>()
                            )
                        case .keyboard(let keyboard):
                            var event = Android_Emulation_Control_KeyboardEvent()
                            event.eventType = .keypress
                            if let key = keyboard.key { event.key = key }
                            else if let text = keyboard.text { event.text = text }
                            let request = GRPCCore.ClientRequest(message: event, metadata: metadata)
                            _ = try await client.sendKey(
                                request: request,
                                serializer: GRPCProtobuf.ProtobufSerializer<Android_Emulation_Control_KeyboardEvent>(),
                                deserializer: GRPCProtobuf.ProtobufDeserializer<SwiftProtobuf.Google_Protobuf_Empty>()
                            )
                        }
                    }
                }
                _ = try await group.next()
                group.cancelAll()
            }
        }
    }

    private func prepareAVD(paths: TFTMACRuntimePaths, telemetry: TFTMACNativeTelemetry) throws -> AVDConfigurationTransaction {
        let transaction = try AVDConfigurationTransaction(
            configURL: paths.avdConfig,
            stateRoot: paths.applicationSupport.appendingPathComponent("State", isDirectory: true),
            captureDirectory: telemetry.captureDirectory,
            profile: profile
        )
        telemetry.recordEvent("AVD_CONFIG_APPLIED", payload: [
            "original_sha256": transaction.originalSHA256,
            "applied_sha256": transaction.appliedSHA256,
            "reversible": true
        ])
        return transaction
    }

    private func recoverInterruptedAVDTransaction(paths: TFTMACRuntimePaths) throws {
        try AVDConfigurationTransaction.recoverIfNeeded(
            configURL: paths.avdConfig,
            stateRoot: paths.applicationSupport.appendingPathComponent("State", isDirectory: true),
            captureRoot: paths.applicationSupport.appendingPathComponent("Captures", isDirectory: true)
        )
    }

    nonisolated private static func adbEnvironment(paths: TFTMACRuntimePaths) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "ADB_VENDOR_KEYS")
        environment.removeValue(forKey: "ADB_SERVER_SOCKET")
        environment.removeValue(forKey: "ANDROID_ADB_SERVER_ADDRESS")
        environment["ANDROID_SDK_ROOT"] = paths.sdkRoot.path
        environment["ANDROID_AVD_HOME"] = paths.avdHome.path
        environment["ANDROID_ADB_SERVER_PORT"] = "5038"
        environment["ADB_MDNS_AUTO_CONNECT"] = ""
        return environment
    }

    nonisolated private static func adb(paths: TFTMACRuntimePaths, _ arguments: [String], timeout: TimeInterval) throws -> ProcessResult {
        let result = try runCommand(
            paths.adb,
            ["-P", "5038", "-s", "emulator-5582"] + arguments,
            environment: adbEnvironment(paths: paths),
            timeout: timeout
        )
        guard result.status == 0 else {
            throw TFTMACRuntimeError("ADB command failed: \(result.output.suffix(1200))")
        }
        return result
    }

    nonisolated private static func runCommand(
        _ executable: URL,
        _ arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let timeoutWork = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeoutWork.cancel()
        let output = String(data: data, encoding: .utf8) ?? ""
        return ProcessResult(status: process.terminationStatus, output: output)
    }

    nonisolated private static func parseINI(_ text: String) -> [String: String] {
        var result = [String: String]()
        for line in text.split(whereSeparator: \.isNewline) {
            let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                result[pair[0].trimmingCharacters(in: .whitespaces)] = pair[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    nonisolated private static func processExists(_ processIdentifier: Int32) -> Bool {
        if Darwin.kill(processIdentifier, 0) == 0 { return true }
        return errno != ESRCH
    }

    nonisolated private static func processMatchesLaunchedIdentity(
        _ processIdentifier: Int32,
        sessionMarker: String? = nil
    ) -> Bool {
        guard processExists(processIdentifier),
              let result = try? runCommand(
                URL(fileURLWithPath: "/bin/ps"),
                ["-p", "\(processIdentifier)", "-ww", "-o", "command="],
                timeout: 5
              ), result.status == 0 else { return false }
        let baseIdentityMatches = result.output.contains("qemu-system-aarch64")
            && result.output.contains("@TFT_Ultra_Tablet")
            && result.output.contains("-port 5582")
        return baseIdentityMatches && (sessionMarker.map(result.output.contains) ?? true)
    }

    nonisolated private static func findOwnedEmulatorPID(sessionMarker: String) -> Int32? {
        guard let result = try? runCommand(
            URL(fileURLWithPath: "/bin/ps"),
            ["-axo", "pid=,command="],
            timeout: 10
        ), result.status == 0 else { return nil }
        for line in result.output.split(whereSeparator: \.isNewline) {
            guard line.contains("qemu-system-aarch64"),
                  line.contains("@TFT_Ultra_Tablet"),
                  line.contains(sessionMarker),
                  let pid = line.split(whereSeparator: \.isWhitespace).first.flatMap({ Int32($0) }) else { continue }
            return pid
        }
        return nil
    }

    nonisolated private static func anyEmulatorUsingSharedAVD() -> Bool {
        guard let result = try? runCommand(
            URL(fileURLWithPath: "/bin/ps"),
            ["-axo", "command="],
            timeout: 10
        ), result.status == 0 else { return true }
        return result.output.split(whereSeparator: \.isNewline).contains { line in
            line.contains("qemu-system-aarch64") && line.contains("@TFT_Ultra_Tablet")
        }
    }

    nonisolated private static func controllerDiscoveryRoots(paths: TFTMACRuntimePaths) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Caches/TemporaryItems/avd/running", isDirectory: true),
            FileManager.default.temporaryDirectory.appendingPathComponent("avd/running", isDirectory: true),
            paths.avdHome.appendingPathComponent("running", isDirectory: true),
            home.appendingPathComponent(".android/avd/running", isDirectory: true)
        ]
        var unique = [URL]()
        for candidate in candidates where !unique.contains(candidate) { unique.append(candidate) }
        return unique
    }
}

private struct ProcessResult: Sendable {
    let status: Int32
    let output: String
}

private final class AVDConfigurationTransaction: @unchecked Sendable {
    let originalSHA256: String
    let appliedSHA256: String

    private let configURL: URL
    private let backupURL: URL
    private let markerURL: URL

    init(
        configURL: URL,
        stateRoot: URL,
        captureDirectory: URL,
        profile: TFTMACRuntimeProfile
    ) throws {
        try FileManager.default.createDirectory(at: stateRoot, withIntermediateDirectories: true)
        self.configURL = configURL
        backupURL = captureDirectory.appendingPathComponent("avd-config.before.ini")
        markerURL = stateRoot.appendingPathComponent("avd-config-transaction.json")
        let original = try Data(contentsOf: configURL)
        originalSHA256 = Self.sha256(original)
        try original.write(to: backupURL, options: .atomic)
        var config = String(decoding: original, as: UTF8.self)
        let values: [String: String] = [
            "hw.cpu.ncore": "\(profile.vCPU)",
            "hw.ramSize": "\(profile.ramMiB)",
            "hw.lcd.width": "\(profile.width)",
            "hw.lcd.height": "\(profile.height)",
            "hw.lcd.density": "\(profile.densityDPI)",
            "hw.gpu.enabled": "yes",
            "hw.gpu.mode": profile.gpuMode,
            "hw.gltransport": profile.graphicsTransport,
            "hw.gltransport.drawFlushInterval": "\(profile.asgDrawFlushInterval)",
            "hw.gltransport.asg.writeBufferSize": "\(profile.asgWriteBufferSize)",
            "hw.gltransport.asg.writeStepSize": "\(profile.asgWriteStepSize)",
            "hw.gltransport.asg.dataRingSize": "\(profile.asgDataRingSize)",
            "showDeviceFrame": "no",
            "skin.name": "\(profile.width)x\(profile.height)",
            "fastboot.forceColdBoot": "yes",
            "fastboot.forceFastBoot": "no"
        ]
        for (key, value) in values { config = Self.setting(key: key, value: value, in: config) }
        let applied = Data(config.utf8)
        appliedSHA256 = Self.sha256(applied)
        let marker: [String: Any] = [
            "schema": 1,
            "config": configURL.path,
            "backup": backupURL.path,
            "original_sha256": originalSHA256,
            "applied_sha256": appliedSHA256
        ]
        let markerData = try JSONSerialization.data(withJSONObject: marker, options: [.prettyPrinted, .sortedKeys])
        try markerData.write(to: markerURL, options: .atomic)
        try applied.write(to: configURL, options: .atomic)
    }

    func restore() throws {
        let original = try Data(contentsOf: backupURL)
        guard Self.sha256(original) == originalSHA256 else {
            throw TFTMACRuntimeError("The AVD backup hash changed; automatic restore stopped safely.")
        }
        let current = try Data(contentsOf: configURL)
        let currentSHA256 = Self.sha256(current)
        let decision = try AVDTransactionGuard.restoreDecision(
            currentSHA256: currentSHA256,
            originalSHA256: originalSHA256,
            appliedSHA256: appliedSHA256
        )
        if decision == .alreadyOriginal {
            try? FileManager.default.removeItem(at: markerURL)
            return
        }
        try original.write(to: configURL, options: .atomic)
        try? FileManager.default.removeItem(at: markerURL)
    }

    static func recoverIfNeeded(configURL expectedConfigURL: URL, stateRoot: URL, captureRoot: URL) throws {
        let markerURL = stateRoot.appendingPathComponent("avd-config-transaction.json")
        guard let data = try? Data(contentsOf: markerURL),
              let marker = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let config = marker["config"] as? String,
              let backup = marker["backup"] as? String,
              let expected = marker["original_sha256"] as? String,
              let applied = marker["applied_sha256"] as? String else { return }
        let markerConfigURL = URL(fileURLWithPath: config)
        let backupURL = URL(fileURLWithPath: backup)
        try AVDTransactionGuard.validateRecoveryPaths(
            markerConfigURL: markerConfigURL,
            expectedConfigURL: expectedConfigURL,
            backupURL: backupURL,
            captureRoot: captureRoot
        )
        let backupData = try Data(contentsOf: backupURL)
        guard sha256(backupData) == expected else {
            throw TFTMACRuntimeError("A prior AVD transaction backup failed its hash check.")
        }
        let currentData = try Data(contentsOf: expectedConfigURL)
        let currentSHA256 = sha256(currentData)
        let decision = try AVDTransactionGuard.restoreDecision(
            currentSHA256: currentSHA256,
            originalSHA256: expected,
            appliedSHA256: applied
        )
        if decision == .alreadyOriginal {
            try FileManager.default.removeItem(at: markerURL)
            return
        }
        try backupData.write(to: expectedConfigURL, options: .atomic)
        try FileManager.default.removeItem(at: markerURL)
    }

    private static func setting(key: String, value: String, in text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let index = lines.firstIndex(where: { $0.hasPrefix("\(key)=") }) {
            lines[index] = "\(key)=\(value)"
        } else {
            lines.append("\(key)=\(value)")
        }
        return lines.joined(separator: "\n")
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class TFTMACRuntimeController {
    private let service: TFTMACRuntimeService
    private var runTask: Task<Void, Never>?
    private(set) var failed = false

    init(profile: TFTMACRuntimeProfile, mailbox: LatestFrameMailbox, status: @escaping TFTMACRuntimeService.StatusHandler) {
        service = TFTMACRuntimeService(profile: profile, mailbox: mailbox, status: status)
    }

    func start() {
        guard runTask == nil else { return }
        runTask = Task { [service] in
            do { try await service.run() }
            catch is CancellationError { }
            catch {
                await MainActor.run { self.failed = true }
            }
        }
    }

    func sendMouse(x: Int32, y: Int32, buttons: Int32) {
        Task { await service.sendMouse(MouseInput(x: x, y: y, buttons: buttons)) }
    }

    func sendKeyboard(text: String? = nil, key: String? = nil) {
        guard text?.isEmpty == false || key?.isEmpty == false else { return }
        Task { await service.sendKeyboard(KeyboardInput(text: text, key: key)) }
    }

    func recordPresentation(_ sample: PresentationSample) {
        Task { await service.recordPresentation(sample) }
    }

    func recordMarker(_ marker: String) {
        Task { await service.recordMarker(marker) }
    }

    func recordSettingsChange(previous: TFTMACRuntimeProfile, next: TFTMACRuntimeProfile) {
        Task { await service.recordSettingsChange(previous: previous, next: next) }
    }

    func stop() async {
        await service.stop()
        runTask?.cancel()
        _ = await runTask?.result
        runTask = nil
    }
}
