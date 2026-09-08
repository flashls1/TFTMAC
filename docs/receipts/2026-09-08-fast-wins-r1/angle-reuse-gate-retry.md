# Fast-wins experiment receipt: ANGLE reuse candidate retry

Date: 2026-09-08
Status: **LAUNCH_CORRECTNESS_PASS; PERFORMANCE_UNPROVEN**

## Decision-critical test

The same prebuilt ANGLE buffer-view reuse candidate was relaunched after the
minimum runtime repair that moved synchronous graphics and Riot screenshot
probes off the runtime actor. No driver bytes or runtime settings changed.

## Evidence that the mechanism ran

- Candidate: `dev-observed-reuse-cache-r14`
- ANGLE revision: `1166eec4c0b125e9e945196acfc549983ef72b18`
- Manifest SHA-256:
  `054b8fa9354bb5beb6e501728bbd6f9539f76aceba1e3060fdd9050d4f69cf81`
- Capture: `2026-09-08T17-25-48.466Z-3e363fd6-2c9c-40e6-a636-2e90d073984e`
- Session: `STOPPED`, `2026-09-08T17:25:48Z` to `2026-09-08T17:26:43Z`.
- Live TFT PID: `3740`.
- `ANGLE_DRIVER_LOADED_VERIFIED` recorded all three manifest-matching
  libraries and `reuse_enabled=true`, `variant=\"reuse\"`.
- `TFT_READY_FOR_USER` recorded 1920x1080 at 60 Hz.
- The capture contains 608 `TFT_ANGLE / GUEST_GLES_VULKAN /
  SWAP_AGGREGATE` events, proving the candidate's event producer was active.
  Its short boot/lobby interval recorded zero texture-buffer creates, cache
  hits, or retained views; this is not a gameplay workload.
- Four complete graphics snapshots and 608 pipeline events were sealed. The
  capture still has no presentation-lineage IDs, so it cannot establish
  guest-to-display frame causality.

## Decision

The candidate now passes the launch and mechanism-exercise gate. There is no
FPS, p95/p99, or continuous-60 result in this short run. The candidate must be
measured in an actual TFT match (or a validated replay that exercises the
texture-buffer path) before it can be kept or rejected for performance.
