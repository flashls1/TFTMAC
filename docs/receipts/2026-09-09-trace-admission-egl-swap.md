# EGL swap-boundary admission receipt

**Date:** 2026-09-09 06:45 UTC  
**Decision:** Does the host `eglSwapBuffers` entry point observe the TFT presentation path in the hidden real-TFT activity window?

## Mechanism under test

The custom gfxstream host backend records a begin/end pair at source site `1501` around `dpy->nativeType()->swapBuffers(Srfc->native())` in `eglSwapBuffers`. The event boundary is `kColorBufferPublish` (`13`). Recording remains opt-in and diagnostic.

## Smallest decision test and evidence

The newly built backend was copied into the isolated runtime and loaded by a hidden emulator using `-qt-hide-window -read-only`, console port `5605`, and the private pipeline recorder. Runtime backend SHA-256:

`d06077225c0d4e08c2c59dd51683313c95a509b4b8d03e99cacabde709b93e8e`

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r14-egl-swap`

The emulator reached ADB after 9 seconds and `sys.boot_completed=1` after a further 5 seconds. `adb shell monkey` launched TFT, and `dumpsys activity` identified `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity`. The run stayed hidden for the activity window and stopped cleanly.

The sealed capture contains 30 segment headers and 91,226 events. All segment and payload hashes validated. The current backend generated 78,614 actual GLES2 duration events (source `1401`), 12,582 speculative decoder-probe events (source `1300`), and 30 decoder-constructor events (source `9001`). It generated **zero** source `1501` begin events and **zero** source `1501` end events.

## Result

**`EGL_SWAP_NOT_ADMITTED` — valid negative diagnostic evidence.** The current TFT window does not reach this `eglSwapBuffers` entry point, despite the exact custom backend being loaded and the real TFT GLES decoder being active. This hook cannot yet identify frame delivery or justify an optimization. The prior GLES decoder evidence remains valid for host-call timing, but has no presentation identity.

## Next decision-critical action

Instrument the next concrete native swap boundary used by this backend (`EglOS`/Darwin `nsSwapBuffers`) with a distinct source site, then repeat one hidden real-TFT boot. Do not alter ANGLE, shader, fence, transport, quality, or emulator settings until a swap/publish event is admitted and tied to the TFT process.
