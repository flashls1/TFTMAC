# vCPU 6 screening receipt

**Scope:** silent HighPerf stock-shadow launch with the guest CPU override set to
six vCPUs. This is a screening run for the first guest-side lever, not a final
performance acceptance run.

**Observed:** 2026-09-09 (local Mac, America/Chicago)

## Decision-critical test

The decision was whether the existing DEV launch path can exercise the locked
six-vCPU guest configuration while preserving the current High quality profile
and producing TFT SurfaceFlinger frame evidence. The smallest test launched
DEV silently, inspected the recorded emulator command and runtime identity, and
queried the sealed SQLite frame windows before terminating the owned processes.

## Evidence

- Launch environment: `TFTMAC_RUNTIME_MODE=advanced_diagnostics`
  `TFTMAC_AUTONOMOUS_SILENT=1` `TFTMAC_DEV_VCPU=6`
  `TFTMAC_ENABLE_AUTO_PERFETTO=0`
- Capture: `2026-09-09T03-07-17.766Z-9d4b290a-9347-42b7-a57b-06d6205cb169`
- Runtime receipt: `TFT_READY_FOR_USER`, engine `Unreal Engine`, profile
  `tftmac_diagnostic_stock_shadow_r1`, 1920×1080, 60 Hz, CoreAudio.
- Process evidence: `TFT_PROCESS_STARTED` recorded the current TFT process
  (PID 3837). `EMULATOR_HOST_LAUNCHED` recorded `-cores 6` and `-memory 6144`.
- Driver identity: stock-shadow gfxstream SHA-256
  `3772fef215058831ea419c9281fd203d010003d5defdc195dd120bc7748e4093`.
- Database coverage: 68 frame windows (49 available with samples), 5,093
  frame facts, 137 presentation samples, 25 resource samples, 6 input dispatch
  samples, and 40 clock samples.
- Available-window aggregate: effective FPS minimum 1.1838, maximum 61.9896,
  mean 56.2204; worst p95 interval 2,929.371 ms and worst p99 interval
  2,929.371 ms; 16 jank events and 8 severe events.
- Later GameActivity windows were usually near 59–60 FPS, but their p95 frame
  intervals remained about 17.1–17.6 ms and one sampled window was 57.576 FPS.
  These windows did not include a complete combat workload.
- Native clock samples ranged from 69,667 ns to 610,667 ns uncertainty. The
  610,667 ns maximum exceeds the 0.5 ms attribution gate, so precise
  cross-boundary causal timing is rejected for this run.
- Resource sampler recorded emulator CPU from 39.2% to 481.1% and RSS from
  534,784 KiB to 3,156,832 KiB. At test time, internal free space was 2.6 GiB
  and external free space was 170 GiB.

## Result

`RESOURCE_PRESSURE_NON_ACCEPTANCE; SCREENING_ONLY`

The six-vCPU mechanism was exercised and the app reached the user-ready
surface, but the run stopped before a complete match or late combat. It does
not prove a guest scheduler gain, a driver bottleneck, continuous 60 FPS, or a
winning configuration. Internal free space was below the required 8 GiB floor,
and the clock uncertainty exceeded the causal-attribution threshold. The
capture remains valid diagnostic evidence; it must be repeated above the
resource floor after the first proven late boundary is available.

Owned emulator, network-simulation, logcat, and launcher processes were cleaned
after the run. No Control files or credentials were changed.
