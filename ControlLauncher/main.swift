import AppKit
import Foundation

private enum ControlLauncherError: LocalizedError {
    case missingControl
    case missingADB
    case launchFailed(String)
    case adbUnavailable(String)
    case unlockRejected

    var errorDescription: String? {
        switch self {
        case .missingControl:
            return "The protected Control app is missing from /Applications/TFTMAC.app."
        case .missingADB:
            return "The protected Control ADB executable is missing."
        case .launchFailed(let detail):
            return "The protected Control app could not be launched: \(detail)"
        case .adbUnavailable(let state):
            return "Control did not reach authorized ADB device state on emulator-5582 (last state: \(state))."
        case .unlockRejected:
            return "Android did not accept the saved unlock PIN after two bounded attempts."
        }
    }
}

private struct CommandResult {
    let status: Int32
    let output: String
}

@main
@MainActor
struct TFTMACControlLauncher {
    private static let controlApp = URL(fileURLWithPath: "/Applications/TFTMAC.app", isDirectory: true)
    private static let adb = URL(fileURLWithPath: "/Volumes/MAC MINI M4/TFTMAC/Runtime/SDK/platform-tools/adb")
    private static let adbPort = "5038"
    private static let serial = "emulator-5582"

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        do {
            let secret = try TFTMACGuestUnlockSecretStore.loadOrPrompt(applicationName: "TFTMAC")
            try launchProtectedControlIfNeeded()
            try waitForAuthorizedDevice()
            try unlockIfNeeded(secret: secret)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private static func launchProtectedControlIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: controlApp.path) else {
            throw ControlLauncherError.missingControl
        }
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.flashls1.tftmac").isEmpty {
            return
        }
        let result = try run(
            executable: URL(fileURLWithPath: "/usr/bin/open"),
            arguments: ["-n", controlApp.path],
            timeout: 30
        )
        guard result.status == 0 else {
            throw ControlLauncherError.launchFailed(result.output)
        }
    }

    private static func waitForAuthorizedDevice() throws {
        guard FileManager.default.isExecutableFile(atPath: adb.path) else {
            throw ControlLauncherError.missingADB
        }
        let deadline = Date().addingTimeInterval(300)
        var state = "missing"
        while Date() < deadline {
            let result = try runADB(["get-state"], timeout: 10)
            state = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if result.status == 0, state == "device" { return }
            Thread.sleep(forTimeInterval: 1)
        }
        throw ControlLauncherError.adbUnavailable(state)
    }

    private static func unlockIfNeeded(secret: TFTMACGuestUnlockSecret) throws {
        for attempt in 0..<3 {
            let user = try runADB(["shell", "dumpsys", "user"], timeout: 15)
            if user.output.contains("RUNNING_UNLOCKED") { return }
            if attempt == 2 { break }
            try sendUnlockOverStandardInput(secret: secret)
            Thread.sleep(forTimeInterval: 5)
        }
        throw ControlLauncherError.unlockRejected
    }

    private static func sendUnlockOverStandardInput(secret: TFTMACGuestUnlockSecret) throws {
        let process = Process()
        process.executableURL = adb
        process.arguments = ["-P", adbPort, "-s", serial, "shell"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        try process.run()

        var command = Data("input keyevent KEYCODE_WAKEUP\ninput keyevent KEYCODE_ENTER\n".utf8)
        let pin = try secret.transientPIN()
        for scalar in pin.unicodeScalars {
            command.append(Data("input keyevent KEYCODE_\(scalar)\n".utf8))
        }
        command.append(Data("input keyevent KEYCODE_ENTER\nexit\n".utf8))
        try input.fileHandleForWriting.write(contentsOf: command)
        command.resetBytes(in: 0..<command.count)
        input.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        _ = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw ControlLauncherError.adbUnavailable("unlock transport failed")
        }
    }

    private static func runADB(_ arguments: [String], timeout: TimeInterval) throws -> CommandResult {
        try run(executable: adb, arguments: ["-P", adbPort, "-s", serial] + arguments, timeout: timeout)
    }

    private static func run(
        executable: URL,
        arguments: [String],
        timeout: TimeInterval
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            status: process.terminationStatus,
            output: String(data: data, encoding: .utf8) ?? ""
        )
    }

    private static func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "TFTMAC Control Launcher"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}
