# Preflight — valid CVar impact testing

## User outcome
The user explicitly clarified that a four-hour runtime is not an acceptance criterion. The required outcome is valid matched testing that determines whether each admitted setting has an impactful positive, negative, or neutral effect.

## Current authority
- Base: merged `master` `e0261e2afe3d78453877756c481e5b2932adc008`.
- Current winner: `DEV-B8-WIN-01`; protected Control/LKG remain immutable.
- Unresolved settings from the prior campaign: `r.pso.PrecompileThreadPoolSize 4->2`, `r.ShaderPipelineCache.BackgroundBatchSize 20->4`, `a.Budget.BudgetMs 6.0->5.0`; 5.0->4.0 remains conditional.
- Prior candidate attempts did not produce admissible performance evidence because the DeviceProfiles bind-overlay transaction failed during ADB root/unroot transitions. Controls and rollback/integrity were valid.

## Root cause boundary
`OvernightLab/overnight_lab.py` currently issues `adb root` / `adb unroot` and immediately polls `adb shell id -u`. Both commands restart `adbd`; the current implementation has no explicit reconnect/wait-for-device transition and only a 20s polling window. The observed failures are exactly `ADB_ROOT_FAILED` / `ADB_UNROOT_FAILED` during candidate apply, while later rollback remained clean. The smallest correct repair is to make the existing privilege transition restart-aware, not to redesign the runtime or candidate mechanism.

## Scope
1. Add one restart-aware UID transition helper used by `adb_root` and `adb_unroot`.
2. Require the owned emulator to remain present; use the existing exact serial/ADB server and `wait-for-device`, then prove the expected UID by `id -u`.
3. Preserve fail-closed timeout behavior and rollback semantics.
4. Add an impact-only campaign mode that stops when the admitted queue is resolved; elapsed runtime is only a safety bound, not an acceptance target. Keep existing stability-tail behavior available for explicit future soak use.
5. Prove the root/unroot transaction with a bounded DEV-only live canary before candidate measurement.
6. Run matched control/candidate tests for the unresolved queue; confirmation remains required for any promising result. The 4ms animation candidate remains conditional on a confirmed 5ms result.
7. Promote only repeatable net improvement; record neutral/regression/inconclusive truth and preserve telemetry.

## Non-goals
No Control/LKG mutation, no app rebuild, no source-built AEMU, no new candidate families, no four-hour soak requirement, no speculative ADB framework.

## ZenMC qualification
ZENMC_REQUIRED because ADB privilege transitions restart the transport and interact with rollback/recovery. Model must prove: no candidate measurement before shell UID is restored to 2000; root/unroot timeout fails closed; emulator loss fails closed; rollback remains required; impact-only completion depends on queue resolution rather than elapsed soak time.