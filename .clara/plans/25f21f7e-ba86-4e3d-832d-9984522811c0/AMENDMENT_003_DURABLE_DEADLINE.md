# Amendment 003 — Durable Four-Hour Deadline Across Host-Operation Resume

## Discovery classification
`BLOCKING DEPENDENCY` discovered during the first governed resume of campaign `incremental-20260911T082151Z-1f32770a`.

The runner persisted `deadline_monotonic_ns`. The original campaign process stored `14400097332625`, while the next Clara host-operation process observed a current monotonic value near `49626079892666`. The resulting resume calculation falsely reported zero seconds remaining even though the durable wall-clock campaign start was `2026-09-11T08:21:51Z` and the approved four-hour deadline is therefore `2026-09-11T12:21:51Z`.

A process-local monotonic origin is valid only within one process/clock namespace. It is not a durable checkpoint value across Clara host-operation recovery. Persisting it violated the plan's restart/recovery requirement and could truncate the four-hour campaign without running the queue.

## Smallest authorized repair
1. Persist the campaign deadline as an absolute UTC timestamp (`deadline_utc`) derived once when the campaign is created.
2. Persist `duration_seconds` for provenance.
3. Use UTC comparison for all candidate admission, confirmation admission, stability-control admission, and final deadline classification.
4. Never reconstruct an absent durable deadline from a fresh process-local monotonic value.
5. For a legacy/in-progress campaign missing `deadline_utc`, fail closed with `CAMPAIGN_DEADLINE_MIGRATION_REQUIRED` until an exact evidence-backed one-time state migration provides it.
6. Migrate the current campaign only from its already-persisted `started_utc=2026-09-11T08:21:51Z` plus the user-approved `4h` duration, yielding `deadline_utc=2026-09-11T12:21:51Z`. Preserve the old monotonic value under a forensic legacy field rather than treating it as authority.
7. Resume the same campaign ID and queue index. Do not create a replacement campaign, do not discard the prior false-classifier run, and do not extend the deadline to compensate for repair time.

## Complexity Economics Gate
PASS. The canonical durable value is one absolute UTC deadline already supported by Python's standard library. No scheduler, timer service, clock daemon, lease, or new persistence subsystem is required.

## ZenGate
PASS. ZenMC V4 completed with 100,000 trajectories, zero invariant violations, result `PASS`, receipt `77576f5db814d315d11a8af9992340a778f416239780182dc46fea4646440766`. This amendment changes only the persisted deadline representation and admission checks required for restart-safe execution. Candidate semantics, measurement workload, promotion logic, protected Control/LKG boundaries, and the four-hour wall-clock duration are unchanged.

## ZenMC V4 qualification
ZENMC_REQUIRED because the defect is specifically in restart/recovery and deadline transitions.

Required invariants:
- one campaign has one immutable absolute UTC deadline;
- restart/host-operation changes never reset or extend that deadline;
- legacy state without a durable deadline fails closed until explicit evidence-backed migration;
- current campaign migration equals `started_utc + 14400 seconds` exactly;
- no candidate/confirmation/stability run is admitted at or after `deadline_utc`;
- a run admitted before the deadline may finish and must seal rollback/evidence before terminal state;
- queue index and accepted stack survive restart unchanged;
- rollback failure still stops all future admissions;
- frozen LKG remains immutable;
- post-queue runs remain stability-control only.

## Current campaign migration authority
Campaign: `incremental-20260911T082151Z-1f32770a`

Persisted start: `2026-09-11T08:21:51Z`

Approved duration: `14400` seconds (4 hours)

Exact durable deadline: `2026-09-11T12:21:51Z`

The migration may occur only after the currently-running old resume process is terminal and the repaired source is validated/installed, so no two processes can race on campaign state.
