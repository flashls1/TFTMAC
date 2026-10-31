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

## 2026-10-30 amendment: TFT TURBO 2 Checkpoint 1 preservation

Classification: explicit USER_SCOPE_CHANGE. Flash authorized the TFT TURBO 2 plan and required a stop at every numbered checkpoint until an explicit `continue`. This amendment supersedes the September campaign as the immediate execution objective only; it neither reruns nor declares that older campaign complete.

Requested layer: IMPLEMENT, bounded to Checkpoint 1 (source preservation and successor managed branch). No product rebuild, installation, runtime configuration, emulator launch, AVD migration, credential operation, dependency upgrade, cleanup, merge or deployment is authorized in this slice.

Evidence: Clara connect/status and host operations `tft-turbo2-cp1-inventory-20261030-v1` and `tft-turbo2-cp1-preservation-review-20261030-v1`. Existing HEAD is `70ee2aba4c67fc64864aa35a401b7be26cc665c1`; master is the older September `e0261e2afe3d78453877756c481e5b2932adc008`. There are 67 tracked modifications plus untracked October source/docs. The deployed build receipt points to this worktree and HEAD; the installed core hash matches that receipt. All six checked source/installed resources match (runtime-modes, TURBO icon and four HighPerf assets). The old receipt does not hash every dirty source file: do not claim a fresh rebuild or bit-reproducible binary provenance.

Protected installed core hashes observed: TURBO `a3955be420b00b1fd13801a5dfcad65fe085fe7e3486a763b6788750acb1ed67`; Ranked `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`. Both strict deep signatures pass. Private build seed remains present and will not be copied into Git.

Preserve all existing intended tracked changes and untracked source/docs, including history archives, RankedLauncher, TURBO icon and the in-tree `implementation.md -> improvements.md` link. Exclude only generated `scripts/__pycache__/` and the rejected local `DriverRuntime/angle1166/block-cache-candidate/` artifact directory. Preserve excluded material at its original location, without deletion. Existing ignored build/runtime/AVD/credential data stays outside Git. Targeted secret-marker scan of selected text found no hits; this is not an assertion of universal secret absence.

Read-only diff review covers all changed paths/hunks and classifies runtime, presentation, tests, configuration, tooling and documentation as an existing source snapshot, not new feature approval. Existing Markdown hard-break trailing spaces produce a diff-check warning against September; preservation must not silently reformat original bytes. Runtime defects and stale September/current documentation are recorded for separate, source-only authority reconciliation in the successor, never converted into a gameplay-success claim.

Nearest decisive proof: selected-file SHA-256 manifest equals committed Git blobs; successor branch has exact snapshot ancestor and matching source; non-secret installed artifact hashes remain unchanged; successor clean and checkpoint durably preserved. The original worktree may retain only deliberately excluded local artifacts.

ZenMC qualification for this amendment: ZENMC_NOT_REQUIRED. This slice uses existing Clara checkpoint/create primitives and deterministic Git/file parity checks. It introduces no runtime state machine, restart/recovery logic, concurrency implementation or live cutover. Future AVD/runtime stages must be qualified independently.