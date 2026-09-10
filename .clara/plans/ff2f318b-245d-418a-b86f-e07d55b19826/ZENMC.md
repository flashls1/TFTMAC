# ZenMC — unattended failure-state model

Mode: COMPLEX_SYSTEMS / EMPIRICAL_TEST_REQUIRED for FPS.

## Mandatory production guards
1. LKG immutability
2. installed DEV identity verification
3. official-client/PBE admission gate
4. build-scope classifier
5. static candidate delta preflight
6. candidate sandbox/artifact hashes
7. bounded boot/runtime/login/UI/measurement watchdogs
8. semantic game state machine
9. unified run identity
10. per-variable requested/effective verification
11. telemetry sequence/completeness gate
12. failure fingerprint + recurrence quarantine
13. verified rollback before continuation
14. atomic checkpoint + real-state reconciliation on resume
15. external auth classification without bypass

## Modeled transitions
- clean start -> baseline verify -> candidate -> preflight -> optional component build -> smoke -> game -> measure -> analyze -> rollback -> next.
- compile/artifact/config failure -> fingerprint -> bounded repair if in scope -> recurrence quarantine -> next.
- boot/ADB transient -> one bounded recovery -> deterministic recurrence quarantine.
- login service transient -> bounded backoff; CAPTCHA/MFA -> AUTH_BLOCKED, no bypass.
- unknown UI -> evidence capture -> bounded observe -> UI_BLOCKED, no blind click.
- telemetry producer loss -> INCONCLUSIVE; do not convert to performance fail/pass.
- candidate crash/corruption -> hard reject -> rollback.
- rollback failure -> restore/reconcile LKG baseline; if unprovable, hard campaign stop.
- supervisor death -> atomic checkpoint + inspect actual processes/mounts/ADB -> restore incomplete state -> resume next safe boundary.
- Zoe/Clara route loss -> deterministic local supervisor continues; no project mutation authority is delegated to runtime.

## Fault-injection coverage required before unattended acceptance
PBE candidate/evidence, malformed manifest, wrong package/version, unexpected second delta, bad/missing ANGLE artifact, build fail, launch fail, ADB timeout, unknown UI, missing telemetry, event loss, child hang, duplicate failure, stale checkpoint, interrupted overlay, rollback denial.

## Decision constraints
FPS gains are never predicted by this model; Tocker gameplay is empirical authority. Candidate scoring must distinguish HARD_REJECT, INCONCLUSIVE, NO_SIGNAL, MECHANISM_WORKING, POSITIVE_PROVISIONAL, PROMOTION_CANDIDATE, WIN_60.

## Model verdict
PASS only if every mandatory guard is implemented or a strictly stronger already-existing mechanism is proven and reused. No guard is optional in unattended mode.