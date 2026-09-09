# GLES2 decoder duration receipt

**Date:** 2026-09-09 06:20 UTC  
**Decision:** Which host GLES2 decoder calls consume measurable CPU time in the same hidden TFT activity window?

## Mechanism under test

The `gles2_decoder_context_t::decode` loop records a begin/end pair at source site `1401` around each recognized GLES2 switch dispatch. The event carries the GLES opcode in `queue_depth` and the elapsed host decoder time in `duration_ns`. Recording remains opt-in and diagnostic.

The custom host backend build completed successfully. Runtime copy SHA:

`c740889cff3ce59d795c37d0b8ac791be990941feb6ea96fa5b4959496917156`

## Smallest decision test and evidence

The isolated emulator used `-qt-hide-window -read-only`, port `5603`, and the recorder environment. It reached ADB after 10 seconds and `sys.boot_completed=1` after a further 5 seconds. `adb shell monkey` launched TFT, and `dumpsys activity` showed `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity`. After 25 seconds of activity the emulator was stopped with SIGINT.

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r13-gles2-duration`

The capture sealed 26 non-empty segments with 35,925 completed duration spans. Highest aggregate costs in this window were:

```text
glCompileShader                    349 calls   137.994 ms total   p95 892.8 us
glDrawArrays                     1,470 calls    84.226 ms total   p95 451.6 us
glLinkProgram                      176 calls    67.451 ms total   p95 711.5 us
glShaderString                     349 calls    64.671 ms total   p95 378.5 us
glDrawElementsInstancedOffsetAEMU  170 calls    22.074 ms total   p95 529.0 us
glBufferSubData                    498 calls    20.039 ms total   p95 60.2 us
glBlitFramebuffer                   93 calls    19.555 ms total   p95 367.9 us
glReadPixels                        7 calls     9.283 ms total   p95 2.287 ms
```

## Result

**`GLES2_CALL_DURATIONS_ADMITTED` — valid diagnostic evidence.** The host GLES2/gfxstream path is measurable and shader compilation plus draw/resolve work are material in the observed startup/activity window. These totals overlap no frame identity and include any non-TFT graphics sharing the host; they are not a 60 FPS result and do not justify changing shader or draw behavior yet.

## Next decision-critical action

Instrument the host EGL `eglSwapBuffers`/native swap call with a publish-boundary duration and repeat the same hidden TFT boot. Compare swap intervals and decoder spans before selecting a fast path. If swaps are absent, the current window is not presenting through this EGL surface and the presentation route must be classified before optimization.
