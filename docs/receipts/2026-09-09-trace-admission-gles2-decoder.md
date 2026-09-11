# Actual host GLES2 decoder admission receipt

**Date:** 2026-09-09 05:58 UTC  
**Decision:** Is TFT's active rendering stream reaching the host GLES2 decoder, and which GL operations are present?

## Mechanism under test

The host `gles2_decoder_context_t::decode` loop records an opt-in `kGfxstreamDecode` instant at source site `1400`, carrying the decoded GLES opcode in `queue_depth`. The existing Vulkan decoder probe remains in place only to show that its earlier events were speculative parser attempts. The GLES2 target received the existing `PipelineEventV1` include path; no optimization or quality setting changed.

The custom host backend build completed successfully. Runtime copy SHA:

`5c9d532aae1444d65ecaa0d7c56b0b2fcd0be57dbb09292b695496a5ed509659`

## Smallest decision test and evidence

The isolated emulator used `-qt-hide-window -read-only`, port `5601`, and the recorder environment. It reached ADB after 14 seconds and `sys.boot_completed=1` after a further 5 seconds. `adb shell monkey` launched `com.riotgames.league.teamfighttactics`; `dumpsys activity` showed `com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity` as the top activity. The hidden emulator was stopped with SIGINT after 25 seconds of activity.

Capture directory:

`/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r12-gles2`

The capture sealed 28 non-empty `TFTPIPE1` segments containing 43,407 GLES decoder events and 12,792 speculative Vulkan decoder events. The most frequent GLES opcodes were:

```text
glTexParameteri                 3,242
glVertexAttribPointerOffset     2,861
glBindTexture                   2,766
glGetUniformLocation             2,434
glUniformMatrix3fv               1,951
glDrawArrays                    1,731
glUseProgram                    1,563
glGetProgramiv                  1,400
glBindFramebuffer               1,384
glClear                         991
```

The complete opcode histogram is derived from the sealed capture with `gles2_opcodes.h`; unknown `100xx` values are retained rather than discarded because they may be render-control traffic seen during decoder probing.

## Result

**`GLES2_DECODER_ADMITTED` — valid mechanism-exercise evidence.** The actual host GLES2 decoder is receiving a sustained GL stream while TFT's Unreal `GameActivity` is active. This corrects the earlier Vulkan-decoder targeting error. It identifies the guest-to-host GLES/gfxstream boundary as reachable; it does not yet prove that all recorded commands belong exclusively to TFT or identify the late-frame owner. No 60 FPS claim is made.

## Next decision-critical action

Add one duration pair around the GLES2 decoder's actual switch dispatch, keyed by opcode, then repeat the same hidden TFT boot. Use those durations and the existing frame data to choose the first measured bottleneck. Do not start ANGLE view reuse, shader translation, fence fast paths, or router work before that result.
