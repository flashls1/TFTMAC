# Implementation Plan — resolve CVar overlay and measure impact

1. Implement a single `wait_adb_uid(expected_uid, timeout)` primitive in `OvernightLab/overnight_lab.py` using the existing exact ADB binary/server/serial. During the bounded transition, require the owned emulator to remain alive, use `wait-for-device` as the reconnect primitive, then prove `adb shell id -u == expected_uid`.
2. Route `adb_root()` and `adb_unroot()` through that primitive. Preserve existing error classes and fail-closed behavior. Do not change Control/LKG or AVD ownership.
3. Extend IncrementalLab with an explicit impact-only execution option. In impact-only mode, execute the same queue/control/candidate/confirmation logic but skip the post-queue stability-tail loop and terminalize when the queue is resolved. Time remains only a maximum safety bound.
4. Add self-test coverage for impact-only queue-exhaustion semantics and the privilege-transition decision helper where deterministic testing is possible.
5. Run ZenMC against the accepted state machine; require zero violations before product execution.
6. Checkpoint plan + ZenMC receipt before source effects.
7. Validate source with `scripts/verify-tftmac.command`.
8. Install exact source into the live OvernightLab and prove source/live parity plus static integrity.
9. Run a bounded DEV-only privilege canary: launch the isolated DEV runtime, prove shell UID 2000, root -> UID 0, unroot -> UID 2000, repeat once, then normal quit/rollback and verify installed DEV + frozen LKG integrity. No performance conclusion is taken from this canary.
10. Start a fresh impact-only campaign from `DEV-B8-WIN-01`. Test in order: PSO threads 2; shader background batch 4; animation budget 5ms; 4ms only if 5ms confirms positive. Each candidate uses fresh matched control, exact CVar readback/engine-log proof, native combat telemetry, and verified rollback.
11. For PROMISING/HOME_RUN, require the existing confirmation pair before integrating. For neutral/regression/inconclusive, do not integrate. If a candidate becomes a winner, the next candidate must use the newly confirmed cumulative working profile.
12. Reconcile results into `CHANGELOG.md` and `project.md`; update `facts.md` only if current hard authority changes. Create a new `DEV-B8-WIN-##` only with confirmation evidence.
13. Run final production validation and review; publish, PR, exact-SHA CI, merge, and prove merged/live parity and runtime quiescence.

## ZenGate
PASS subject to ZenMC PASS. This is the minimum causal repair: one reconnect-aware transition primitive plus one execution-mode flag; no new service, store, runtime, AVD, app, or candidate family. Acceptance is valid impact evidence, not elapsed wall-clock duration.

## 2026-10-30 superseding execution slice: TFT TURBO 2 Checkpoint 1

User authority: implement the approved TFT TURBO 2 plan, STOP at each numbered checkpoint, resume only when Flash types continue. This slice is source preservation/branching only. Existing September steps above remain historical and are not resumed.

Active win-condition register: outcome = exact October source preserved plus isolated successor managed branch; project = tftmac; preservation change = 7fc8b225-88fb-4c19-9bda-1f7b4671f0fe; class = IMPLEMENT/CP1; proof = manifest/Git parity, recorded source and app identities, clean successor and durable checkpoint; next action = planning checkpoint before snapshot.

1. Checkpoint this paired amendment using Clara changes.checkpoint, exact HEAD, and planning paths only. Do not stage product files opportunistically.
2. Generate a non-secret preservation manifest under this plan directory: every intended tracked source file plus selected untracked additions, path/type/executable-bit/SHA-256; manifest itself excluded from its own hash. Record protected non-secret installed artifact hashes, original HEAD, included/excluded paths and existing build-receipt resource parity. Fail on concurrent drift or unexpected path/secret markers. Read symlinks as links, never dereference outside the tree.
3. Preserve existing October bytes in an explicit-path Clara changes.checkpoint. Exclude scripts/__pycache__/ and DriverRuntime/angle1166/block-cache-candidate/; do not delete or reset excluded files. Publish the checkpoint to its existing branch for durable preservation. No PR/merge/deploy required.
4. Verify snapshot Git blobs and modes exactly match the captured manifest. Capture exact resulting SHA. Reconcile any tool transport uncertainty through the returned operation before retry.
5. Create one successor Clara managed change from that exact SHA with summary TFT TURBO 2. Accept Clara's generated branch name; do not rename tracked worktrees behind Clara or create an unrelated repository. Never base on stale master.
6. Persist the approved thirteen-checkpoint roadmap and CP1 evidence in the successor with its own preflight/implementation plan. Add source-only superseding notes to facts/project/agent authority where necessary so the successor is not mistaken for an installed release; preserve historical statements as dated records. Clearly mark unverified future release-version claims for official-source re-verification at CP4.
7. Validate only the requested preservation layer: full source manifest parity, changed-document checks, clean successor, exact remote checkpoint, original application identities unchanged. Native compile/gameplay gates belong to later build/runtime stages; never report them as freshly passed here.
8. Save durable HANDOFF with change ID, exact SHA, completed CP1 evidence and next CP2; use scratchpad only for new material constraints/unpromoted findings. STOP. CP2 needs Flash's explicit continue.

Allowed effects: planning/document records, deterministic source manifest, existing source snapshot commit/push through Clara, successor managed worktree creation and source-only continuity checkpoint. No app/core/config behavior changes, no emulator/AVD effects, no credential access, no mainline merge.

ZenGate CP1: PASS. ZENMC_NOT_REQUIRED for this source-preservation-only scope as qualified in the paired preflight. Complexity gate: reuse native Git/Clara primitives; one manifest exists solely to prove exact source preservation. Existing output-path and verification-path defects remain deferred to isolation work before any future build.