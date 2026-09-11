# Render-control color-buffer flush receipt

**Date:** 2026-09-09 06:55 UTC  
**Decision:** Does the render-control color-buffer flush used by the guest reach the host publish path during a hidden real-TFT activity window?

## Mechanism under test

The custom gfxstream host backend records a begin/end pair at source site `1502` around `rcFlushWindowColorBuffer`. The event boundary is `kColorBufferPublish` (`13`), and `queue_depth` carries the guest window-surface handle. Recording remains opt-in and diagnostic.

## Smallest decision test and evidence

The rebuilt backend was copied into the isolated runtime and loaded by a hidden emulator using `-qt-hide-window -read-only`, console port `5607`, and the private pipeline recorder. Runtime backend SHA-256:

`097743b9a0a056988d2858ea366d6d4d4766500c7f1cebfd236c753323db34e3`

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r15-rc-flush`

The emulator reached ADB after 9 seconds and `sys.boot_completed=1` after a further 5 seconds. `adb shell monkey` launched TFT, and `dumpsys activity` identified `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity`. The run stayed hidden for the activity window and stopped cleanly.

The sealed capture contains 29 non-empty event files. All 29 segment/payload hashes validated. It contains 79,181 GLES2 duration events (source `1401`), 12,625 speculative decoder-probe events (source `1300`), 28 decoder-constructor events (source `9001`), and 374 render-control flush events (source `1502`): 187 begin and 187 end pairs.

For the 187 completed flush spans, duration was 102.25 microseconds minimum, 240.5 microseconds median, 714.25 microseconds p95, 3.164542 milliseconds p99, and 3.298083 milliseconds maximum. The 186 begin-to-begin intervals had a 17.960625 millisecond median, 141.60125 millisecond p95, 1,178.240625 millisecond p99, and a 22,173.910667 millisecond maximum; long gaps include startup and transitions and must not be treated as a display cadence.

## Result

**`RENDER_CONTROL_FLUSH_ADMITTED` — valid diagnostic evidence.** The current guest-to-host path reaches `rcFlushWindowColorBuffer`; the hook sees repeated color-buffer publish work during the real TFT `GameActivity`. This is host flush timing only. It does not identify SurfaceFlinger/HWC latches, unique native delivery, or a continuous frame rate, and it does not yet establish that every observed flush belongs to TFT rather than another guest surface.

## Next decision-critical action

Add one narrow render-control decoder identity marker at the `rcFlushWindowColorBufferAsyncWithFrameNumber` opcode, carrying the decoded window handle and frame number, then repeat one hidden real-TFT boot. Use that marker to connect guest protocol work to source-site `1502`; do not change ANGLE, shaders, fences, transport, quality, or emulator settings before that linkage exists.
