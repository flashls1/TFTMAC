import AppKit

@MainActor
final class StartupSplashView: NSView {
    private let splashImage: NSImage
    private let errorLabel = NSTextField(labelWithString: "")

    init(frame frameRect: NSRect, bundle: Bundle = .main) {
        guard let imageURL = bundle.url(
            forResource: "TFTMAC-Splash-1920x1080",
            withExtension: "png"
        ), let image = NSImage(contentsOf: imageURL) else {
            fatalError("TFTMAC startup splash resource is missing or unreadable.")
        }
        splashImage = image
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        configureErrorLabel()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()

        guard splashImage.size.width > 0, splashImage.size.height > 0 else { return }
        let scale = max(bounds.width / splashImage.size.width, bounds.height / splashImage.size.height)
        let width = splashImage.size.width * scale
        let height = splashImage.size.height * scale
        let destination = NSRect(
            x: (bounds.width - width) / 2,
            y: (bounds.height - height) / 2,
            width: width,
            height: height
        )
        let previousInterpolation = NSGraphicsContext.current?.imageInterpolation
        NSGraphicsContext.current?.imageInterpolation = .high
        splashImage.draw(in: destination)
        if let previousInterpolation {
            NSGraphicsContext.current?.imageInterpolation = previousInterpolation
        }
    }

    func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = false
    }

    func clearError() {
        errorLabel.stringValue = ""
        errorLabel.isHidden = true
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseDragged(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func otherMouseDragged(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
    override func keyDown(with event: NSEvent) {}

    private func configureErrorLabel() {
        errorLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.maximumNumberOfLines = 4
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.wantsLayer = true
        errorLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        errorLabel.layer?.cornerRadius = 12
        errorLabel.isHidden = true
        addSubview(errorLabel)

        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.72),
            errorLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            errorLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }
}
