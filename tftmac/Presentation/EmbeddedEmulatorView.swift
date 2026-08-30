import AppKit
import MetalKit

@MainActor
final class EmbeddedEmulatorView: MTKView, MTKViewDelegate {
    init(frame: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("TFTMAC requires Metal on Apple Silicon")
        }
        super.init(frame: frame, device: device)
        framebufferOnly = true
        colorPixelFormat = .bgra8Unorm_srgb
        preferredFramesPerSecond = 60
        enableSetNeedsDisplay = false
        isPaused = false
        clearColor = MTLClearColorMake(0.035, 0.035, 0.045, 1.0)
        delegate = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let queue = device?.makeCommandQueue(),
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }
}
