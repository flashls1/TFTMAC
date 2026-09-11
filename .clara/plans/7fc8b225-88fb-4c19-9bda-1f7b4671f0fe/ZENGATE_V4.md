# ZenGate V4 — PASS

## Decision

PASS for Amendment V4.

## Simplicity / removal test

The simplest correct mechanism is retained: the existing incremental runner plus its existing `candidates` array, matched native 1-5 measurements, confirmation policy, rollback, and integrity checks. Resolved history is moved to a non-executed `resolved_candidates` array in the same manifest; no new filter, scheduler, service, store, lifecycle owner, or runtime is added.

Each new candidate changes exactly one CVar already present in the verified DEV profile. Removing any candidate simply removes that hypothesis; no supporting plumbing exists solely for future-proofing.

## Scope/rabbit-hole gate

PASS. The queue is bounded to one unresolved retest and four evidence-backed mild refinements. Direct Vulkan, rejected transport toggles, protected Control, source-built emulator work, PBE-derived candidates, broad quality cuts, and unrelated cleanup remain excluded.

## ZenMC qualification

`ZENMC_NOT_REQUIRED` for V4. The campaign lifecycle, durable state machine, recovery behavior, rollback algorithm, confirmation algorithm, and concurrency semantics are unchanged from already-modeled/validated authority. V4 only changes manifest data and record-book state. If implementation changes the campaign lifecycle or rollback semantics, this qualification is invalid and a fresh ZenMC is required before execution.

## Execution lock

Only Amendment V4's manifest/data changes, exact result recording, and proven blocker fixes that directly prevent these candidates from executing may enter the change. Any broader mechanism change requires a new amendment.
