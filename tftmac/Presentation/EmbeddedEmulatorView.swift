import AppKit
import MetalKit

private final class PresenterGPUState: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = [0, 0, 0]
    private var completedPresentations: UInt64 = 0

    func availableUploadSlot(excluding current: Int?) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return inFlight.indices.first(where: { inFlight[$0] == 0 && $0 != current })
            ?? inFlight.indices.first(where: { inFlight[$0] == 0 })
    }

    func beginPresentation(slot: Int) {
        lock.lock()
        inFlight[slot] += 1
        lock.unlock()
    }

    func completePresentation(slot: Int) {
        lock.lock()
        inFlight[slot] = max(0, inFlight[slot] - 1)
        completedPresentations &+= 1
        lock.unlock()
    }

    func completedCount() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return completedPresentations
    }
}

@MainActor
final class EmbeddedEmulatorView: MTKView, MTKViewDelegate {
    var onMouseInput: ((Int32, Int32, Int32) -> Void)?
    var onKeyboardInput: ((String?, String?) -> Void)?
    var onPresentationSample: ((PresentationSample) -> Void)?

    private let mailbox: LatestFrameMailbox
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let gpuState = PresenterGPUState()
    private var textures: [MTLTexture?] = [nil, nil, nil]
    private var currentTextureSlot: Int?
    private var lastPresentedSequence: UInt32?
    private var lastSampleTime = CACurrentMediaTime()
    private var lastSamplePresentationCount: UInt64 = 0
    private var lastSampleReceivedCount: UInt64 = 0
    private let statusLabel = NSTextField(labelWithString: "Preparing native Android runtime…")
    private let fpsLabel = NSTextField(labelWithString: "0 FPS")

    init(frame: NSRect, mailbox: LatestFrameMailbox) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("TFTMAC requires Metal on Apple Silicon")
        }
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("TFTMAC could not create its persistent Metal command queue")
        }
        self.mailbox = mailbox
        self.commandQueue = commandQueue
        do {
            pipeline = try Self.makePipeline(device: device)
        } catch {
            fatalError("TFTMAC could not create its native frame pipeline: \(error.localizedDescription)")
        }
        super.init(frame: frame, device: device)
        framebufferOnly = true
        colorPixelFormat = .bgra8Unorm_srgb
        preferredFramesPerSecond = 60
        enableSetNeedsDisplay = false
        isPaused = false
        clearColor = MTLClearColorMake(0.015, 0.018, 0.025, 1.0)
        delegate = self
        configureOverlays()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    func setStatus(_ text: String, isError: Bool) {
        guard !text.isEmpty else {
            statusLabel.isHidden = true
            return
        }
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? .systemRed : .white
        statusLabel.isHidden = false
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        uploadNewestFrameIfPossible()
        guard let slot = currentTextureSlot,
              let texture = textures[slot],
              let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let buffer = commandQueue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            updatePresentationSampleIfNeeded()
            return
        }

        let source = CGSize(width: texture.width, height: texture.height)
        let target = drawableSize
        let scale = min(target.width / source.width, target.height / source.height)
        let renderWidth = source.width * scale
        let renderHeight = source.height * scale
        encoder.setViewport(MTLViewport(
            originX: (target.width - renderWidth) / 2,
            originY: (target.height - renderHeight) / 2,
            width: renderWidth,
            height: renderHeight,
            znear: 0,
            zfar: 1
        ))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        gpuState.beginPresentation(slot: slot)
        let state = gpuState
        buffer.addCompletedHandler { _ in state.completePresentation(slot: slot) }
        buffer.present(drawable)
        buffer.commit()
        updatePresentationSampleIfNeeded()
    }

    override func mouseDown(with event: NSEvent) { sendMouse(event, buttons: 1) }
    override func mouseDragged(with event: NSEvent) { sendMouse(event, buttons: 1) }
    override func mouseUp(with event: NSEvent) { sendMouse(event, buttons: 0) }
    override func rightMouseDown(with event: NSEvent) { sendMouse(event, buttons: 2) }
    override func rightMouseDragged(with event: NSEvent) { sendMouse(event, buttons: 2) }
    override func rightMouseUp(with event: NSEvent) { sendMouse(event, buttons: 0) }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
            super.keyDown(with: event)
            return
        }
        if let key = Self.specialKey(for: event) {
            onKeyboardInput?(nil, key)
        } else if let text = event.characters, !text.isEmpty {
            onKeyboardInput?(text, nil)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "v" {
            paste(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    @objc func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        onKeyboardInput?(String(text.prefix(1024)), nil)
    }

    private func uploadNewestFrameIfPossible() {
        guard let frame = mailbox.takeLatest() else { return }
        guard let slot = gpuState.availableUploadSlot(excluding: currentTextureSlot) else { return }
        if textures[slot] == nil {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm_srgb,
                width: frame.width,
                height: frame.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead]
            descriptor.storageMode = .shared
            textures[slot] = device?.makeTexture(descriptor: descriptor)
            textures[slot]?.label = "TFTMAC Android frame \(slot)"
        }
        guard let texture = textures[slot] else { return }
        frame.pixels.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake2D(0, 0, frame.width, frame.height),
                mipmapLevel: 0,
                withBytes: baseAddress,
                bytesPerRow: frame.width * FrameContract.bytesPerPixel
            )
        }
        currentTextureSlot = slot
        lastPresentedSequence = frame.sequence
    }

    private func sendMouse(_ event: NSEvent, buttons: Int32) {
        let location = convert(event.locationInWindow, from: nil)
        let mapper = ViewportMapper(
            sourceSize: CGSize(width: FrameContract.width, height: FrameContract.height),
            viewportSize: bounds.size
        )
        guard let source = mapper.sourcePoint(for: location) else { return }
        let x = Int32(max(0, min(FrameContract.width - 1, Int(source.x.rounded()))))
        let topOriginY = FrameContract.height - 1 - Int(source.y.rounded())
        let y = Int32(max(0, min(FrameContract.height - 1, topOriginY)))
        onMouseInput?(x, y, buttons)
    }

    private func updatePresentationSampleIfNeeded() {
        let now = CACurrentMediaTime()
        let elapsed = now - lastSampleTime
        guard elapsed >= 1 else { return }
        let total = gpuState.completedCount()
        let delta = total - lastSamplePresentationCount
        let presentationFPS = Double(delta) / elapsed
        let mailboxSnapshot = mailbox.snapshot()
        let receivedDelta = mailboxSnapshot.receivedFrames - lastSampleReceivedCount
        let sourceFPS = Double(receivedDelta) / elapsed
        fpsLabel.stringValue = String(format: "SRC %.0f · OUT %.0f", sourceFPS, presentationFPS)
        let sample = PresentationSample(
            presentedFrames: total,
            presentationFPS: presentationFPS,
            sourceFPS: sourceFPS,
            mailbox: mailboxSnapshot,
            lastPresentedSequence: lastPresentedSequence,
            sampledMonotonicNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
        onPresentationSample?(sample)
        lastSamplePresentationCount = total
        lastSampleReceivedCount = mailboxSnapshot.receivedFrames
        lastSampleTime = now
    }

    private func configureOverlays() {
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.alignment = .center
        statusLabel.maximumNumberOfLines = 3
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.wantsLayer = true
        statusLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        statusLabel.layer?.cornerRadius = 10
        addSubview(statusLabel)

        fpsLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        fpsLabel.textColor = .white
        fpsLabel.alignment = .center
        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        fpsLabel.wantsLayer = true
        fpsLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.62).cgColor
        fpsLabel.layer?.cornerRadius = 6
        addSubview(fpsLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.72),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            fpsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            fpsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            fpsLabel.widthAnchor.constraint(equalToConstant: 142),
            fpsLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private static func makePipeline(device: MTLDevice) throws -> MTLRenderPipelineState {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct RasterData {
            float4 position [[position]];
            float2 textureCoordinate;
        };

        vertex RasterData tftmac_vertex(uint vertexID [[vertex_id]]) {
            const float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
            // Metal's bottom screen edge must sample the bottom RGBA row.
            // The oversized triangle therefore maps bottom vertices to v=1.
            const float2 coordinates[3] = { float2(0.0, 1.0), float2(2.0, 1.0), float2(0.0, -1.0) };
            RasterData output;
            output.position = float4(positions[vertexID], 0.0, 1.0);
            output.textureCoordinate = coordinates[vertexID];
            return output;
        }

        fragment float4 tftmac_fragment(RasterData input [[stage_in]], texture2d<float> frame [[texture(0)]]) {
            constexpr sampler sampleState(coord::normalized, address::clamp_to_edge, filter::linear);
            return frame.sample(sampleState, input.textureCoordinate);
        }
        """
        let library = try device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "TFTMAC RGBA presenter"
        descriptor.vertexFunction = library.makeFunction(name: "tftmac_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "tftmac_fragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func specialKey(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 36, 76: return "Enter"
        case 48: return "Tab"
        case 51, 117: return "Backspace"
        case 53: return "GoBack"
        case 111: return "Power"
        case 115: return "GoHome"
        case 119: return "End"
        case 123: return "ArrowLeft"
        case 124: return "ArrowRight"
        case 125: return "ArrowDown"
        case 126: return "ArrowUp"
        default: return nil
        }
    }
}
