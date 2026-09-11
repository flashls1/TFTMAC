# TFTMAC Results Log — Results-First Pass

Date: 2026-09-10

Use: one hypothesis at a time. Record WIN / NO WIN / INCONCLUSIVE, preserve proven wins, restore baseline after failures, and move forward. Do not expand diagnostics merely to explain a failed candidate.

## Accepted baseline

CONTROL_GREEN — PASS.
- Official current TFT client, 1920x1080, 8 vCPU, 6144 MiB, OpenGL/ANGLE.
- Native authoritative combat windows: 1-1 = 48.83 FPS; 1-2 = 53.65 / 44.57 / 53.61 FPS.
- Normal shutdown and exact AVD baseline restoration verified.

## P1 — Buffer-view retention

Result: NO WIN.
- Existing real-match candidate `dev-observed-reuse-cache-r14` loaded and exercised successfully.
- `retainedBindings=0`, `retainedSyncs=0`, `unchanged=0`.
- Real-match mean 57.21 FPS; 106/147 windows below 60 FPS; continuous-60 gate failed.
- Decision: do not build split-reason infrastructure now. Preserve evidence for later factor isolation only if we return to this family.

## P2 — Cache

### `cache-no-global-sync`
Result: VERIFIED WIN — RETAIN AS WORKING CACHE SETTING.
- Candidate delta is only removal of `syncMonolithicPipelinesToBlobCache`; `debug.egl.blobcache.multifile=true` and `preferSubmitAtFBOBoundary` disabled remain unchanged.
- First valid direct no-root comparison: 1-1 was neutral at 48.78 vs 48.83 FPS; 1-2 three-window mean was 55.68 vs 50.61 FPS (+10.0%), with mean p95 20.59 vs 23.39 ms (-11.9%) and p99 27.12 vs 31.29 ms (-13.3%).
- Confirmation resumed at later Trials progress rather than 1-1. Exact same-stage 1-4 comparison: no-global-sync 54.48 FPS vs matched LKG control 52.07 FPS (+4.6%); p95 22.41 vs 30.33 ms (-26.1%); p99 29.27 vs 37.47 ms (-21.9%); severe intervals 0 vs 3.
- Exact 30-window 1-5 head-to-head: no-global-sync mean 54.92 FPS vs LKG control 55.73 FPS (-1.5%), but p95 improved 15.9%, p99 improved 19.4%, jank per window improved 67.9%, missed-vsync per window improved 70.3%, severe intervals fell 7 -> 1, and worst interval improved 100.09 -> 57.88 ms.
- Interpretation: this is a verified frame-pacing/tail-latency win, not a claim that mean FPS rises in every stage. The setting materially reduces stalls and missed presentation work while average FPS remains broadly comparable and improved in the earlier 1-2/1-4 samples.
- Both candidate and matched-control runs verified official client 18.1-5423749, 1920x1080, 8 vCPU, 6144 MiB, OpenGL/ANGLE, exact requested cache properties, and clean AVD/LKG rollback. No profiler, trace, VM, runtime copy, or new build was used.
- Decision: retain removal of `syncMonolithicPipelinesToBlobCache` as the new working cache winner. Preserve the prior LKG/global-sync configuration unchanged as historical control evidence.

### `cache-current`
Result: BASELINE / NO INDEPENDENT WIN YET.
- This property set is the accepted Sept.10 LKG/CONTROL property set and therefore already represented by CONTROL_GREEN.
- No separate candidate benefit can be claimed without a valid comparator.

## P3 — Direct Vulkan

Result: NO WIN for the fast-pass.
- One bounded clean canary was attempted using the full LKG plus only the Vulkan RHI delta; the lab route was INCONCLUSIVE because its post-launch ADB-root step did not become effective. Exact rollback and AVD restoration passed.
- The existing DEVHighPerf authority already records the decisive candidate behavior: removing the Vulkan-disable flag selected direct Vulkan and caused Metal vertex-descriptor failures during Trials loading.
- Decision: do not build or repair a Vulkan path in this pass. Preserve the evidence for later deep isolation only if we explicitly return to this family.

## Evidence-backed follow-up — Queue Submit Inline

Result: NO WIN / BOOT-INCOMPATIBLE.
- Prior official-client campaign result was BOOT_FAILED, but that run was confounded by low host storage.
- Retested once on 2026-09-10 with adequate storage using the existing DEV preset only: `-VulkanQueueSubmitWithCommands`.
- Native telemetry sealed profile `queue_submit_inline`, workload `official_tft`, with exactly that one emulator-feature override.
- Emulator/ADB never reached readiness; no FPS result was fabricated.
- Cleanup passed: exact AVD SHA restored, DEV/emulator stopped, installed app and LKG integrity verified.
- Decision: reject this setting for the fast-pass; no boot-repair loop.

## Current fast-pass scoreboard

- CONTROL_GREEN: ACCEPTED BASELINE.
- Buffer-view retention: NO WIN.
- Cache no-global-sync: VERIFIED WIN — RETAIN; confirmed frame-pacing/tail-latency improvement.
- Current cache/global-sync: historical LKG control; superseded as the working cache setting by no-global-sync, but preserved unchanged for comparison evidence.
- Direct Vulkan: NO WIN.
- Queue Submit Inline: NO WIN / BOOT-INCOMPATIBLE.
- Virtual Queue Off: prior official-client REJECTED_BELOW_60; do not rerun in this pass.
- Fence Contexts Off: prior official-client REJECTED_BELOW_60; do not rerun in this pass.
- New proven fast wins found in this pass: `cache-no-global-sync` — VERIFIED frame-pacing win.
