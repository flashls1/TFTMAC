# Silent launch gate receipt

**Scope:** TFTMAC DEV autonomous silent lifecycle batch

**Observed:** 2026-09-09 (local Mac, America/Chicago)

## Decision-critical test

The changed mechanism is the `TFTMAC_AUTONOMOUS_SILENT=1` launch policy. The
smallest decision-critical test was a rebuilt DEV launch with that environment
variable, followed by an external native window enumeration and inspection of
the private runtime capture.

## Evidence

- Build command: `/bin/zsh scripts/build-dev-launcher.command`
- Build result: `TFTMAC DEV built without modifying Control`
- Source under test: `TFTMACApplication.swift`, `AppCoordinator.swift`,
  `TFTMACRuntime.swift`, and `scripts/run-60fps-win-campaign.command`
- Launch environment: `TFTMAC_AUTONOMOUS_SILENT=1`
- Native window oracle: `visible_window_count=0`
- Runtime event: `AUTONOMOUS_LAUNCH_POLICY` with
  `silent_requested=true` and `expected_activation_policy=prohibited`
- Runtime reached: AVD recovery, HighPerf asset verification, emulator host
  launch, controller authentication, and first native frame
- Private capture: `2026-09-09T02-52-52.544Z-235dd8fd-1aeb-4b05-af73-eea321518527`

Owned emulator, network-simulation, logcat, and launcher processes were
explicitly cleaned after the test. Control was not started or modified.

## Result and limits

`PASS` for the silent-window policy and process launch path. This test stopped
before a real lobby or gameplay workload, so it does not prove login, recorder
coverage, pipeline causality, or 60 FPS. The capture also contains pre-existing
ADB socket warnings; they did not prevent controller authentication or the first
native frame in this run and remain a separate runtime observation.

The repository source verifier remains blocked by a pre-existing
`ssot/AUTHORITY_INPUTS.sha256` mismatch for `facts.md`; no authority document was
changed to mask that unrelated drift.
