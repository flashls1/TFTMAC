import AppKit

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let mailbox = LatestFrameMailbox()
    private var mainWindowController: MainWindowController?
    private var runtimeController: TFTMACRuntimeController?
    private var settingsWindowController: RuntimeSettingsWindowController?
    private var terminationInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MainWindowController(mailbox: mailbox)
        mainWindowController = controller
        let activeProfile = TFTMACRuntimeProfile.load()
        let runtime = TFTMACRuntimeController(profile: activeProfile, mailbox: mailbox) { [weak controller] text, isError in
            controller?.emulatorView.setStatus(text, isError: isError)
        }
        runtimeController = runtime
        controller.emulatorView.onMouseInput = { [weak runtime] x, y, buttons in
            runtime?.sendMouse(x: x, y: y, buttons: buttons)
        }
        controller.emulatorView.onKeyboardInput = { [weak runtime] text, key in
            runtime?.sendKeyboard(text: text, key: key)
        }
        controller.emulatorView.onPresentationSample = { [weak runtime] sample in
            runtime?.recordPresentation(sample)
        }
        controller.showWindow(nil)
        controller.window?.makeFirstResponder(controller.emulatorView)
        NSApp.activate(ignoringOtherApps: true)
        runtime.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak controller] in
            controller?.enterNativeFullscreen()
        }
    }

    @objc func showSettings(_ sender: Any?) {
        let settings = settingsWindowController ?? RuntimeSettingsWindowController(profile: TFTMACRuntimeProfile.load())
        settings.onSave = { [weak self] previous, next in
            self?.runtimeController?.recordSettingsChange(previous: previous, next: next)
        }
        settingsWindowController = settings
        settings.refreshFromSavedProfile()
        settings.showWindow(sender)
        settings.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func markMatchEntry(_ sender: Any?) { recordMarker("MATCH_ENTRY") }
    @objc func markCombatStart(_ sender: Any?) { recordMarker("COMBAT_START") }
    @objc func markVisibleStutter(_ sender: Any?) { recordMarker("VISIBLE_STUTTER") }
    @objc func markMatchEnd(_ sender: Any?) { recordMarker("MATCH_END") }

    @objc func revealCaptureFolder(_ sender: Any?) {
        let captures = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TFTMAC/Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: captures, withIntermediateDirectories: true)
        NSWorkspace.shared.open(captures)
    }

    private func recordMarker(_ marker: String) {
        runtimeController?.recordMarker(marker)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationInProgress { return .terminateLater }
        guard let runtimeController else { return .terminateNow }
        terminationInProgress = true
        Task { @MainActor in
            await runtimeController.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
