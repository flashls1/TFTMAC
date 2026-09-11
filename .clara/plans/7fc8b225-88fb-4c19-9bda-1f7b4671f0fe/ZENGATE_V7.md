# ZenGate V7

## Decision

PASS contingent on ZenMC V7 zero violations.

## Simplest-correct mechanism

Use the existing DEV Keychain secret only once to remove the emulator credential, then delete that DEV item and remove the DEV unlock dependency. Do not build a new credential service, migration daemon, lock manager, or alternate launcher. Keep Control unlock untouched.

The performance side requires no new optimization: preserve exact `DEV-B8-WIN-01` bytes and effective values already proven. Riot 18.2 is a client transition to validate, not permission to invent settings.

## Scope

Allowed: DEV guest credential retirement, DEV-only stale keychain/setup gates, current update/currentness source, current WIN-01 verification/authority records, DEV rebuild/install, migration boot, no-PIN cold-boot acceptance, Riot update audit completion.

Forbidden: Control mutation, frozen LKG mutation, PBE, Riot package modification, new candidate tuning, rejected PSO=2, rejected animation=5ms, unresolved shader batch=4 promotion, unrelated refactors.

## ZenMC qualification

`ZENMC_REQUIRED`: V7 changes a credential-backed startup state transition and includes one-time migration, deletion, restart, and no-secret cold-boot verification. The model must prove no successful state can delete the DEV Keychain item before Android credential clearing, touch Control's secret, or claim readiness while guest user 0 remains credential-locked.
