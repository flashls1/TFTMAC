# Autonomous Tocker's Trials run receipt

Date: 2026-09-08
Status: **MATCH EVIDENCE CAPTURED; PERFORMANCE FAILURE; SESSION SEAL INTERRUPTED**

## Decision-critical run

The existing TFTMAC DEV build was launched locally with the observed ANGLE
reuse candidate, automatic Perfetto enabled, and the saved local Riot account.
The loop authenticated, entered Tocker's Trials, accepted the queue, entered
1-1 combat, and held the run long enough to observe the next planning stage.
Control and Clara were not used.

- Capture: `2026-09-08T17-46-00.240Z-4669be52-66c3-48a9-8012-7f696853e98e`
- Profile: `tftmac_diagnostic_stock_shadow_r1`
- Candidate: `dev-observed-reuse-cache-r14`
- ANGLE revision: `1166eec4c0b125e9e945196acfc549983ef72b18`
- Manifest SHA-256: `054b8fa9354bb5beb6e501728bbd6f9539f76aceba1e3060fdd9050d4f69cf81`
- Runtime configuration SHA-256: `7895c5e5e179bf238d7d40a3f38bc0bff571df5b1d9210e803118a8790ac1c51`
- TFT process: PID `3917`; `ANGLE_DRIVER_LOADED_VERIFIED` recorded all three
  candidate libraries and `reuse_enabled=true`.
- Saved sign-in: `RIOT_SAVED_SIGNIN_CDP_FINISHED` and
  `RIOT_SAVED_SIGNIN_SUBMITTED` recorded `credential_data_recorded=false`.
- Mode evidence: local screenshots show Tocker's Trials 1-1 planning, active
  1-1 combat, and the following 1-2 planning screen. Their hashes are retained
  in the capture directory.

## Real presentation result

The capture contains 103,743 actual TFT SurfaceFlinger frame intervals and 885
available frame windows. Across the complete post-login capture:

- Mean interval: 17.430 ms; aggregate mean-equivalent rate: 57.37 FPS.
- Interval p95: 19.827 ms; p99: 34.285 ms; maximum: 4,092.801 ms.
- 3,180 janky intervals, 310 severe intervals, and 4,791 missed-vsync
  equivalents.
- Only 163/885 available windows were at or above 60 FPS; no window had a
  p95 interval at or below the 16.667 ms 60-FPS budget.
- Approximate 1-1 combat screenshot interval (18:15:21–18:16:45 local run):
  3,597 intervals, mean 19.683 ms (50.80 FPS), p95 33.885 ms, p99 40.073 ms,
  maximum 183.285 ms, 589 janky and 22 severe intervals.
- Native host presentation stayed near 60 Hz, but source delivery averaged
  49.83 FPS in that combat interval and recorded 125,822 sequence drops. The
  host counter therefore does not establish 60 useful TFT FPS.

This fails the continuous-60 acceptance requirement. The candidate is not
promoted.

## ANGLE mechanism evidence

The raw TFT process log contains the candidate's `TFTMAC_VIEW` producer. A
read-only normalization of the retained raw logs recorded:

- 116,744 swap aggregates and 4,409,502 aggregate view creations.
- 2,661,023 parsed create spans; summed create-call duration was
  167,573.388 ms in the guest clock.
- `retainedBindings=0`, `retainedSyncs=0`, `missingFrames=4`,
  `missingSpans=1,748,479`, and `malformed=100,913`.

The candidate mechanism was exercised, but it retained no views in this run
and the producer stream is incomplete. The aggregate create time is diagnostic
evidence only; it is not a causal guest-to-display frame budget.

## Shutdown result

The generic app-level quit targeted a stale `/Applications/TFTMAC DEV.app`
copy and produced a separate already-owned failure capture. The current
worktree owner was then terminated directly; its emulator children were also
stopped and no TFTMAC, forwarder, QEMU, or netsimd process remained.

Because the owner was forcibly terminated, the live capture's SQLite session
row remains `RUNNING` and normal `finish(status:)` did not run. The database
passes `PRAGMA integrity_check` and `PRAGMA quick_check`; raw logs, Perfetto
traces, screenshots, and the interrupted ANGLE analysis are retained. This is
an explicit seal failure, not a fabricated clean stop.

## SHA-256 receipts

- SQLite file: `1da9197dc61ae431239b0b403222b6ac38ba8951e22dad367aba9eb91a9f8e6d`
- SQLite WAL: transient WAL observed during collection (initial SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`);
  it was checkpointed and is no longer present, so the main SQLite hash above
  is the durable database receipt.
- Native events JSONL: `43d733ca45841eaedb8b7775d388a6061a6163c129a1040be307e982e008d86c`
- Interrupted ANGLE analysis: `19b8f262a0021a8fd8fa0486ec2160a0f1b6b236c31f6ed555c4963060221df5`
- Perfetto trace 1: `b4f4009b7fdcdfc26ab9dc15157874672b23358508404953875f843e6e562046`
- Perfetto trace 2: `86382f49c86f042e7b7c2367e7d4405b3bdb6ac6eba355d2b6a426a21c4ff21e`
- Screenshot `battle-planning.png`:
  `be289d9277ccb09750ac15894e079e7792145098fc51e2c99e0d089830146a85`
- Screenshot `combat-start.png`:
  `a42a0922d81ddeba0b621fdd206fc75371aea1d372b468153e113a0697efd921`
- Screenshot `combat-25s.png`:
  `5e86eb493170673a4fcc78fbe6103ce6164bdcfc8dd0f1698c70eaefab2d6efa`

The capture directory is private local evidence under
`~/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures/`;
credentials are not included in this receipt.
