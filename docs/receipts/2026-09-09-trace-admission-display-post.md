# Display post admission receipt

**Date:** 2026-09-09 07:35 UTC  
**Decision:** Does the hidden diagnostic emulator enter the host `DisplayGl::post` path that swaps the emulator display surface?

## Mechanism under test

The host `DisplayGl::post` path records source site `1506` around its layer composition and `eglSwapBuffers` call. The event boundary is `kSourceFramePublish` (`14`). The probe is guarded and opt-in.

## Smallest decision test and evidence

The rebuilt backend was copied into the isolated runtime and loaded by a hidden emulator using `-qt-hide-window -read-only`, console port `5613`, and the private pipeline recorder. Runtime backend SHA-256:

`0a10255fa623f548f0daf5cf552120052a168dc76014a980779c084221c930bb`

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r18-display-post`

The emulator reached ADB after 10 seconds and `sys.boot_completed=1` after a further 5 seconds. `adb shell monkey` launched TFT, and `dumpsys activity` identified `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity`. The run stayed hidden for the activity window and stopped cleanly.

The sealed capture contains 29 non-empty event files with valid segment and payload hashes. It contains 85,672 GLES2 duration events (source `1401`), 12,896 speculative decoder-probe events (source `1300`), 28 constructor events (source `9001`), 213 guest frame markers (source `1503`), and 213 pairs each for the render-control flush (`1502`), window blit (`1504`), and `ColorBufferGl` blit (`1505`). It contains **zero** source `1506` begin or end events.

## Result

**`DISPLAY_POST_NOT_ADMITTED` — valid negative diagnostic evidence.** The `-qt-hide-window` diagnostic configuration does not create the host display sub-window, so the post-worker/display-surface swap path is not exercised. Hidden runs can prove guest protocol, host GLES, color-buffer flush, and blit work, but cannot prove native display cadence or unique delivered frames.

## Next decision-critical action

Analyze the existing real-game captures for the first late-frame boundary using their authoritative TFT presentation and resource records. Do not infer a 60 FPS result from this hidden run and do not change the graphics path until a gameplay boundary is shown to be material.
