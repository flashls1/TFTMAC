# Host backend load and recorder propagation check

**Date:** 2026-09-09 05:31 UTC  
**Decision:** Was the custom host gfxstream backend actually loaded by the hidden emulator, and did this test produce pipeline events?

## Smallest decision test and evidence

R8 started the isolated runtime with `-qt-hide-window -read-only`, port `5593`, `TFTMAC_PIPELINE_EVENT_V1=1`, and a private events directory. `DYLD_PRINT_LIBRARIES=1` printed the exact loaded path:

`/Volumes/TFTMAC-Causal-Source/Build/causal-angle-sideband-20260909/aemu-runtime-direct-host-20260909/lib64/libgfxstream_backend.dylib`

The emulator reached ADB after 10 seconds and `sys.boot_completed=1` after a further 5 seconds. TFT was launched with `adb shell monkey`, and `dumpsys activity` showed `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity`. The hidden emulator was then stopped with SIGINT.

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r8-load-check`

## Result

**`HOST_BACKEND_LOADED_NO_EVENTS` — partial negative evidence.** The custom dylib load is proven, but no pipeline segment was produced. This narrows the missing evidence to recorder initialization/reachability or an uninstrumented host path. It does not justify an ANGLE or fence optimization and is not a performance result.

Runtime copy SHA during R8:

`9a7178e9de8e0d5c12484aae9c709d207df2c8df5ffe0436693da55243611aaf`

## Next decision-critical action

Emit one opt-in recorder admission event from the `VkDecoder::Impl` constructor. If no segment appears, the recorder environment or initialization is the blocker; if it appears, continue with only the submit family that is shown to execute.
