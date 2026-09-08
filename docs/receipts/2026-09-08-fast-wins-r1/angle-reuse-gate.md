# Fast-wins experiment receipt: ANGLE reuse candidate

Date: 2026-09-08
Status: **REJECTED_LAUNCH_CORRECTNESS**

## Decision-critical test

The existing guarded ANGLE buffer-view reuse candidate was launched through
the packaged DEV route with automatic capture enabled. The oracle required
the candidate library to be mapped by the live TFT process, a usable TFT
surface and ready state, then a valid active-TFT workload before any frame
comparison.

## Mechanism exercise evidence

- Candidate: `dev-observed-reuse-cache-r14`
- ANGLE revision: `1166eec4c0b125e9e945196acfc549983ef72b18`
- Manifest SHA-256:
  `054b8fa9354bb5beb6e501728bbd6f9539f76aceba1e3060fdd9050d4f69cf81`
- Capture: `2026-09-08T17-03-04.856Z-9c1822c2-58c1-4ed7-8fc2-edb50d1f1eac`
- Live TFT PID: `3903`
- The live `/system/lib64` ANGLE files matched the candidate manifest:
  - `libEGL_angle.so`: `3452d6aa4316ef132bb55ed9ef1f4045a1d46e8c9f228caa6eb79e01dbad2088`
  - `libGLESv2_angle.so`: `9780d4b99266764416825f31cf84967484f590a5b44896796a519139dad12a51`
  - `libGLESv1_CM_angle.so`: `00c696df2157e52f0778b4465c9d2b952712405a3c93e7ee691bfaf2672d32c0`

This proves the selected candidate files were the files mapped by TFT. It
does not prove that the reuse branch handled a gameplay draw.

## Failure evidence

- TFT reached `GameActivity` and briefly reported a `SurfaceView` active, then
  reported `TFT_SURFACE_LAYER_LOST`.
- A later surface-active event occurred, but `TFT_READY_FOR_USER` never did.
- The capture recorded 12 game-frame windows, all `UNAVAILABLE` (ADB errors,
  no TFT surface, or no timestamps).
- Native presentation rows existed, but there was no valid TFT gameplay window
  or graphics snapshot from which to compute FPS, p95/p99, stalls, or a gain.
- The capture remained `STARTING` with no end time after the DEV and emulator
  processes were stopped. It is preserved as an unsealed failed capture; the
  database was not edited to fabricate a seal.

## Decision

The candidate is rejected for this batch's launch/correctness gate. This is a
negative usability result, not a performance result. Do not promote, compare,
or claim FPS improvement from this run. The next smallest test is a stock DEV
boot using the same lifecycle, to distinguish a candidate-specific surface
failure from a general DEV launch failure. No additional driver code or
instrumentation is authorized until that distinction is established.
