# Amendment 001 — Continuous Four-Hour Tail

## Why this amendment exists
The approved candidate queue can finish before the exact four-hour campaign deadline. The current runner exits immediately when the queue is exhausted. That does not satisfy the requested continuous four-hour evidence window.

## Scope change
After the candidate queue is exhausted, do **not** invent or admit another tuning candidate. Repeatedly execute a `stability-control` run using the exact current campaign working profile and the existing matched native workload until the deadline prevents admission of the next run.

A stability-control run:
- changes no CVar and cannot promote a candidate;
- uses the current working-profile bytes unchanged;
- uses the same DEV app, StockShadow runtime, Tocker navigation, native SurfaceFlinger/SQLite evidence, and rollback path already approved;
- records run/capture/profile identity, metrics, result classification, and rollback evidence in campaign state/report;
- stops the campaign immediately if runtime identity, telemetry, correctness, or rollback is not green.

Deadline rule: check the monotonic deadline before each new stability-control admission. A run already admitted before the deadline may finish and must complete rollback/evidence sealing; no subsequent run may start after the deadline.

## Complexity Economics Gate
PASS. The smallest correct mechanism is one bounded tail loop in `OvernightLab/incremental_lab.py` reusing `run_profile()` with a synthetic no-mutation stability specification. No new runtime, scheduler, service, VM, AVD, profiler, store, or mutation state machine is introduced.

## ZenGate
PASS. ZenMC V2 completed with 100,000 trajectories, zero invariant violations, result `PASS`, receipt `857b5abdff538ca5903473a9ca7c7e58fdccd0dab39eacae96ba24de93b7300e`. This amendment changes only queue-exhaustion behavior. All original protected boundaries, one-factor candidate rules, rollback gates, evidence rules, and final delivery requirements remain unchanged.

## ZenMC V2 qualification
ZENMC_REQUIRED because the amendment changes deadline, recovery, rollback, and repeated asynchronous run transitions. Model identity: `TFTMAC_INCREMENTAL_4H_LIFECYCLE_V2`.

Required invariants:
1. Frozen LKG is never mutated.
2. No tuning candidate is admitted after candidate-queue exhaustion.
3. Every post-queue run is `stability-control` on the current working-profile identity.
4. Any rollback failure terminates future run admission.
5. Deadline prevents admission of the next candidate or stability run.
6. Candidate promotion still requires positive confirmation.
7. A run admitted before deadline may finish, but must seal evidence and rollback before terminal campaign state.

## Source delta authorized after V2 PASS + checkpoint
- Add the stability-control tail loop and state/report ledger fields only.
- Extend offline self-test to prove the tail-loop policy is enabled without executing the emulator.
- Re-run governed validation and live-install hash-parity/self-test.
- Then start the durable four-hour campaign exactly as the approved plan requires.
