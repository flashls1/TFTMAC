import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    init() {
        let contentView = EmbeddedEmulatorView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "TFTMAC"
        window.titleVisibility = .visible
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.minSize = NSSize(width: 960, height: 540)
        window.center()
        window.contentView = contentView
        super.init(window: window)
        shouldCascadeWindows = false
    }

    required init?(coder: NSCoder) {
        nil
    }
}
