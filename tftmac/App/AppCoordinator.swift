import AppKit

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let mailbox = LatestFrameMailbox(
        buffersDisplayJitter: Bundle.main.bundleIdentifier == "com.flashls1.tftmac.dev"
    )
    private var mainWindowController: MainWindowController?
    private var runtimeController: TFTMACRuntimeController?
    private var settingsWindowController: RuntimeSettingsWindowController?
    private var startupCurtain = StartupCurtainReducer()
    private var activeProfile: TFTMACRuntimeProfile = .playable
    private var activeApplicationSupport = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/TFTMAC", isDirectory: true)
    private var terminationInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MainWindowController(mailbox: mailbox)
        mainWindowController = controller
        controller.showWindow(nil)
        controller.focusStartupCurtain()
        NSApp.activate(ignoringOtherApps: true)

        do {
            let savedProfile = TFTMACRuntimeProfile.load()
            let runtimeConfiguration = try TFTMACSelectedRuntimeConfiguration.load(
                savedProfile: savedProfile
            )
            activeProfile = runtimeConfiguration.profile
            activeApplicationSupport = runtimeConfiguration.applicationSupport
            startupCurtain.configure(workload: runtimeConfiguration.workload)
            renderStartupCurtain(on: controller, animated: false)

            let isDEV = runtimeConfiguration.selection.mode == .advancedDiagnostics
            let unlockSecret: TFTMACGuestUnlockSecret? = isDEV ? nil : try TFTMACGuestUnlockSecretStore.loadOrPrompt(
                applicationName: "TFTMAC",
                runtimeMode: runtimeConfiguration.selection.mode
            )
            if ProcessInfo.processInfo.environment["TFTMAC_UNLOCK_SETUP_ONLY"] == "1" {
                controller.emulatorView.setStatus(
                    isDEV ? "TFTMAC DEV does not require an Android PIN." : "Automatic Android unlock is stored securely.",
                    isError: false
                )
                NSApp.terminate(nil)
                return
            }
            let runtime = TFTMACRuntimeController(
                runtimeConfiguration: runtimeConfiguration,
                guestUnlockSecret: unlockSecret,
                mailbox: mailbox,
                status: { [weak self, weak controller] text, isError in
                    guard let self, let controller else { return }
                    if isError, self.startupCurtain.state.isVisuallyCovered {
                        self.startupCurtain.fail(text)
                        self.renderStartupCurtain(on: controller)
                    } else {
                        controller.emulatorView.setStatus(text, isError: isError)
                    }
                },
                gameFrame: { [weak self, weak controller] window in
                    guard let self, let controller else { return }
                    controller.emulatorView.setGameFrameWindow(window)
                    guard let status = window?.status else { return }
                    self.startupCurtain.observeGameFrameStatus(
                        status,
                        currentPresentedSequence: controller.emulatorView.latestSuccessfullyPresentedSourceSequence
                    )
                    self.renderStartupCurtain(on: controller)
                },
                completed: {
                    if runtimeConfiguration.workload == .ownedVulkanProbe {
                        NSApp.terminate(nil)
                    }
                }
            )
            runtimeController = runtime
            controller.emulatorView.onTouchInput = { [weak runtime] input, timestampNS in
                runtime?.sendTouch(input, nativeEventMonotonicNS: timestampNS)
            }
            controller.emulatorView.onMouseInput = { [weak runtime] x, y, buttons, timestampNS in
                runtime?.sendMouse(x: x, y: y, buttons: buttons, nativeEventMonotonicNS: timestampNS)
            }
            controller.emulatorView.onKeyboardInput = { [weak runtime] text, key, timestampNS in
                runtime?.sendKeyboard(text: text, key: key, nativeEventMonotonicNS: timestampNS)
            }
            controller.emulatorView.onPresentationSample = { [weak runtime] sample in
                runtime?.recordPresentation(sample)
            }
            controller.emulatorView.onHostPresentationWindow = { [weak runtime] sample in
                runtime?.recordHostPresentation(sample)
            }
            controller.emulatorView.onSourceFramePresented = { [weak self, weak controller] sequence in
                guard let self, let controller else { return }
                self.startupCurtain.sourceFramePresented(sequence)
                self.renderStartupCurtain(on: controller)
            }
            runtime.start()
        } catch {
            var message = error.localizedDescription
            if Bundle.main.bundleIdentifier == "com.flashls1.tftmac.dev" {
                let support = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/TFTMAC/Modes/advanced_diagnostics", isDirectory: true)
                do { _ = try DiagnosticArtifactFile.persistStartupFailure(message, applicationSupport: support) }
                catch { message += " (The private failure receipt could not be written: \(error.localizedDescription))" }
            }
            startupCurtain.fail(message)
            renderStartupCurtain(on: controller)
        }

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

    @objc func toggleRememberRiotLogin(_ sender: NSMenuItem) {
        RiotCredentialStore.remember.toggle()
        sender.state = RiotCredentialStore.remember ? .on : .off
    }

    @objc func signInWithSavedAccount(_ sender: Any?) {
        runtimeController?.signInWithSavedAccount()
    }

    @objc func markMatchEntry(_ sender: Any?) { recordMarker("MATCH_ENTRY") }
    @objc func startCombatBenchmark(_ sender: Any?) {
        runtimeController?.startCombatBenchmark(performanceModeConfirmed: false)
    }
    @objc func markVisibleStutter(_ sender: Any?) { runtimeController?.markVisibleStutter() }
    @objc func endCombatBenchmark(_ sender: Any?) {
        var correctnessPassed = true
        if activeProfile.experimentPreset.isActiveCandidate {
            let alert = NSAlert()
            alert.messageText = "Did Combat Latency A preserve correctness?"
            alert.informativeText = "Reject the run if boot, graphics, input, audio, login, or gameplay correctness regressed. TFTMAC will restore Control for the next launch."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "All Correct — End")
            alert.addButton(withTitle: "Reject: Correctness Problem")
            correctnessPassed = alert.runModal() == .alertFirstButtonReturn
        }
        runtimeController?.endCombatBenchmark(correctnessPassed: correctnessPassed)
    }
    @objc func markMatchEnd(_ sender: Any?) { recordMarker("MATCH_END") }

    @objc func revealCaptureFolder(_ sender: Any?) {
        let captures = activeApplicationSupport
            .appendingPathComponent("Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: captures, withIntermediateDirectories: true)
        NSWorkspace.shared.open(captures)
    }

    private func recordMarker(_ marker: String) {
        runtimeController?.recordMarker(marker)
    }

    private func renderStartupCurtain(on controller: MainWindowController, animated: Bool = true) {
        switch startupCurtain.state {
        case .covered, .eligible:
            controller.showStartupCurtain()
        case .failed(let message):
            controller.showStartupCurtainError(message)
        case .revealed:
            controller.revealStartupCurtain(animated: animated)
        }
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
