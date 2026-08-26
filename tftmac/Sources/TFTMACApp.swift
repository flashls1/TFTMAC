import AppKit
import Foundation
import SwiftUI

private enum TFTMACRuntime {
    static let package = "com.riotgames.league.teamfighttactics"
    static let component = "com.riotgames.league.teamfighttactics/com.riotgames.leagueoflegends.RiotNativeActivity"
    static let avdName = "TftHighEndTablet"
    static let serial = "emulator-5592"
    static let adbPort = "5040"

    static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TFTMAC", isDirectory: true)
    }

    static var sdk: URL { root.appendingPathComponent("sdk", isDirectory: true) }
    static var avdHome: URL { root.appendingPathComponent("avd", isDirectory: true) }
    static var adb: URL { sdk.appendingPathComponent("platform-tools/adb") }
    static var emulator: URL { sdk.appendingPathComponent("emulator/emulator") }
    static var log: URL { root.appendingPathComponent("TFTMAC.log") }
}

enum TFTMACRendererProfile: String, CaseIterable, Identifiable {
    case enhanced
    case compatibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .enhanced: "Enhanced — ES 3.2 / ANGLE / Metal"
        case .compatibility: "Compatibility — Stock Google Emulator"
        }
    }

    var emulatorFlags: [String] {
        switch self {
        case .enhanced:
            return [
                "-feature", "GLESDynamicVersion,Vulkan,GuestAngle,-GLPipeChecksum,AsyncComposeSupport,VirtioGpuFenceContexts",
                "-append-userspace-opt", "androidboot.opengles.version=196610"
            ]
        case .compatibility:
            return []
        }
    }
}

enum TFTMACGraphicsPreset: String, CaseIterable, Identifiable {
    case balanced
    case quality
    case ultra
    case fourK

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: "Enhanced 1080p — Target"
        case .quality: "1440p — Experimental"
        case .ultra: "1800p — Experimental"
        case .fourK: "4K — Experimental"
        }
    }

    var size: String {
        switch self {
        case .balanced: "1920x1080"
        case .quality: "2560x1440"
        case .ultra: "3200x1800"
        case .fourK: "3840x2160"
        }
    }

    var density: Int {
        switch self {
        case .balanced: 280
        case .quality: 416
        case .ultra: 520
        case .fourK: 640
        }
    }

    var cpuCores: Int {
        switch self {
        case .balanced: 8
        case .quality: 6
        case .ultra, .fourK: 8
        }
    }

    var memoryMB: Int {
        switch self {
        case .balanced: 8192
        case .quality: 6144
        case .ultra, .fourK: 8192
        }
    }
}

@MainActor
final class TFTMACModel: ObservableObject {
    @Published var status = "Ready"
    @Published var detail = "TFTMAC runs Riot's official Google Play client in a high-end tablet runtime tuned for Apple Silicon."
    @Published var busy = false
    @Published var gameRunning = false
    @Published var selectedGraphicsPreset: TFTMACGraphicsPreset = .balanced
    @Published var selectedRendererProfile: TFTMACRendererProfile = .enhanced

    private let worker = DispatchQueue(label: "com.flashls1.tftmac.runtime", qos: .userInitiated)

    func launch() {
        guard !busy else { return }
        let preset = selectedGraphicsPreset
        let renderer = selectedRendererProfile
        busy = true
        status = "Starting Android…"
        detail = "Booting \(preset.title) with \(renderer.title)."
        worker.async { [weak self] in
            do {
                try Self.ensureRuntime()
                try Self.startADBServer()
                if !Self.deviceIsReady() {
                    try Self.startEmulator(preset: preset, renderer: renderer)
                }
                try Self.waitFor("Android device", timeout: 240) { Self.deviceIsReady() }
                try Self.waitFor("Android boot", timeout: 240) {
                    Self.adbOutput(["shell", "getprop", "sys.boot_completed"])
                        .trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                }
                _ = try Self.runADB(["shell", "wm", "size", preset.size])
                _ = try Self.runADB(["shell", "wm", "density", "\(preset.density)"])
                guard Self.adbOutput(["shell", "pm", "path", TFTMACRuntime.package]).contains("package:") else {
                    throw RuntimeError.message("TFT is not installed. Open Google Play and install TFT from Riot Games.")
                }
                _ = try Self.runADB(["shell", "pm", "enable", "--user", "0", TFTMACRuntime.package])
                _ = try Self.runADB(["shell", "am", "start", "-W", "--user", "0", "-n", TFTMACRuntime.component])
                try Self.waitFor("TFT", timeout: 120) {
                    !Self.adbOutput(["shell", "pidof", TFTMACRuntime.package]).isEmpty
                }
                DispatchQueue.main.async {
                    self?.busy = false
                    self?.gameRunning = true
                    self?.status = "TFT is running"
                    self?.detail = "Sign into Riot inside TFT. Your Google and Riot credentials stay inside the Android/TFT environment."
                }
            } catch {
                Self.appendLog("Launch failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.busy = false
                    self?.gameRunning = false
                    self?.status = "Couldn’t start TFT"
                    self?.detail = error.localizedDescription
                }
            }
        }
    }

    func openGooglePlay() {
        guard !busy else { return }
        busy = true
        status = "Opening Google Play…"
        detail = "Use Google Play to install or update Riot's official TFT client."
        worker.async { [weak self] in
            do {
                try Self.ensureRuntime()
                try Self.startADBServer()
                if !Self.deviceIsReady() { try Self.startEmulator() }
                try Self.waitFor("Android device", timeout: 240) { Self.deviceIsReady() }
                try Self.waitFor("Android boot", timeout: 240) {
                    Self.adbOutput(["shell", "getprop", "sys.boot_completed"])
                        .trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                }
                _ = try Self.runADB([
                    "shell", "am", "start", "-a", "android.intent.action.VIEW",
                    "-d", "market://details?id=\(TFTMACRuntime.package)"
                ])
                DispatchQueue.main.async {
                    self?.busy = false
                    self?.status = "Google Play is open"
                    self?.detail = "Install or update TFT from Riot Games, then press Play TFT."
                }
            } catch {
                DispatchQueue.main.async {
                    self?.busy = false
                    self?.status = "Couldn’t open Google Play"
                    self?.detail = error.localizedDescription
                }
            }
        }
    }

    func stop() {
        worker.async { [weak self] in
            _ = try? Self.runADB(["emu", "kill"])
            DispatchQueue.main.async {
                self?.busy = false
                self?.gameRunning = false
                self?.status = "Android stopped"
                self?.detail = "Press Play TFT to start it again."
            }
        }
    }

    nonisolated private static func ensureRuntime() throws {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: TFTMACRuntime.adb.path),
              fm.isExecutableFile(atPath: TFTMACRuntime.emulator.path),
              fm.fileExists(atPath: TFTMACRuntime.avdHome.appendingPathComponent("\(TFTMACRuntime.avdName).ini").path) else {
            throw RuntimeError.message("TFTMAC runtime is not installed. Re-run the local TFTMAC setup from the project.")
        }
    }

    nonisolated private static func environment() -> [String: String] {
        ProcessInfo.processInfo.environment.merging([
            "ANDROID_SDK_ROOT": TFTMACRuntime.sdk.path,
            "ANDROID_AVD_HOME": TFTMACRuntime.avdHome.path,
            "ANDROID_ADB_SERVER_PORT": TFTMACRuntime.adbPort,
            "ADB_MDNS_AUTO_CONNECT": ""
        ]) { _, new in new }
    }

    nonisolated private static func startADBServer() throws {
        _ = try run(TFTMACRuntime.adb, ["-P", TFTMACRuntime.adbPort, "start-server"])
    }

    nonisolated private static func startEmulator(
        preset: TFTMACGraphicsPreset = .balanced,
        renderer: TFTMACRendererProfile = .enhanced
    ) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: TFTMACRuntime.root, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: TFTMACRuntime.log.path) {
            fm.createFile(atPath: TFTMACRuntime.log.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: TFTMACRuntime.log)
        try handle.seekToEnd()
        let process = Process()
        process.executableURL = TFTMACRuntime.emulator
        process.arguments = [
            "@\(TFTMACRuntime.avdName)", "-id", "TFTMAC-High-End-Tablet", "-port", "5592",
            "-gpu", "host", "-skin", preset.size, "-cores", "\(preset.cpuCores)", "-memory", "\(preset.memoryMB)",
            "-no-snapshot", "-no-metrics", "-no-boot-anim", "-crash-report-mode", "disabled"
        ] + renderer.emulatorFlags
        process.environment = environment()
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        appendLog("Emulator started pid=\(process.processIdentifier)")
    }

    nonisolated private static func deviceIsReady() -> Bool {
        adbOutput(["get-state"]) == "device"
    }

    nonisolated private static func adbOutput(_ args: [String]) -> String {
        (try? runADB(args))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    @discardableResult
    nonisolated private static func runADB(_ args: [String]) throws -> String {
        try run(TFTMACRuntime.adb, ["-P", TFTMACRuntime.adbPort, "-s", TFTMACRuntime.serial] + args)
    }

    nonisolated private static func run(_ executable: URL, _ args: [String]) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = executable
        process.arguments = args
        process.environment = environment()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let out = stdout.fileHandleForReading.readDataToEndOfFile()
        let err = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: out, encoding: .utf8) ?? ""
        let errorOutput = String(data: err, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw RuntimeError.message(errorOutput.isEmpty ? "Command failed with status \(process.terminationStatus)." : errorOutput)
        }
        return output
    }

    nonisolated private static func waitFor(_ name: String, timeout: TimeInterval, condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            Thread.sleep(forTimeInterval: 1)
        }
        throw RuntimeError.message("Timed out waiting for \(name).")
    }

    nonisolated private static func appendLog(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: TFTMACRuntime.root, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: TFTMACRuntime.log.path) {
            fm.createFile(atPath: TFTMACRuntime.log.path, contents: data)
            return
        }
        if let handle = try? FileHandle(forWritingTo: TFTMACRuntime.log) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        }
    }
}

private enum RuntimeError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case let .message(value): value }
    }
}

struct TFTMACView: View {
    @ObservedObject var model: TFTMACModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TFTMAC")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Live Teamfight Tactics on Apple Silicon")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.status)
                        .font(.system(size: 18, weight: .semibold))
                    Text(model.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("1920 × 1080")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    Text("280 DPI · Tablet class · Metal accelerated")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 7) {
                Text("Graphics engine")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Graphics engine", selection: $model.selectedRendererProfile) {
                    Text("Enhanced 1080p").tag(TFTMACRendererProfile.enhanced)
                    Text("Compatibility 1080p").tag(TFTMACRendererProfile.compatibility)
                }
                .pickerStyle(.segmented)
                .disabled(model.busy || model.gameRunning)
            }

            HStack(spacing: 12) {
                Button("Play TFT") { model.launch() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.busy)
                Button("Google Play / Update") { model.openGooglePlay() }
                    .disabled(model.busy)
                Button("Stop Android") { model.stop() }
            }

            Spacer()

            Text("Official Riot client • Installed by Google Play • No Riot binary modification")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 650, height: 410)
        .onAppear { model.launch() }
    }
}

@main
struct TFTMACApp: App {
    @StateObject private var model = TFTMACModel()

    var body: some Scene {
        WindowGroup("TFTMAC") {
            TFTMACView(model: model)
                .frame(minWidth: 620, minHeight: 330)
        }
    }
}
