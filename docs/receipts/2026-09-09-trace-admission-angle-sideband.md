# Trace admission receipt: custom ANGLE sideband with real TFT

**Observed:** 2026-09-09 (local Mac, America/Chicago)

## Decision-critical test

The decision was whether a guest ANGLE build carrying the guarded timeline
sideband, paired with the instrumented gfxstream host, causes the current TFT
process to emit a sealed pipeline event. The smallest test built the two ANGLE
libraries, substituted them only in an isolated hardlink runtime, booted the
existing read-only AVD, launched TFT, and inspected the private event directory
after real process activity.

## Build and runtime identity

- ANGLE target: `libGLESv2 libEGL`, GN define
  `TFTMAC_ANGLE_CAUSAL_TRACE=1`; Ninja exit `0`.
- Guest `libGLESv2.dylib` SHA-256
  `f1a00d26eab53fecdc36f616fc5807e872eade6955d801296c9cc12059372458`.
- Guest `libEGL.dylib` SHA-256
  `dcb5a85658c5a5160c53f5704a9e5ff352fccd214d6201b6f8273c430fe42d09`.
- Matching component dependencies were isolated beside the runtime:
  `libabsl.dylib` SHA-256
  `1d23d258c79368fd8f61dd87fc86501d672d07caf533ad8f1426066e6f753f15`,
  `libchrome_zlib.dylib` SHA-256
  `93e73bd266c368b2d096e198a422fb51018fbab812b2e3626191fab7e4bc0c7f`,
  and `libc++.dylib` SHA-256
  `9598712baf1fdb38eeaf0108b5b2ea74a283637daf5459624ab277c5d196d105`.
- Custom AEMU host `emulator` SHA-256
  `b6ff8c61dfefc39ee16cfb52e8904416fa3a79632113fba9a39482e36f77bcaf`.
- Instrumented host `libgfxstream_backend.dylib` SHA-256
  `d92ffec5c62feffdbef3658a82efe6cba7e5bebc6d201efc8560b51d4b10c725`.
- AVD: `TFTMAC_CausalTrace_R1`, `-read-only`, `-qt-hide-window`, port 5588;
  no user-facing window was used. Capture directory:
  `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r3-angle-guest`.

## Mechanism-exercise evidence

- `sys.boot_completed=1` and ADB reported `emulator-5588` as a device.
- `dumpsys activity` identified the actual TFT process and
  `com.epicgames.unreal.GameActivity`.
- Host output recorded `Created VkInstance ... application:'TFT'
  engine:'UnrealEngine5.7'`.
- TFT logcat recorded `GraphicsEnvironment: ForceANGLE` as off and Vulkan
  loader activity for the TFT process; the emulator also opened its guest
  `EGL_emulation` libraries.
- `pipeline-events/` remained empty after approximately 40 seconds of TFT
  activity. No `TFTPIPE1` record was produced.
- The emulator was stopped cleanly with the owned process tree drained.

## Result

`GUEST_MARKER_STILL_MISSING`

The custom ANGLE sideband was built and installed, but the current TFT run did
not produce an event proving that ANGLE's modified queue-submit path executed.
The observed Vulkan instance and `ForceANGLE=off` evidence make the direct
Vulkan path the current traced boundary; this test cannot establish ANGLE view
creation cost, a late-frame owner, or any FPS gain. Do not implement view reuse,
storage-buffer translation, fences, or a router from this result. The next
decision test must instrument the direct guest Vulkan submission path (or prove
the exact Android library load path) before another optimization batch.

No Control files, Clara connection, credentials, or production runtime were
changed.
