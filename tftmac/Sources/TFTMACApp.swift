import AppKit
import Foundation
import SwiftUI

private enum TFTMACControl {
    static let package = "com.riotgames.league.teamfighttactics"
    static let avdName = "TFT_Ultra_Tablet"
    static let emulatorVersion = "37.1.11"
    static let image = "system-images;android-36;google_apis_playstore;arm64-v8a"
    static let serial = "emulator-5592"
    static let adbPort = 5040
    static let consolePort = 5592
    static let vCPU = 6
    static let memoryMB = 6144
    static let width = 1920
    static let height = 1080
    static let density = 320
    static let refreshHz = 60
    static let runtimeRoot = "/Volumes/MAC MINI M4/TFTMAC/Runtime"
}

private struct HelperResponse {
    let action: String
    let values: [String: Any]

    var actionValue: String? { values["action"] as? String }
    var captureDir: String? { values["captureDir"] as? String }
    var packageState: String? {
        if let package = values["package"] as? [String: Any] {
            return package["state"] as? String
        }
        return values["packageState"] as? String
    }
}

private enum ControlError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(value): return value
        }
    }
}

private enum DirectControlHelper {
    static var script: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("tftmac-direct-control.mjs")
    }

    static var node: URL? {
        let candidates = ["/opt/homebrew/bin/node", "/usr/local/bin/node"]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    static func run(_ action: String) throws -> HelperResponse {
        guard FileManager.default.fileExists(atPath: TFTMACControl.runtimeRoot) else {
            throw ControlError.message("External TFTMAC runtime volume is not mounted: \(TFTMACControl.runtimeRoot)")
        }
        guard let script, FileManager.default.fileExists(atPath: script.path) else {
            throw ControlError.message("TFTMAC direct-control helper is missing from the app bundle.")
        }
        guard let node else {
            throw ControlError.message("Node.js is required by this control build and was not found.")
        }

        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = node
        process.arguments = [script.path, action]
        process.standardOutput = output
        process.standardError = errors
        process.environment = ProcessInfo.processInfo.environment
        try process.run()
        process.waitUntilExit()

        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ControlError.message(detail.isEmpty ? "Direct-control action failed with status \(process.terminationStatus)." : detail)
        }
        guard let data = stdout.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ControlError.message("Direct-control helper returned invalid state.")
        }
        return HelperResponse(action: action, values: object)
    }
}

@MainActor
final class TFTMACModel: ObservableObject {
    @Published var status = "Direct-play control ready"
    @Published var detail = "Stock Google Emulator + official Google Play/Riot TFT. Capture starts before Android and before TFT."
    @Published var busy = false
    @Published var captureActive = false
    @Published var gameRunning = false
    @Published var capturePath: String?

    private let worker = DispatchQueue(label: "com.flashls1.tftmac.direct-control", qos: .userInitiated)

    func refresh() {
        perform(action: "status", working: "Reading control state…") { response in
            self.captureActive = (response.values["activeSession"] as? [String: Any]) != nil
            self.gameRunning = response.values["tftPid"] != nil && !(response.values["tftPid"] is NSNull)
            if let active = response.values["activeSession"] as? [String: Any] {
                self.capturePath = active["captureDir"] as? String
            }
            let gameState = response.values["gameState"] as? String
            if gameState == "ANR_WAIT_REQUIRED" {
                self.status = "TFT paused on Android ANR"
                self.detail = "The Riot WebView stopped responding. Choose Wait, not Close App, so the live patched client can recover without restarting the emulator."
            } else if gameState == "PATCHING_OR_INITIALIZING" {
                self.status = "TFT is patching — capture active"
                self.detail = "Riot's in-game patch service is active. Keep the emulator running; TFTMAC will not classify the client as ready until patching finishes."
            } else if self.gameRunning {
                self.status = "TFT is running — capture active"
                self.detail = gameState == "RUNNING_POST_PATCH_OR_LOBBY"
                    ? "Riot's patch service is no longer active. Confirm the lobby/party state before beginning the gameplay control."
                    : "Telemetry is append-only and active while TFT is running."
            } else {
                self.status = self.captureActive ? "Control capture active" : "Direct-play control ready"
                self.detail = self.captureActive
                    ? "Telemetry is append-only and active. Use Google Play / Update before Play TFT if an update is offered."
                    : "Start Control before opening Google Play or TFT so the full session is captured."
            }
        }
    }

    func startControl() {
        perform(action: "start", working: "Starting stock capture before Android…") { response in
            self.captureActive = true
            self.capturePath = response.captureDir
            self.status = "Stock control capture active"
            let packageState = response.packageState ?? "unknown"
            self.detail = "Stock Android control is ready. Official TFT package state: \(packageState)."
        }
    }

    func startDonorControl() {
        perform(action: "start-donor-control", working: "Starting Mactician-compatible control…") { response in
            self.captureActive = true
            self.capturePath = response.captureDir
            self.status = "Mactician-compatible control active"
            let packageState = response.packageState ?? "unknown"
            self.detail = "ANGLE + Vulkan + virtio-gpu-ASG compatibility control is live. Official TFT package state: \(packageState)."
        }
    }

    func openGooglePlay() {
        guard captureActive else {
            status = "Start Control first"
            detail = "The logger must be active before package/update and TFT launch for Control 0."
            return
        }
        perform(action: "play-action", working: "Checking official TFT in Google Play…") { response in
            switch response.actionValue {
            case "AUTH_REQUIRED":
                self.status = "Google authentication required"
                self.detail = "Authenticate directly inside Google Play, then press Google Play / Update again. TFTMAC does not read or store your credentials."
            case "INSTALLED", "UPDATED", "CURRENT_OBSERVED":
                self.status = "Official TFT is current"
                self.detail = "Google Play is authoritative and no Update action remains. You can launch TFT."
            default:
                self.status = "Google Play state: \(response.actionValue ?? "observed")"
                self.detail = "The official Play flow is still resolving."
            }
        }
    }

    func launchTFT() {
        guard captureActive else {
            status = "Start Control first"
            detail = "TFT launch is blocked until the logger is active."
            return
        }
        perform(action: "launch-game", working: "Launching official TFT…") { response in
            self.gameRunning = response.values["pid"] != nil
            if response.actionValue == "RIOT_AUTH_POSSIBLE" {
                self.status = "Riot authentication required"
                self.detail = "Authenticate directly inside TFT. After authentication, enter a live match and keep this capture running."
            } else {
                self.status = "TFT is running — capture active"
                self.detail = "Enter a current live match and play through combat. Press F8 for a manual stutter marker if needed."
            }
        }
    }

    func markStutter() {
        guard captureActive else { return }
        perform(action: "marker", working: nil, showBusy: false) { _ in
            self.status = "Stutter marker recorded"
            self.detail = "F8 marker written into the active control capture."
        }
    }

    func stopAndSave() {
        guard captureActive else { return }
        perform(action: "stop", working: "Finalizing control capture…") { response in
            self.captureActive = false
            self.gameRunning = false
            self.capturePath = response.captureDir ?? self.capturePath
            self.status = "Control capture finalized"
            self.detail = "Raw evidence, package/renderer state, frame metrics, manifest, and normalized lab state were saved."
        }
    }

    private func perform(
        action: String,
        working: String?,
        showBusy: Bool = true,
        success: @escaping @MainActor (HelperResponse) -> Void
    ) {
        guard !busy || !showBusy else { return }
        if showBusy { busy = true }
        if let working { status = working }
        worker.async { [weak self] in
            do {
                let response = try DirectControlHelper.run(action)
                DispatchQueue.main.async {
                    if showBusy { self?.busy = false }
                    success(response)
                }
            } catch {
                DispatchQueue.main.async {
                    if showBusy { self?.busy = false }
                    self?.status = "Direct-control action failed"
                    self?.detail = error.localizedDescription
                }
            }
        }
    }
}

struct TFTMACView: View {
    @ObservedObject var model: TFTMACModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("TFTMAC")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Direct Play Control 0")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
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
                    Text("1920 × 1080 @ 60")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    Text("320 DPI · 6 vCPU · 6144 MB")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Stock or Mactician-compatible · direct window")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text("Frozen runtime")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Google Emulator \(TFTMACControl.emulatorVersion) · API 36 Play ARM64 · \(TFTMACControl.avdName)")
                    .font(.system(size: 12, design: .monospaced))
                Text("Package authority: Google Play / Riot only")
                    .font(.system(size: 12, weight: .medium))
            }

            HStack(spacing: 10) {
                Button("1A  Start Stock") { model.startControl() }
                    .disabled(model.busy || model.captureActive)
                Button("1B  Start Mactician-Compatible") { model.startDonorControl() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.busy || model.captureActive)
                Button("2  Google Play / Update") { model.openGooglePlay() }
                    .disabled(model.busy || !model.captureActive)
                Button("3  Play TFT") { model.launchTFT() }
                    .disabled(model.busy || !model.captureActive)
                Button("Stop & Save") { model.stopAndSave() }
                    .disabled(model.busy || !model.captureActive)
            }

            if let path = model.capturePath {
                Text(path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            Spacer()

            HStack {
                Text("Official Riot client · no hosted feed · no bundled/community TFT package")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("F8 = stutter marker")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(28)
        .frame(width: 760, height: 430)
        .onAppear { model.refresh() }
    }
}

@main
struct TFTMACApp: App {
    @StateObject private var model = TFTMACModel()

    var body: some Scene {
        WindowGroup("TFTMAC") {
            TFTMACView(model: model)
                .frame(minWidth: 720, minHeight: 390)
        }
        .commands {
            CommandMenu("Control") {
                Button("Mark Stutter") { model.markStutter() }
                    .keyboardShortcut(KeyEquivalent(Character("\u{F70B}")), modifiers: [])
            }
        }
    }
}
