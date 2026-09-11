# Fast-wins lifecycle comparator: stock DEV

Date: 2026-09-08
Status: **BASELINE_LIFECYCLE_PASS; PERFORMANCE_INCONCLUSIVE**

## Decision-critical test

After the reuse candidate failed before readiness, stock DEV was launched with
the same packaged lifecycle and no experimental driver manifest. The test was
only to distinguish a candidate-specific launch failure from a general DEV
launch failure. It was stopped through the application quit path so the
capture could finalize.

## Evidence

- Profile: `tftmac_diagnostic_stock_shadow_r1`
- Capture:
  `2026-09-08T17-08-50.090Z-67e19473-0451-475a-bf62-de8c10ad99cf`
- SQLite SHA-256:
  `ebb03852f35135bba31f3be3a731b85ddcb3104027bb9aca360bcb948a5274d7`
- Session status: `STOPPED`; ended at `2026-09-08T17:10:06Z`.
- `ADB_DEVICE_AUTHORIZED`, `FIRST_NATIVE_FRAME`, and
  `TFT_READY_FOR_USER` were recorded at 1920×1080 / 60 Hz.
- The saved-sign-in path submitted once for the recognized form. The receipt
  records no credential bytes and authentication was not yet independently
  verified in this short lifecycle test.
- Surface events reached `TFT_SURFACE_LAYER_ACTIVE`; the initial login prompt
  caused a known zero-frame transition and a later layer replacement.
- 29 frame windows were recorded: 12 `AVAILABLE` and 17 `UNAVAILABLE` during
  boot/login transitions. The available windows ranged from 0 to 60.51 FPS,
  with a maximum p95 interval of 2895.64 ms and 8 severe intervals. This is
  startup/login evidence, not a gameplay performance result.
- `pipeline_events`: 0. Native presentations: 3790.

## Decision

Stock DEV passes the basic boot-to-ready lifecycle that the reuse candidate
failed. The first failure is therefore candidate-specific or candidate/path
interaction, rather than proof that the entire DEV launcher is broken. The
reuse candidate remains rejected for this batch and must not be promoted or
used for an FPS comparison. The next authorized action is a targeted launch
comparison or rollback of that candidate; no new recorder or driver code is
justified until the candidate can reach the same ready oracle.
