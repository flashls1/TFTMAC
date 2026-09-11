import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    let emulatorView: EmbeddedEmulatorView
    let startupSplashView: StartupSplashView
    private let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
    private var startupCurtainRevealed = false

    init(mailbox: LatestFrameMailbox) {
        emulatorView = EmbeddedEmulatorView(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            mailbox: mailbox
        )
        startupSplashView = StartupSplashView(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.black.cgColor
        emulatorView.translatesAutoresizingMaskIntoConstraints = false
        startupSplashView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(emulatorView)
        rootView.addSubview(startupSplashView)
        NSLayoutConstraint.activate([
            emulatorView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            emulatorView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            emulatorView.topAnchor.constraint(equalTo: rootView.topAnchor),
            emulatorView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            startupSplashView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            startupSplashView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            startupSplashView.topAnchor.constraint(equalTo: rootView.topAnchor),
            startupSplashView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "TFTMAC"
        window.titleVisibility = .visible
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.minSize = NSSize(width: 960, height: 540)
        window.center()
        window.contentView = rootView
        super.init(window: window)
        shouldCascadeWindows = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    func focusStartupCurtain() {
        guard !startupCurtainRevealed else { return }
        window?.makeFirstResponder(startupSplashView)
    }

    func showStartupCurtain() {
        guard !startupCurtainRevealed else { return }
        startupSplashView.clearError()
        startupSplashView.alphaValue = 1
        startupSplashView.isHidden = false
        focusStartupCurtain()
    }

    func showStartupCurtainError(_ message: String) {
        guard !startupCurtainRevealed else { return }
        startupSplashView.alphaValue = 1
        startupSplashView.isHidden = false
        startupSplashView.showError(message)
        focusStartupCurtain()
    }

    func revealStartupCurtain(animated: Bool = true) {
        guard !startupCurtainRevealed else { return }
        startupCurtainRevealed = true
        startupSplashView.clearError()

        guard animated else {
            finishStartupCurtainReveal()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            startupSplashView.animator().alphaValue = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.finishStartupCurtainReveal()
        }
    }

    func enterNativeFullscreen() {
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }

    private func finishStartupCurtainReveal() {
        startupSplashView.alphaValue = 0
        startupSplashView.isHidden = true
        window?.makeFirstResponder(emulatorView)
    }
}
