# Host synchronous queue-submit admission receipt

**Date:** 2026-09-09 05:17 UTC  
**Decision:** Does the first host `OP_vkQueueSubmit` decoder case receive real TFT submissions when the opt-in recorder is enabled?

## Mechanism under test

The host `OP_vkQueueSubmit` decoder case was instrumented at source site `1201`. When the recorder is enabled, it allocates a host-local monotonic ID, records a `kHostVulkanSubmit` begin/end pair around `m_state->on_vkQueueSubmit`, and restores the prior transport ID. This is an admission probe only; it does not claim guest identity or display lineage.

Build target `libgfxstream_backend.dylib` completed successfully. The resulting SHA was:

`6b08c3a66a6b4d0637e6754eecc17cdb2261e92f4dff16e27ca3b590cf76e4e5`

## Smallest decision test and evidence

The isolated emulator used `-qt-hide-window -read-only`, port `5589`, and the recorder environment. It reached ADB after 11 seconds and `sys.boot_completed=1` after a further 4 seconds. `adb shell monkey` launched `com.riotgames.league.teamfighttactics`; `dumpsys activity` showed `com.epicgames.unreal.league.teamfighttactics/com.epicgames.unreal.GameActivity` as the top activity. The process remained active for 35 seconds, then the emulator was stopped with SIGINT.

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r6-direct-submit`

The capture contains `manifest.txt`, `foreground.log`, `monkey.log`, and activity dumps. The `pipeline-events/` directory contained zero files and zero bytes after TFT activity was present. No `TFTPIPE1` segment was sealed.

## Result

**`SYNC_SUBMIT_NOT_ADMITTED` — negative evidence.** The real TFT process ran, but the synchronous queue-submit probe produced no recorder artifact. This indicates TFT did not exercise this decoder case, or the host backend did not inherit/enable the recorder on the decoder thread. It does not identify the late frame owner and does not justify an optimization.

The command’s wildcard byte-count diagnostic reported an expected “no matches” shell message because the directory was empty; this did not alter the capture or emulator state.

## Next decision-critical action

Instrument the adjacent `OP_vkQueueSubmitAsyncGOOGLE` decoder case only, rebuild the host dylib, and repeat the same hidden TFT boot. If that also produces no events, stop expanding host hooks and classify recorder inheritance/host-path reachability as the blocker before any ANGLE or fence work.
