# Render-control frame-number linkage receipt

**Date:** 2026-09-09 07:05 UTC  
**Decision:** Does the guest `rcFlushWindowColorBufferAsyncWithFrameNumber` command identify the same frame work observed by the host color-buffer flush hook?

## Mechanism under test

The render-control decoder records an instant source site `1503` for opcode `OP_rcFlushWindowColorBufferAsyncWithFrameNumber`. The event carries the decoded window-surface handle in `queue_depth` and the guest frame number in `duration_ns`. The existing source site `1502` begin/end pair surrounds the host `rcFlushWindowColorBuffer` implementation. Recording remains opt-in and diagnostic.

## Smallest decision test and evidence

The rebuilt backend was copied into the isolated runtime and loaded by a hidden emulator using `-qt-hide-window -read-only`, console port `5609`, and the private pipeline recorder. Runtime backend SHA-256:

`3f60165621fd3a57cf2055475a07c671d53144131a9e3689ea9cdec3fd1caa42`

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r16-rc-opcode`

The emulator reached ADB after 9 seconds and `sys.boot_completed=1` after a further 5 seconds. `adb shell monkey` launched TFT, and `dumpsys activity` identified `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity`. The run stayed hidden for the activity window and stopped cleanly.

The sealed capture contains 30 non-empty event files with valid segment and payload hashes. It contains 82,860 GLES2 duration events (source `1401`), 12,812 speculative decoder-probe events (source `1300`), 29 constructor events (source `9001`), 402 flush events (source `1502`: 201 begin and 201 end), and 201 decoder markers (source `1503`). The first markers carry frame numbers `0`, `1`, `2`, `3`, and `4`; their window handles match the `queue_depth` value on the corresponding `1502` begin/end pair. All 201 marker events have a matching flush pair.

## Result

**`RENDER_CONTROL_FRAME_LINK_ADMITTED` — valid diagnostic evidence.** The guest render-control frame-number command is present and aligns one-for-one with the host color-buffer flush work in this real TFT `GameActivity` window. This establishes a frame identity at the guest-protocol-to-host-publish boundary. It still does not prove SurfaceFlinger/HWC latch or unique native delivery, and the window is not a gameplay or 60 FPS acceptance run.

## Next decision-critical action

Instrument the concrete copy stage inside `EmulatedEglWindowSurface::flushColorBuffer` and the following `ColorBufferGl` flush/blit with distinct source sites, preserving the frame handle linkage, then repeat one hidden real-TFT boot. Use those spans to decide whether host copy/resolve time is material before considering any optimization.
