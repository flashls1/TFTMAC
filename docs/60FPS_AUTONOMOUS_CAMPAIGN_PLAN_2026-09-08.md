# TFTMAC autonomous 60 FPS campaign

Status: **queue exhausted with no 60 FPS win; next run is storage-gated**

## Win condition

Find a current DEV configuration that boots without a red startup failure,
authenticates the saved local account, enters Tocker's Trials, and sustains
actual TFT SurfaceFlinger delivery at or above 60 FPS during the measured
combat workload. A Mac 60 Hz counter, lobby average, source-frame average,
or a run without mechanism-exercise proof cannot pass.

For a candidate to be recorded as a **WIN**, all of the following must hold:

1. The boot interval has no `RUNTIME_FAILED`, `STARTUP_FAILURE_PRESERVED`, or
   classifier `error` result, and `TFT_READY_FOR_USER` is present.
2. The selected ANGLE manifest or DEV experiment profile is proven in the
   capture. A launcher flag alone is insufficient.
3. The saved sign-in reaches the lobby, Tocker's Trials reaches 1-1 combat,
   and the screen remains visually correct with input and audio working.
4. Every available combat frame window in the confirmation interval has
   `effective_fps >= 60` and `p95_interval_ms <= 16.667`; any under-target
   window rejects the candidate immediately.
5. Unique source delivery remains available and the run exits with verified
   emulator cleanup and configuration restoration.

## ZoeMC model result

**MODE B — COMPLEX_SYSTEMS: EMPIRICAL_TEST_REQUIRED.** The topology is
guest Unreal/RHI → GLES/ANGLE → guest Vulkan/gfxstream → ASG/host decoder →
MoltenVK/Metal → SurfaceFlinger/native delivery. Existing evidence eliminates
neither guest submission nor host transport as the sole owner, and no model
can honestly predict FPS from the available counters. Feasible candidate
families are preserved in this order: existing ANGLE binaries, the three
current DEV emulator feature presets, then bounded combinations and new code
only when a measured boundary justifies it. Stale PBE/high-resolution launcher
entries and quality reductions are excluded from this campaign.

**MODE A — PLAN_PREFLIGHT: PLAN_MODEL_PASS.** Behavior units cover cold boot,
red-splash failure, saved sign-in, lobby/mode navigation, ready-check timing,
combat entry, live frame oracle, early rejection, direct owner shutdown,
rollback, and interrupted-capture preservation. Historical stale-bundle
ownership and unsealed-capture failures are represented as regression cases.

## ZenGate result

**ZEN GATE V4.1: PASS.** Scope is limited to the existing DEV app, current
runtime, current quality, one local AVD, and reversible candidate selection.
No Control, Clara, credentials, or unrelated source behavior is changed. Each
run produces a private receipt and the campaign ledger records `WIN`,
`REJECTED_UNDER_60`, `BOOT_FAILED`, `CORRECTNESS_FAILED`, or `INCONCLUSIVE`.

## Ordered campaign

Runs execute one at a time and stop as soon as a WIN is proven:

1. `angle-reference` — stock ANGLE reference manifest.
2. `angle-no-reuse-r13` — observed no-reuse ANGLE build.
3. `angle-reuse-r13` — first reuse build.
4. `angle-reuse-r14` — current reuse build.
5. `queue-submit-inline` — current DEV preset.
6. `virtual-queue-off` — current DEV preset.
7. `fence-contexts-off` — current DEV preset.
8. `reuse-r14-queue-submit-inline` — only if both individual mechanisms
   survive their screening interval; otherwise this combination is skipped.

Each run checks the splash immediately, proves its mechanism, drives the same
Tocker's Trials 1-1 combat entry, and rejects on the first valid under-60
combat window. No rebuild or configuration mutation occurs during a run.
All captures remain private; the campaign ledger contains hashes and metrics,
never credentials.

## Stop and evidence rules

- A candidate with any valid combat window below 60 FPS is not a win and is not
  repeated in this campaign.
- A candidate with a boot, login, visual, input, audio, crash, or cleanup
  failure is recorded and skipped; the failure is not hidden by retry.
- A classifier or recorder failure is `INCONCLUSIVE` and receives only the
  minimum repair needed to make the same test runnable.
- A performance run is invalid when the host has less than 8 GiB free on the
  internal volume or less than 20 GiB free on the external runtime volume. The
  runner must refuse before boot in that case; no FPS result is promoted.
- The campaign is unattended and silent. Heartbeats are written to the
  private campaign log; no repeated app windows or user prompts are used.
- The run is bounded to the ordered queue and stops after a proven WIN or
  exhaustion of the queue. It does not claim success from averages.

## ZEN GATE DISCOVERY REPORT

- The previous reuse run proved mechanism exercise but produced zero retained
  bindings and failed continuous 60 FPS; it remains a rejection baseline.
- The current capture finalization path can remain `RUNNING` after a forced
  owner kill. The campaign uses direct owner shutdown and records any seal
  failure rather than rewriting the capture.
- Cross-stack request-to-presentation lineage remains unavailable. Results
  are therefore an actual-present decision oracle, not a complete causal
  attribution of every late frame.

## Execution receipt — 2026-09-08

Campaign root (private, outside Git):
`~/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Campaigns/60fps-win/2026-09-08T19-33-23Z-b1724550-2cae-4a1b-a14f-c13655220dab`

The ordered queue exhausted without a `WIN_60FPS` receipt. The sealed outcomes
were:

| Candidate | Outcome | Decision evidence |
|---|---|---|
| `angle-reference` | `REJECTED` | Screen disconnected; 3 available windows; minimum effective FPS 0; mechanism and ready events present |
| `angle-no-reuse-r13` | `BOOT_FAILED` | Ready timeout with preserved runtime failure event |
| `angle-reuse-r13` | `BOOT_FAILED` | Ready timeout with preserved runtime failure event |
| `angle-reuse-r14` | `REJECTED` | Visible screen error; 25 available windows; 56 jank / 21 severe |
| `queue-submit-inline` | `BOOT_FAILED` | Red boot/runtime failure before readiness |
| `virtual-queue-off` | `REJECTED_BELOW_60` | 51 combat windows; minimum effective FPS 0; worst p95 3737.182 ms; source minimum 0.984 FPS; 595 jank / 139 severe |
| `fence-contexts-off` | `REJECTED_BELOW_60` | 30 combat windows; minimum effective FPS 0; worst p95 3194.045 ms; source minimum 0.975 FPS; 231 jank / 70 severe |

The two candidates that reached sustained combat show repeated 40–59 FPS
windows and severe stalls, so changing these transport flags did not restore a
continuous 60 FPS path. The captures also show the host below the required
storage budget (about 3.2 GiB free internally during collection), so this
campaign is diagnostic evidence only and cannot be used as a clean A/B
comparison. The runner now enforces the storage preflight and exits before an
additional boot when the budget is violated.

The next admissible experiment is a new, explicitly scoped candidate only after
the storage preflight passes. It must target the measured upstream guest
Unreal/RHI cost; another permutation of the rejected queue flags is not a
winning path. No candidate or setting is promoted from this receipt.

ZEN GATE V4 EXECUTION LOCK — Execute only this approved plan and the minimum changes required to satisfy its stated win condition and acceptance criteria. Do not add, refactor, rename, clean up, generalize, optimize, upgrade, reformat, or alter unrelated behavior unless this plan explicitly requires it. Every changed file and material diff hunk must trace to an approved requirement/plan step, required validation, or a proven blocking dependency without which acceptance cannot pass. When an unplanned issue is discovered, perform only the minimum investigation needed to classify it: if it blocks current acceptance, prove the dependency and return the smallest scope expansion through targeted Zen Gate before changing it; if it is a real but non-blocking defect, do not repair it now—save it to the persistent project scratchpad or Zen Gate Discovery Ledger and include it in the final ZEN GATE DISCOVERY REPORT for separate review and Zen Gate repair planning. Once a discovery is shown not to block the current win condition, stop investigating it and return to the approved task. Before completion, audit the final diff and revert every change that cannot be justified by this rule.
