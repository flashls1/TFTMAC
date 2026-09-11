# Amendment 002 — incremental-gains optimization doctrine

Date: 2026-09-11 America/Chicago
Change: `b42fb30e-2f22-45f0-9d27-00d9e67a58bf`
Trigger: explicit Flash scope/goal clarification in the current bound TFTMAC conversation.

## User outcome

Continuous useful 60 FPS remains the ultimate product target, but it is **not** the minimum success threshold for each experiment. The active optimization strategy is cumulative: expose and test small existing/research-backed settings one factor at a time, retain every **verified repeatable net improvement**, layer the next candidate on top of the latest winner, and determine empirically whether those small gains compound toward continuous 60 FPS.

If a candidate does not improve the game, is inconclusive, or regresses it, record the exact failure/result, restore the latest winner, and move on. Do not spend the pass building infrastructure merely to explain a loser.

## Authority correction

Current `facts.md`, `project.md`, `CHANGELOG.md`, and recovery constraints already describe cumulative verified-net-win promotion, but `facts.md`, `benchmark.md`, `dev.md`, the Swift benchmark decision engine, and its tests still contain a legacy **5% weighted-FPS promotion/rejection floor**. That floor conflicts with the clarified user goal because a legitimate 1–4% improvement could be rejected before it can compound.

## Revised decision semantics

1. `HOME_RUN` remains a label for a large/broad win. Its existing strong thresholds may remain as a standout classification.
2. `PROMISING` becomes the bounded-screen classification for an **incremental positive candidate**: there is at least one directly measured improvement signal and no material veto/regression that outweighs it. There is no fixed +5% weighted-FPS minimum.
3. `REJECT` is reserved for correctness/usability failure or material measured regression, not merely for failing to clear an arbitrary positive-gain percentage.
4. `INCONCLUSIVE` remains for invalid/mismatched evidence or a result that does not establish a directional net gain or regression.
5. A `PROMISING`/incremental win is not automatically permanent from one noisy sample. It requires the existing confirmation discipline. Once the improvement is repeatable and net-positive with no correctness/stability/compatibility/severe-tail veto, promote it as the next `DEV-B8-WIN-##` baseline.
6. 60 FPS remains the cumulative destination and full-run success condition. Until achieved, report the remaining deficit; do not reject a smaller verified step merely because it does not independently reach 60.
7. Existing historical decisions are not rewritten solely because the doctrine changed. Rejected candidates remain rejected unless new evidence/mechanism gives a specific reason to reopen them.

## Implementation scope

- Update `facts.md`, `project.md`, `CHANGELOG.md`, `benchmark.md`, and `dev.md` so this cumulative doctrine is explicit and no current authority says sub-5% gain alone is rejection.
- Update `tftmac/Runtime/CombatBenchmarkAnalysis.swift` to remove the legacy `<5% weighted FPS => REJECT` gate and classify small clean directional improvements as `PROMISING` while preserving correctness and material-tail vetoes.
- Update `Tests/TFTMACTests/CombatBenchmarkAnalysisTests.swift` with explicit sub-5% incremental-win coverage, neutral/no-signal inconclusive coverage, correctness rejection, and material-regression rejection.
- Refresh authority-input hashes/STACK lock as required by repository validation.
- Preserve the already-repaired OvernightLab live continuity work in this same change.
- Revalidate, republish PR #10 at the new exact SHA, require fresh exact-SHA CI, merge, and verify the local source-only live layer.

## Simplest correct code rule

Do not introduce a new scoring framework or new decision enum. Reuse the existing `PROMISING` classification.

After validity/correctness and the existing 10% p95/p99 material-regression veto:

- evaluate `HOME_RUN` first;
- classify `PROMISING` when one of these directly measured families improves: weighted FPS; 1% low; both p95 and p99 frame intervals; or smoothness (jank/severe/missed-vsync) without introducing a material conflicting regression;
- classify an exact/no-directional-change result as `INCONCLUSIVE`, not `REJECT`;
- keep `REJECT` for correctness failure or material regression.

This deliberately removes the false 5% floor without constructing a synthetic weighted score whose weights would be arbitrary.

## ZenGate

PASS. The scope is an explicit user-goal correction and removes a contradictory false gate. The smallest viable mechanism is to revise the existing decision semantics and tests; no new service, datastore, framework, candidate matrix, runtime copy, or telemetry architecture is needed.

`ZENMC_NOT_REQUIRED`: this changes deterministic comparison classification only; it does not add asynchronous lifecycle, recovery, concurrency, cutover, or external-effect state.

## Acceptance

- No current authority or executable decision path rejects a valid candidate solely because weighted FPS gain is below 5%.
- A small directly measured clean gain can reach `PROMISING` and, after existing confirmation, become the next working winner.
- Neutral/no-signal evidence remains `INCONCLUSIVE` rather than a fabricated win.
- Correctness failure and material p95/p99 regression still reject.
- Existing `HOME_RUN` large-win semantics remain available.
- Full source validation and fresh PR exact-SHA CI pass.
