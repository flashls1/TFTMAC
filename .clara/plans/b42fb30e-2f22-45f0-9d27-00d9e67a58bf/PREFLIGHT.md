# Preflight — post-merge TFTMAC OvernightLab continuity repair

Date: 2026-09-10 America/Chicago
Change: `b42fb30e-2f22-45f0-9d27-00d9e67a58bf`
Completion class: IMPLEMENT_SHIP
Base: merged `master` SHA `bf61c21a723f2f132834acedda860efbb2223d42`

## Controlling authority

Read and adopted in this fresh Zoe session: current `facts.md`, `project.md`, `CHANGELOG.md`, and `.clara/plans/ff2f318b-245d-418a-b86f-e07d55b19826/RECOVERY_CONSTRAINTS_2026-09-10.md`.

Current DEV authority is `DEV-B8-WIN-01`: official TFT `18.1-5423749` / `8423749`, 1920x1080 / 320 DPI / 60 Hz, effective 8 vCPU / 6144 MiB, host GPU/CoreAudio, selected game RHI `OPENGL_ES_ANGLE`, multifile cache ON, `preferSubmitAtFBOBoundary` disabled, and `syncMonolithicPipelinesToBlobCache` removed. Protected Control/LKG remains immutable.

## Saved-point reconciliation

1. Saved change `ff2f318b-245d-418a-b86f-e07d55b19826` published exact SHA `9674294dd557a8ed7250c34deb6e9ca3f8d05f86`.
2. Exact GitHub check `Validate TFTMAC` run `34559035858`, job `103137754606`, completed SUCCESS on that SHA.
3. PR #9 was then squash-merged as `bf61c21a723f2f132834acedda860efbb2223d42`; the prior managed change is correctly closed.
4. The ignored historical OvernightLab evidence still exists in the closed worktree, including the campaign/database data recorded by the saved checkpoint. It must not be lost merely because the source change merged.
5. The old campaign `overnight-20260910T160337Z-501dd433` has a stale `RUNNING` checkpoint, but current host reconciliation found no OvernightLab controller, TFTMAC DEV core, or owned qemu/5586 process. Its last run reached Tocker stage 1-5 but has no `result.json`; it is interrupted historical evidence, not a current promotion result.
6. `/Volumes/MAC MINI M4/TFTMAC/OvernightLab` does not currently exist. Therefore the plan's required local live layer is not actually installed despite README claims.
7. Merged source contains `OvernightLab/overnight_lab.py`, `README.md`, schema, authority, and manifest, but README references `install.command` and `run-overnight-campaign.command` that are absent.
8. `overnight_lab.py` derives `PROJECT_ROOT` as its parent and requires `tools/tft-screen-classifier.swift` plus `scripts/build-tft-screen-classifier.command`; a naive copy of only the OvernightLab directory would fail static acceptance.
9. Current manifest automatic queue is only `control`; all previously admitted fast-pass optimization families are already resolved in the current record books. This repair must not silently add or rerun a performance candidate.

## Simplest correct mechanism

Add only the missing source-controlled install and campaign wrapper seams. The installer copies the small OvernightLab source/config plus exactly the classifier source/build helper needed by the existing code into `/Volumes/MAC MINI M4/TFTMAC`, compiles the classifier, and runs static verification. It never copies an app, SDK, emulator, AVD, system image, game package, or credentials.

Separately, before the closed worktree can be reclaimed, preserve its ignored runtime evidence into the new live OvernightLab location without deleting or rewriting it. Reconcile the stale campaign checkpoint against actual host state using the already-implemented `reconcile_resume` behavior, but do not run or resume a candidate as part of reconciliation.

## Required source/document corrections

- Add `OvernightLab/install.command`.
- Add `OvernightLab/run-overnight-campaign.command`.
- Correct `project.md` current-state text that still names the now-merged/closed `ff2f...` change as active; name this continuation change and record PR #9 merge/live-layer recovery state.
- Append a continuity entry to `CHANGELOG.md` for this tooling/live-layer repair. Do not create a new `DEV-B8-WIN-##` because no performance candidate is being tested.
- Update README command semantics only if required by the implemented wrapper behavior.
- `facts.md` changes only if a newly verified hard project fact requires it; current performance/runtime authority remains unchanged.

## Acceptance

- Protected Control and frozen LKG are never mutated.
- Closed-worktree ignored telemetry is durably preserved before any possible worktree cleanup.
- Live install exists at `/Volumes/MAC MINI M4/TFTMAC/OvernightLab` and contains no forbidden runtime/app copies.
- Installed source/config hashes match the selected managed source.
- Classifier builds and self-tests at the installed location.
- `verify-static`, `self-test`, and `fault-test` pass from the installed location.
- Stale old campaign is reconciled to a non-running interrupted/recovered historical state without replaying it; its evidence remains readable/reportable.
- No new gameplay/performance candidate runs during this repair.
- Source validator passes, diff/review is clean, and the selected worktree finishes clean.
- Source is delivered through PR/CI/merge. Project deployment profile is SOURCE_ONLY; the requested live layer for this change is the verified local install.

## ZenGate / ZenMC qualification

ZenGate basis: the missing live-install seam is a proven blocker to the already-approved live layer, and the proposed additions survive the removal test. No new architecture, service, scheduler, store, runtime clone, or experimental family is introduced.

`ZENMC_NOT_REQUIRED` for the new source delta: the wrappers add no new lifecycle/state semantics. Campaign recovery, locking, rollback, quarantine, and resume behavior remain owned by the existing previously-tested Python controller. This change validates those existing recovery paths rather than redesigning them.
