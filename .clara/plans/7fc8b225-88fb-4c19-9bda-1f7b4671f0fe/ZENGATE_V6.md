# ZenGate V6 — PASS subject to ZenMC V6 PASS

## Decision
PASS for Amendment V6 subject to a matching 100,000-trajectory ZenMC V6 with zero safety violations.

## Complexity economics
The simplest correct end-to-end mechanism is the already-proven single Google Play DEV guest plus native ADB. Google Play remains the sole package/update authority. The runtime adds only the missing authority/currentness gate and a deterministic audit recorder; it does not create an updater, mirror, second guest, package copy service, or hard-coded latest-version feed.

A three-phase audit is required because Google Play delivery and Riot first-launch content initialization are separate transitions. Omitting `PRE_UPDATE`, `POST_PLAY_UPDATE`, or `POST_RIOT_INIT` makes it impossible to attribute which owner changed a file. Hash manifests/diffs are evidence, not a new package store; Riot binaries remain outside Git.

## Rabbit-hole gate
Allowed paths are limited to native launch/package gating, a bounded update-audit implementation and tests, current authority/record books, and generated local update evidence. Graphics tuning families remain frozen until the update baseline is established. Control/LKG, PBE, mirrors, package patching, broad runtime redesign and unrelated cleanup are excluded.

## Safety invariants
1. `MATCH_READY`/`TFT_READY_FOR_USER` is forbidden when installer authority is not `com.android.vending` or Play exposes Install/Update.
2. PBE is never accepted as production authority.
3. User authentication is performed only in official Google/Riot UI; no credentials are read or stored.
4. A package transition requires all three audit phases and machine-readable diffs before optimization resumes.
5. Interrupted/ambiguous updates fail closed and preserve resumable evidence.
6. A new Riot client gets its own matched baseline; client-driven deltas are never promoted as a TFTMAC tuning winner.
7. Protected Control/LKG artifacts are never mutated.

## ZenMC qualification
ZENMC_REQUIRED due asynchronous update/auth states, partial progress, restart/recovery and external-effect uncertainty. Execution remains suspended until the V6 receipt passes and the planning checkpoint is rebound.
