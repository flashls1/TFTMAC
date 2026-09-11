# Fast-wins real-match receipt: ANGLE reuse candidate

Date: 2026-09-08
Status: **PERFORMANCE_FAILURE; CANDIDATE NOT PROMOTED**

## Workload and identity

- Capture: `2026-09-08T17-30-36.264Z-7f4423a4-0eea-4e47-a849-e8a355f54bdd`
- Session: `STOPPED`, `2026-09-08T17:30:36Z` to `2026-09-08T17:36:47Z`.
- Candidate: `dev-observed-reuse-cache-r14`
- ANGLE revision: `1166eec4c0b125e9e945196acfc549983ef72b18`
- Manifest SHA-256: `054b8fa9354bb5beb6e501728bbd6f9539f76aceba1e3060fdd9050d4f69cf81`
- The live TFT process (PID 3915) emitted `ANGLE_DRIVER_LOADED_VERIFIED` with all
  three manifest library hashes and `reuse_enabled=true`.
- `TFT_READY_FOR_USER` was recorded at 1920x1080 / 60 Hz. The active match
  interval began after the final login SurfaceView replacement at 17:31:24Z and
  ended at the owned emulator stop at 17:36:21Z.

## Actual TFT presentation result

For the 147 nonempty available windows in that match interval:

- Median window FPS: 59.79; mean: 57.21; minimum: 6.98.
- 106/147 windows (72.1%) were below 60 FPS; 18 were below 55 FPS.
- Aggregate frame-interval p95: 18.346 ms; p99: 32.832 ms; maximum: 2,847.756 ms.
- 16,737 frame intervals were recorded; 422 exceeded 20 ms, 147 exceeded
  33.3 ms, and 30 exceeded 100 ms.
- 258 janky intervals, 61 severe intervals, and 763 missed-vsync equivalents
  were recorded.
- Input dispatch remained responsive: 1,539 RPC acknowledgements, zero failures;
  dispatch-to-RPC acknowledgement ranged from 0.25 ms to 14.79 ms.

This fails the continuous-60 acceptance gate. The Mac presenter’s 60 Hz cadence
is not used as a substitute for these TFT SurfaceFlinger intervals.

## ANGLE reuse evidence

The capture contained 17,535 `SWAP_AGGREGATE` and 281,541
`CREATE_BUFFER_VIEW` events from the actual TFT process. The normalized
ANGLE evidence reported:

- `retainedBindings=0`, `retainedSyncs=0`, `unchanged=0`;
- `creations=688,741`, `invalidatedSyncs=688,741`, and `create_call_ns=30,031,103,608`;
- `allocation_changed=4,509`, with no observed range or format changes;
- `cache_hits=882,754`, which did not result in retained view bindings;
- `missingSpans=407,200` and `malformed=9,458`.

The feature was selected and exercised, but the candidate did not demonstrate
view retention in this workload. The incomplete producer evidence also prevents
using the aggregate nanoseconds as a precise causal frame budget. The candidate
is rejected for performance pending a corrected reuse path and a repeatable
matched comparison.

## Shutdown stall

TFT frame checkpoints continued through 17:36:17Z. The emulator exit was
confirmed at 17:36:24Z, but `ANGLE_EVIDENCE_FINALIZED` was not recorded until
17:36:47Z. The 23-second post-exit gap corresponds to synchronous normalization
of the 299,076-event ANGLE stream during cleanup. This is a shutdown/finalization
latency defect, separate from the in-match rendering result.

Sealed SQLite SHA-256: `62ce91fadf1cbc124e7f8a865d4db871a3d6bf24b7e54124f87dea535fd90282`.
Sealed ANGLE evidence SHA-256: `879162163d091770c273992bf3ce8eba786f81013005dc030c2f7b0c593b1b54`.
