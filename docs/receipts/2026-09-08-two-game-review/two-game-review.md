# Two recent TFT gameplay capture review — 2026-09-08

> This receipt reviews the two newest `STOPPED` captures with long TFT process intervals. It adds derived, sanitized evidence to the project and does not modify either raw capture.

## Selection and evidence boundary

The two selected captures are the newest long sessions that ended cleanly: the Sep 8 run lasted about 39m44s with a TFT process present, and the Sep 7 run lasted about 45m45s. Both use profile `tftmac_diagnostic_stock_shadow_r1`, the same configuration SHA, 1920×1080 at 60 Hz, and the same observed stack (Unreal Vulkan → gfxstream → host Vulkan/MoltenVK → Metal).

The logs prove a real TFT process, an active TFT surface, and thousands of visual checkpoints. They do **not** encode TFT stage/combat/round semantics, so this receipt cannot certify that either interval was a complete match or compare a particular combat scene. The FPS results below are therefore diagnostic session evidence, not final continuous-60 acceptance.

## Session results

| Measure | Sep 8 capture | Sep 7 capture |
| --- | ---: | ---: |
| Session / process duration | 39.73 min | 45.75 min |
| Available frame windows | 2148 / 2174 (98.80%) | 2458 / 2494 (98.56%) |
| Effective FPS median / p05 / minimum | 59.21 / 30.76 / 0.00 | 59.37 / 32.97 / 0.00 |
| Windows below 60 / 50 / 30 FPS | 1597 (74.35%) / 486 (22.63%) / 90 (4.19%) | 1737 (70.67%) / 498 (20.26%) / 85 (3.46%) |
| Per-window p95 interval: median / p95 | 18.38 / 46.62 ms | 18.33 / 46.66 ms |
| Per-window p99 interval p95 | 92.35 ms | 80.87 ms |
| Jank / severe / missed-vsync totals | 11062 / 422 / 14588 | 11403 / 497 / 14273 |
| Worst available window | 4.40 FPS; 3299.5 ms p95; 3299.5 ms max | 14.64 FPS; 1330.8 ms p95; 1330.8 ms max |
| Native callbacks / unique source transitions / repeats | 143799 / 127464 / 16335 (11.36%) | 165231 / 148931 / 16300 (9.86%) |
| Presentation sample mailbox replacements / sequence drops | 13461 / 0 | 157982 / 101793 |
| Host p95 completion / GPU p95 (median window) | 1.00 / 0.34 ms | 1.13 / 0.36 ms |
| Host max window p95 completion / GPU | 2.72 / 1.73 ms | 9.66 / 1.82 ms |
| Host drawable misses / command errors | 0 / 0 | 0 / 0 |
| Emulator CPU p50 / p95 / max | 278.9 / 357.4 / 623.6% | 271.4 / 350.6 / 636.1% |
| Emulator RSS p50 / p95 / max | 2382 MiB / 3085 MiB / 3906 MiB | 2010 MiB / 2895 MiB / 4252 MiB |
| SurfaceFlinger render rate / last total,HWC,GPU missed | 60.0 Hz / 102,102,0 | 60.0 Hz / 99,99,0 |
| Pipeline events / diagnostic epochs | 0 / 0 | 0 / 0 |

## What the two captures show

1. **The limiting path is upstream of confirmed host GPU execution.** Both sessions report an active Unreal Vulkan process, gfxstream, MoltenVK on Apple M4, and 60 Hz SurfaceFlinger. Host presentation windows have sub-1.2 ms median p95 completion and sub-0.4 ms median p95 GPU time, with no drawable misses or command errors. That does not prove the host is perfect, but these logs do not show host Metal/GPU saturation as the cause of the frame loss.
2. **TFT frame production/presentation is not continuously 60.** Between 70.67% and 74.35% of available one-second windows are below 60 FPS. The p95 of each window’s p95 interval is about 46.6 ms, and the p95 of p99 intervals is 80.9–92.3 ms. Each run has hundreds of severe windows and worst windows at 4.40 and 14.64 FPS. These are direct SurfaceView interval measurements, so the continuous-60 acceptance fails.
3. **The native presenter often repeats or replaces source content.** About 9.86–11.36% of native callbacks repeat the previous source sequence. Game 2 also records 101,793 cumulative sequence-drop counts and 157,982 mailbox replacements in presentation samples, versus zero and 13,461 in Game 1. This is useful transport/presenter evidence, but the current recorder has no shared cross-stack frame ID, so it cannot prove which upstream operation caused each drop or what was visible on the physical display.
4. **The recorder has known coverage gaps.** Each run has one startup `GAME_FRAME_COLLECTOR_UNAVAILABLE` caused by ADB reporting the device offline, leaving 26/36 unavailable windows. Both have zero `pipeline_events`, zero diagnostic epochs, and zero pipeline segments. The stack receipt therefore remains correlated component evidence rather than guest→host→display causal attribution.
5. **No fatal runtime/input/audio failure explains the result.** Neither run records an ANR, input timeout, fatal crash, or memory kill. Audio samples show zero partial and empty underruns. The runtime incident aggregate does contain audio log-error counts (1,480 and 972); those are log-message counts, not measured underruns, and should not be treated as the graphics cause.

## Login/launch observations in these captures

Sep 8 records one and Sep 7 records two `RIOT_SAVED_SIGNIN_STOPPED` receipts with a redacted classification of an unreadable DEV Keychain item. Manual sign-in remained available. This is separate from frame timing, but it means these captures do not prove automatic saved login. The current report intentionally stores no username, password, Keychain item data, or raw log text.

## Decision and next action

**Decision: retain as diagnostic evidence; reject continuous-60 acceptance and do not credit the ANGLE buffer-view hypothesis from these sessions.** The next experiment should first close the two evidence gaps that prevent a causal decision: (a) remove the startup ADB-offline collector gap, and (b) emit/verify request, submission, and presentation identities in a short controlled heavy-combat capture. Only then should a driver or scheduling batch be judged by recoverable critical-path milliseconds. A host-GPU rewrite is not justified by these logs.

## Raw capture receipts

| Run | Capture ID | SQLite SHA-256 |
| --- | --- | --- |
| Game 1 (newest completed long TFT session) | `2026-09-08T13-11-58.729Z-7be114c0-a92d-4197-b983-b98e498127fb` | `34480bf2d1dbf72d51569cb84a427fad9fe3053063aaabe95c08f8f02486d282` |
| Game 2 (previous completed long TFT session) | `2026-09-07T00-51-11.665Z-81c30ae4-e52f-4e02-b1c8-165c4e2cdb81` | `6affb9bf477c79372351d645217775b2247320f691797fa3d41a1ce9048a7863` |

The raw directories remain under `/Users/flash/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures/`. The machine-readable source for all derived values is [`two-game-review.json`](two-game-review.json).

Report generated from local SQLite reads at `2026-09-08T16:24:07Z`.
