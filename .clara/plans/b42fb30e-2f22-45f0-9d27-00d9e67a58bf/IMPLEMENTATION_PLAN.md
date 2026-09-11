# Implementation Plan — finish the merged OvernightLab live layer and continuity

Supersedes no performance plan and admits no new optimization candidate. It continues the merged Sept-10 results-first obligation only far enough to make the already-approved local control plane truthful, durable, and resumable.

## Execution contract

1. Add a minimal `OvernightLab/install.command` that installs only source/config/controller material plus the existing classifier source/build helper into `/Volumes/MAC MINI M4/TFTMAC`, preserves existing generated evidence, compiles the classifier, and performs static verification. It must not copy or alter Control, DEV app, SDK, emulator, AVD, system image, TFT package, credentials, or unrelated project files.
2. Add a minimal `OvernightLab/run-overnight-campaign.command`: `--self-test` runs controller self-test plus fault-test; ordinary arguments execute the existing `campaign` CLI under `caffeinate`. Do not duplicate campaign state logic in shell.
3. Update `project.md` current state so the active change is `b42fb30e-2f22-45f0-9d27-00d9e67a58bf`, PR #9 merge SHA is recorded, and the old RUNNING campaign is not presented as live after reconciliation.
4. Append `CHANGELOG.md` with the post-merge continuity/live-layer result. Keep `DEV-B8-WIN-01`; no performance version promotion occurs.
5. Validate source locally before live effects.
6. Install the small control plane into the external TFTMAC root.
7. Copy/merge only the ignored historical OvernightLab evidence from the closed `ff2f...` worktree into the live OvernightLab location, preserving source from the new install and preserving generated evidence byte-for-byte. Never delete the source evidence origin until durable preservation is proven.
8. Verify copied evidence identities/counts/hashes at a bounded representative level and preserve the database/campaign directories completely.
9. Reconcile `overnight-20260910T160337Z-501dd433` against actual host state using existing `reconcile_resume` without entering `run_campaign`. Expected result: stale RUNNING becomes recovered/interrupted with baseline restored; no candidate replay.
10. Regenerate the historical report after reconciliation and verify it remains available.
11. Run installed `verify-static`, `self-test`, and `fault-test`. Confirm no TFTMAC DEV/qemu campaign process was started by those validations.
12. Re-read current `facts.md` and `project.md`; resolve any new factual drift before finalization.
13. Run repository validation, review exact diff, checkpoint/publish, deliver PR, require exact-SHA CI green, merge, and reconcile clean source state.
14. Because this repository is SOURCE_ONLY, independently verify the local installed control-plane hashes/acceptance after merge. Do not invent a remote deployment.
15. Stop this repair at the current results-first decision boundary. The existing automatic queue remains `control` only. A future performance test requires one deliberately admitted, evidence-backed hypothesis from the then-current authority; resolved P1/P2/P3 and rejected transport candidates are not rerun automatically.

## Exclusions

No new app/runtime/SDK/AVD copy. No Control/LKG mutation. No storage cleanup. No new VM/builder. No generic telemetry expansion. No unbounded profiling. No gameplay/performance candidate during this repair. No resurrection of PBE, direct Vulkan, buffer-retention, queue-submit-inline, virtual-queue-off, fence-contexts-off, or historical global-sync as a current candidate.

## Acceptance proof

Green source validation + exact source diff/review + live install hash parity + installed static/self/fault tests + preserved historical evidence + non-running reconciled stale campaign + exact-SHA GitHub CI + merge + clean selected worktree/local post-merge live verification.
