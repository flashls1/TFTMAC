# TFTMAC DEV — Current 18.3 Development Route

## Current identity

- App: `/Applications/TFTMAC DEV.app` (`com.flashls1.tftmac.dev`, Build 8).
- Desktop route: `/Users/flash/Desktop/TFTMAC DEV.app`.
- Game: `com.riotgames.league.teamfighttactics`, `18.3-5530794`, code `8530794`.
- Installer: `com.android.vending`.
- Runtime: StockShadow advanced diagnostics, ADB `5041`, serial `emulator-5586`, console `5586`, controller `8556`.
- Effective output: **`1920×1080`**, density `416`, `60 Hz`; physical displays
  remain `2560×1440`. An explicit 2560×1440 override remains available for
  matched control.
- Effective resources: `8 vCPU`, `6144 MiB`, host GPU/CoreAudio.

## Launch and evidence rules

Cold-launch through the normal Desktop route. Verify the package, installer, boot state, display, activity, runtime identity, audio, input, and logger growth before a run is admitted. Store the capture under the current capture root and copy only the sealed receipt/evidence required by the SSOT.

A home-screen acceptance is a launch/playability check, not a gameplay benchmark. A setting is current only when the 18.3 capture records it. A performance win requires a matched 18.3 comparison, one separable change, repeatability, and clean rollback.

Three matched 1920×1080 full-Trial captures now establish the current
playability default at a median 59.03 workload FPS, with zero audio underruns.
The strict continuous 60-FPS/severe-stall contract and causal presentation
owner remain unresolved.

## Protected boundaries

Never overwrite the Control app, StockShadow runtime, required SDK, launcher route, Riot package, credentials, or the dirty source worktree. Do not resurrect retired source-build, causal-AVD, or obsolete settings routes.

## Current evidence

Use `TFTDEV-SSOT/receipts/post-cleanup-launch-2026-09-27.txt`, `evidence/current/`, and `TFTDEV1.md`. Archived pre-18.3 documents are not active configuration.
