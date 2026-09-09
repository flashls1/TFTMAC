# Color-buffer blit/resolve receipt

**Date:** 2026-09-09 07:15 UTC  
**Decision:** How much host time is spent copying the guest render surface into the posted color buffer?

## Mechanism under test

Two guarded host spans were added below the already-linked render-control frame marker:

- source `1504`: `EmulatedEglWindowSurface::flushColorBuffer` around `ColorBufferGl::blitFromCurrentReadBuffer`, carrying the window handle;
- source `1505`: the `ColorBufferGl::blitFromCurrentReadBuffer` implementation.

Both use `kColorBufferPublish` (`13`) and remain opt-in diagnostics.

## Smallest decision test and evidence

The rebuilt backend was copied into the isolated runtime and loaded by a hidden emulator using `-qt-hide-window -read-only`, console port `5611`, and the private pipeline recorder. Runtime backend SHA-256:

`78d69d01a2177d04f6e2d35e70a0af9303d88f7b80fc8aa28312159a9a35fe8d`

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r17-blit`

The emulator reached ADB after 9 seconds and `sys.boot_completed=1` after a further 5 seconds. `adb shell monkey` launched TFT, and `dumpsys activity` identified `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity`. The run stayed hidden for the activity window and stopped cleanly.

The sealed capture contains 31 non-empty event files with valid segment and payload hashes. It contains 82,756 GLES2 duration events (source `1401`), 12,749 speculative decoder-probe events (source `1300`), 30 constructor events (source `9001`), 207 guest frame markers (source `1503`), 207 render-control flush pairs (source `1502`), 207 window-surface blit pairs (source `1504`), and 207 `ColorBufferGl` blit pairs (source `1505`).

For both inner spans the measured duration distribution was approximately 92 microseconds minimum, 232 microseconds median, 865 microseconds p95, 2.60 milliseconds p99, and 7.22 milliseconds maximum. Each `1504` and `1505` pair occurred once per `1503` frame marker in this window.

## Result

**`COLOR_BUFFER_BLIT_ADMITTED` — valid diagnostic evidence.** The host copy/resolve operation is reached for every observed render-control frame and is measurable. Its p95 is below the one-millisecond screening target in this activity window, while rare multi-millisecond spans exist. These timings are host-call spans, not GPU execution, SurfaceFlinger latches, unique native delivery, or a continuous 60 FPS result. They do not yet justify changing the copy path.

## Next decision-critical action

Instrument the first post/latch handoff after color-buffer flush (the framebuffer/post-worker path) with the existing guest frame marker, then repeat one hidden real-TFT boot. Measure whether frames wait there before selecting a fast path.
