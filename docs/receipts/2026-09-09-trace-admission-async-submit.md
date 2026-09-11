# Host asynchronous queue-submit admission receipt

**Date:** 2026-09-09 05:24 UTC  
**Decision:** Does the adjacent `OP_vkQueueSubmitAsyncGOOGLE` decoder case receive real TFT submissions when the opt-in recorder is enabled?

## Mechanism under test

The host `OP_vkQueueSubmitAsyncGOOGLE` decoder case was instrumented at source site `1201`. When the recorder is enabled, it allocates a host-local ID, records a `kHostVulkanSubmit` begin/end pair around `m_state->on_vkQueueSubmitAsyncGOOGLE`, and restores the prior transport ID. The already present timeline-sideband and direct-marker probes were left unchanged. This is an admission probe only.

Build target `libgfxstream_backend.dylib` completed successfully. The runtime copy SHA was:

`9a7178e9de8e0d5c12484aae9c709d207df2c8df5ffe0436693da55243611aaf`

## Smallest decision test and evidence

The isolated emulator used `-qt-hide-window -read-only`, port `5591`, and the recorder environment. It reached ADB after 10 seconds and `sys.boot_completed=1` after a further 5 seconds. `adb shell monkey` launched `com.riotgames.league.teamfighttactics`; `dumpsys activity` showed `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity` as the top activity. The process remained active for 35 seconds, then the emulator was stopped with SIGINT.

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r7-async-submit`

The capture contains the launch manifest, foreground emulator log, monkey result, and activity dumps. The `pipeline-events/` directory contained zero files and zero bytes after TFT activity was present. No `TFTPIPE1` segment was sealed.

## Result

**`ASYNC_SUBMIT_NOT_ADMITTED` — negative evidence.** Neither the synchronous nor asynchronous host queue-submit probe produced a recorder artifact during real TFT activity. Along with the prior `DIRECT_MARKER_NOT_ADMITTED` result, this means no host decoder mechanism-exercise evidence exists yet. It does not prove that the GPU path is idle, and it does not identify a late-frame owner. ANGLE view/fence optimization work remains gated.

## Next decision-critical action

Verify that the custom `libgfxstream_backend.dylib` is the library loaded by the emulator and that the recorder environment reaches its host process. Use one hidden launch with dynamic-library load tracing and the existing verbose log. If either is absent, repair only that runtime propagation/load boundary and retry this admission test; do not add more decoder hooks.
