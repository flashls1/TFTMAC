# Host `vkQueueSubmit2` admission receipt

**Date:** 2026-09-09 05:36 UTC  
**Decision:** Does the host `OP_vkQueueSubmit2` decoder case receive real TFT submissions when the opt-in recorder is enabled?

## Mechanism under test

The host `OP_vkQueueSubmit2` decoder case was instrumented at source site `1202`. When enabled, it allocates a host-local ID, records a `kHostVulkanSubmit` begin/end pair around `m_state->on_vkQueueSubmit2`, and restores the prior transport ID. This is an admission probe only.

Build target `libgfxstream_backend.dylib` completed successfully. The runtime copy SHA was:

`e64cbd30ddaaef9d47cbe7a506532db6b9ab9e9cb9d64f52125a311a4dc02149`

## Smallest decision test and evidence

The isolated emulator used `-qt-hide-window -read-only`, port `5595`, and the recorder environment. It reached ADB after 11 seconds and `sys.boot_completed=1` after a further 4 seconds. `adb shell monkey` launched `com.riotgames.league.teamfighttactics`; `dumpsys activity` showed `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity` as the top activity. The process remained active for 35 seconds, then the emulator was stopped with SIGINT.

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r9-submit2`

The capture contains the launch manifest, foreground emulator log, monkey result, and activity dumps. The `pipeline-events/` directory contained zero files and zero bytes after TFT activity was present. No `TFTPIPE1` segment was sealed.

## Result

**`SUBMIT2_NOT_ADMITTED` — negative evidence.** The real TFT process ran, but the `vkQueueSubmit2` probe produced no recorder artifact. Together with the sync, async, and direct-marker negatives, this still does not identify the late-frame owner. No optimization batch advanced.

## Next decision-critical action

Run the constructor-level recorder admission check described in the load receipt before adding another decoder case.
