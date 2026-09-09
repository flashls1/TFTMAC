# Direct Vulkan marker admission receipt

**Date:** 2026-09-09 05:13 UTC  
**Decision:** Does the existing direct Vulkan trace marker reach the host gfxstream decoder during a real TFT process?

## Mechanism under test

The host `OP_vkTraceAsyncGOOGLE` decoder case was instrumented at source site `1101`. When a non-zero marker ID is decoded, the hook records a `kGfxstreamDecode` instant event while carrying that ID as `transport_work_id`. The recorder remained opt-in through `TFTMAC_PIPELINE_EVENT_V1=1` and `TFTMAC_PIPELINE_EVENTS_DIR`.

Host build target `libgfxstream_backend.dylib` completed successfully. The runtime manifest was:

```text
runtime=/Volumes/TFTMAC-Causal-Source/Build/causal-angle-sideband-20260909/aemu-runtime-direct-host-20260909
emulator_sha=b6ff8c61dfefc39ee16cfb52e8904416fa3a79632113fba9a39482e36f77bcaf
host_gfxstream_sha=1db6e615a6a8df77d3a2844b155cab95fc3558f0ce5a0ffb5150ed13fc786b12
guest_angle_gles_sha=bd9b177a1e803bd35575261c7e76c3b232428bffcf5833c04b503d578e450652
marker_hook_source=vk_decoder.cpp:OP_vkTraceAsyncGOOGLE:source_site_1101
```

The guest remained the stock ANGLE library for this admission test. No app, credential, quality, or Control change was made.

## Smallest decision test and evidence

The isolated emulator was started with `-qt-hide-window -read-only`, port `5587`, and the pipeline recorder environment. It reached `sys.boot_completed=1`. `adb shell monkey` launched `com.riotgames.league.teamfighttactics`, and `dumpsys activity` identified `com.epicgames.unreal.GameActivity` with TFT process PID `3831`. The run remained active for approximately 35–45 seconds before clean SIGINT shutdown.

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r5-direct-host`

The capture contains the launch manifest, foreground emulator log, monkey result, and activity evidence. `pipeline-events/` contained zero sealed segment files and no `TFTPIPE1` bytes after the real TFT process was active.

## Result

**`DIRECT_MARKER_NOT_ADMITTED` — negative evidence.** The host hook compiled and the real TFT activity ran, but no direct marker event was produced. This does not prove that no Vulkan work reached the host; it proves only that this marker path did not provide mechanism-exercise evidence. The ANGLE view/fence optimization batches remain gated and were not run.

The preceding custom-ANGLE overlay attempt (`20260909-r4-direct-marker`) also exited before ADB with no fatal message captured; its artifact is preserved separately as a startup failure. It is not used as performance evidence.

## Next decision-critical action

Instrument one host queue-submit decoder case with a host-generated admission ID and immediately repeat the same hidden real-TFT boot. If that produces sealed events, the result will establish host queue-submit admission only; it will not be presented as complete guest-to-display lineage or as a 60 FPS result.
