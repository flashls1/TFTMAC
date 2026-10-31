# TFT TURBO 2 — active execution contract, Checkpoint 1

## Win-condition register

Outcome: current October source durably preserved and a clean successor managed branch created. Project tftmac; change fda4732b-70e6-45dd-97ca-cfc2b1f48c6c; class IMPLEMENT/CP1. Source base 0a18c7f707730a18072df2bd74f5920ca1f98f56. Required proof: exact 482-file snapshot parity, current executable-source parity, source-only documentation changes, remote publication, original apps unchanged. Stop when that slice passes. CP2 is not authorized to execute until Flash says continue.

## Procedure

1. Checkpoint this paired preflight/plan before authority/document changes.
2. Persist TFT_TURBO_2_PLAN.md containing the approved 13-checkpoint roadmap, unchanged user requirements and safety dependencies. Future software versions must be reverified at implementation time.
3. Add superseding source-only notes to facts.md, project.md and AGENTS.md. Correct the identified API34/API36 documentation mismatch using observed SDK metadata. Preserve historical evidence and defaults as historical; do not rewrite product code or claim a new working release.
4. Record the CP1 source-preservation event in improvements.md, explicitly stating no build/audio validation has occurred.
5. Verify every inherited manifest entry against the source snapshot commit, compare current executable/configuration sources exactly, allowing only the four named authority/ledger documents to differ as reviewed. Confirm the new branch base and absence of excluded/private runtime data. Check new/edited documentation for accidental formatting errors. Recheck protected non-secret installed artifacts.
6. Persist CP1_ACCEPTANCE.json with exact hashes/counts/proof and CP2_NOT_STARTED. Native changes.checkpoint with explicit document/receipt paths and push=true. Confirm exact remote SHA and clean new worktree; do not merge or close the active change.
7. Save a Clara HANDOFF that says CP1 complete, records exact branch/head/manifest, and names CP2 as next action only after explicit continue. Retain scratchpad for concise material constraints, not a duplicate operation journal. Stop.

## Allowed files/effects

Planning artifacts under .clara/plans/fda4732b-70e6-45dd-97ca-cfc2b1f48c6c/, TFT_TURBO_2_PLAN.md, facts.md, project.md, AGENTS.md, improvements.md. Git checkpoint/push only for these new reviewed documentation files. Read-only verification of the inherited source and installed non-secret app hashes. No code changes, app build/sign/install, runtime migration, credentials, cleanup or host configuration changes.

## Recovery and boundaries

No force push, reset, clean, implicit branch switching, protected-path registry changes or publication of ignored/private inputs. Reconcile exact operation before replay if interrupted. Keep old apps and old source checkout. Latest user stop-at-checkpoint instruction overrides generic autonomous continuation at CP1 success; do not schedule a wake into CP2.

## ZenGate

PASS. ZENMC_NOT_REQUIRED for the source-only preservation layer, with rationale in the paired preflight. The simplest adequate design is native Git/Clara source preservation plus one exact integrity manifest and a compact handoff. CP1 does not claim the emulator or audio repair is complete.

## CP2 active execution amendment — 2026-10-30

Supersedes CP1 as the active slice after Flash's explicit continue. Effective project tftmac; same change/branch. Class IMPLEMENT/CP2. Win condition: isolated future identity/path contract and production build-entry safeguards proven, committed and published, with original apps and native runtime untouched. No CP3 migration, build, signing, installation, emulator update, native launch or authentication operation.

1. Checkpoint this appended preflight/plan before implementation.
2. Add ssot/turbo2-isolation.json defining blocked_not_built, com.flashls1.tftmac.turbo2, Desktop/TFT TURBO 2.app, Turbo2/StockShadow independent SDK/AVD, TFTMAC_Turbo2_StockShadow_R2, ports 5053/5600/5601/8560, state namespace turbo2, per-mode state/captures, and unchanged global native-runtime lease. Runtime hashes stay absent until actual provenance is observed.
3. Add scripts/turbo2_isolation.py with side-effect-free descriptor validation, canonical path/alias/overlap protection, current registry endpoint collision checks and read-only port availability observation. Neither preflight nor normal guard may create app/runtime directories, retrieve secrets, start ADB, modify Keychain or run a compiler. Use standard-library primitives only. Keep credential references declarative; access is unverified, never assumed.
4. Integrate the guard at the earliest existing build/verification entrypoint. Builder defaults only to proposed Turbo2 output and exposes --preflight; execution remains explicitly disabled pending the actual native mode/candidate build integration. Reject old output, nesting, symlinks and unexpected output. Remove ad-hoc signing fallback, pass exact output to verifier, and remove forced Finder restart. Verifier requires an explicit candidate --app, permits read-only --preflight, and refuses absent/wrong/unintegrated candidates before tests. Its final text must not claim original TURBO validated for delivery.
5. Add focused Tests/Tooling/test_turbo2_isolation.py exercising production functions and real CLI subprocess entrypoints. Verify valid contract, disjoint paths/ports, adjacent guest-ADB endpoint, protected originals, aliases and path traversal, duplicate/reserved ports, false-ready contract, missing signing identity, wrong app/registry, disabled builds and no filesystem/subprocess side effects. Use .build disposable fixtures only; no giant framework or fake gameplay tests.
6. Add docs/TFT_TURBO_2_ISOLATION.md mapping exact identity decisions, read-only dependency exceptions and remaining native wiring. Mark descriptor as not the active runtime manifest and no installed app. Detail that new bundle Keychain access must be proven and original deletion paths must never run for Turbo2.
7. Update current facts/project/AGENTS/BUILD_PROTOCOL and improvements ledger with CP2 scope/guard use. Preserve historical records. Correct any resulting current-authority contradictions. CP3 preflight must consume the exact contract and integrate the minimal native route before it can claim a logged-in clone launch; no blind AVD duplication now.
8. Run focused tests and zsh/Python syntax checks, preflight, actual old-target/missing-target negative checks. Verify incumbent resource/core hashes and native Swift/registry unchanged. Persist CP2_ACCEPTANCE.json with real results and deferred runtime/authentication fields, review exact diff, publish explicit paths and verify clean exact remote HEAD.
9. Save HANDOFF for CP2 acceptance and pause. CP3 begins only after a new user continue. Do not create automatic cross-checkpoint wake.

Allowed modifications: this change's .clara/plans files; ssot/turbo2-isolation.json; scripts/turbo2_isolation.py; scripts/build-turbo-app.py; scripts/verify-turbo-build.command; Tests/Tooling/test_turbo2_isolation.py; docs/TFT_TURBO_2_ISOLATION.md; facts.md; project.md; AGENTS.md; BUILD_PROTOCOL.md; improvements.md; TFT_TURBO_2_PLAN.md status only. Test outputs confined to .build; no changes to old source checkout, Swift sources, active registry or installed/runtime paths.

ZenGate PASS, ZENMC_NOT_REQUIRED for the bounded pure-validation implementation described in paired preflight. Complexity economics: a single descriptor feeds one shared preflight used by existing entrypoints, avoiding a new launcher/framework/state store. The explicit disabled state prevents unsafe pseudo-builds before native wiring, authentication migration and actual manifests exist. Do not label CP2 guard tests as complete native/gameplay acceptance.
