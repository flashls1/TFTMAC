# TFT TURBO 2 — approved staged implementation roadmap

Authority: Flash's October 30, 2026 plan approval in the current project conversation. Project `tftmac`, repository `flashls1/TFTMAC`. Preserve the existing product; build an isolated successor. STOP at each numbered checkpoint and proceed only after explicit `continue`. No automatic cross-checkpoint wake or background progression.

## Outcome and boundaries

A separate `~/Desktop/TFT TURBO 2.app` should launch the official signed-in TFT client automatically, retain Google/Riot account state, eliminate persistent scratchy audio, and adopt verified compatible stable emulator/graphics fixes without meaningful gameplay regression. Preserve the original `TFT TURBO.app` and immutable `TFT Ranked.app`, their SDK/AVD/account state, current 8-vCPU/6144-MiB/1080p baseline, and proven ASG 256-KiB ring/64-KiB step/2000-us flush/1-MiB write buffer until an independently accepted change supersedes a value. This roadmap does not promise provider tokens never expire or certify continuous 60 FPS.

The active successor is Clara change `fda4732b-70e6-45dd-97ca-cfc2b1f48c6c`, branch `clara/tft-turbo-2-fda4732b`. The human-facing workstream is TFT TURBO 2. Clara's generated branch spelling is authoritative; do not rename it outside Clara. Base `0a18c7f707730a18072df2bd74f5920ca1f98f56` contains the verified October source snapshot `04a6ac9673e44714b4cf1524290a4f7cbc64023a`, not September master.

## Checkpoints and decisive proof

### 1. Preserve source and create successor

Preserve the current October working source and supporting history/tools/assets, excluding generated Python cache and rejected local driver artifacts. Verify all 482 captured source files and modes against committed Git blobs. Preserve original apps. Create this managed successor from exact published preservation SHA. Persist this roadmap, CP1 scope, receipt and handoff. Publication/clean successor and unchanged installed artifact hashes complete CP1. No build or runtime change occurs here.

### 2. Application/runtime isolation

Discover and define the minimum separate Turbo2 application identity, SDK/AVD/capture roots, authenticated controller and valid unused ports. Preserve the exclusive runtime lease. Audit all hard-coded mode/path/hash checks before adding an exact new mode. Do not disable existing Control/DEV identity guards. Candidate bundle identity `com.flashls1.tftmac.turbo2`, root `~/Library/Application Support/TFTMAC/Turbo2/StockShadow`, and AVD name `TFTMAC_Turbo2_StockShadow_R2` are proposals pending this stage's checks, not installed facts.

Before ANY future candidate build, apply the output/verification/signing safeguards described in checkpoint 10. The legacy builder deletes its output and defaults to TURBO 1; the legacy verifier also hard-codes TURBO 1. Never run it with only a changed output argument and assume validation checked the candidate. This is a prerequisite, not permission to skip checkpoint stops or claim checkpoint 10 complete early.

Pass: isolated identity/path contract and guarded build route proven without touching originals. No AVD migration before CP3.

### 3. Preserve authenticated guest state

Clone the entire AVD only after normal shutdown and proof no process writes its disks; never stop a live match. Preserve userdata, encryptionkey backing files/overlays, required metadata, permissions and complete qcow2 backing chains. Copies must not resolve to writable original backing files through hardlinks/symlinks/absolute paths. APFS independent copy-on-write clones are acceptable after verifying independence. Keep immutable backup and exact restore path outside Git. Do not factory reset, wipe data, clear app/account state, use -wipe-data, replace the guest image, regenerate account identity, or expose secrets.

Initially retain API36 Google Play ARM64 revision7. Preserve the existing authorized ADB host key identity, existing saved Riot login interface and guest unlock dependencies without printing their values or overwriting the original Keychain items. Validate new signed-app Keychain access; stable signing does not guarantee a new bundle ID inherits consent. Official provider MFA/consent must not be bypassed. First prove authenticated clone behavior with the incumbent engine, then upgrade in CP4. A legitimate provider-enforced prompt requires an exact report rather than silently repeating logins.

Pass: recoverable offline clone, original hashes/state intact, account/session retained and normal TFT entry; checkpoint prevents repeated manual setup.

### 4. Upgrade the coherent official emulator package

Reverify Google stable-channel metadata and compatible macOS ARM64 artifacts at execution time. Version 37.2.13 is the candidate named in the approved plan, NOT a version independently downloaded/accepted by CP1. Record official source, exact revision/build, archive integrity and component hashes. Use a separate SDK root. Do not patch only QEMU or mix arbitrary ANGLE/gfxstream/MoltenVK dylibs. Keep the signed-in API36 guest image, resolution, vCPU/RAM and tuning unchanged for the first comparison. Confirm emulator, QEMU, graphics dependencies and authenticated gRPC protocol compatibility as one coherent package.

Expect Quick Boot snapshot invalidation across engine changes; use a cold boot without wiping persistent userdata. Verify virtual audio hardware and effective parameters rather than assuming old environment variables remain supported. Preview/Canary/API-major migration is excluded from the initial update. No source emulator rebuild unless CP9 is justified.

Pass: isolated stable engine boots preserved guest and official TFT with no account-state loss, and native input/display/audio/control smoke checks pass.

### 5. Preserve one-click startup

Maintain native AppKit/Metal window, hidden emulator UI, packaged host launch via /usr/bin/open in the logged-in Mac session, exact ADB ownership, authenticated controller, guest wake/unlock, official Google Play ownership/currentness, existing Riot session and automatic official TFT activity launch. End at the normal TFT home/lobby, ready to play; do not automatically queue a ranked match. No manual terminal, Android home-screen navigation or extra launcher buttons.

Pass: three consecutive direct-to-TFT launches without unexpected repeated credential prompts; separately log cold-start duration and repeat-start behavior.

### 6. Fix audio with actual runtime evidence

Start with unchanged audio settings on the updated coherent engine. Correlate actual AudioFlinger/ranchu PCM writes, emulator backend and audible output. Existing streamAudio can help compare emulator digital mix with host output, but confirm the tap location/format and observer overhead before causal claims. The prior evidence reports persistent pcm_writei EIO; that is not proof of its initiating cause. No live-game ADB root/unroot or audioserver restart. No masking diagnostics or blindly growing buffers.

Only if needed, test one independently justified buffering/timer/polling/guest-property/startup change at a time. Zero gameplay PCM EIO, no sustained device failure, clean audible startup/lobby/full-match output, no audio-triggered disconnect and no material graphics regression are required. Update the old source-only G-06 check to a truthful runtime gate before claiming audio repaired. Document conflicts with old locked buffering rules and reconcile authority only after approved evidence-backed acceptance.

### 7. Validate graphics and measured improvements

Evaluate the vendor-coherent updated ANGLE/gfxstream/MoltenVK/Metal pipeline. Confirm the selected game RHI versus lower-layer Vulkan separately. Preserve known working transport values when supported. Capture actual game FPS, 1% lows, p95/p99/worst-frame latency, severe hitches, RHI and emulator CPU, memory, frame freshness, input responsiveness and audio/network health. Inspect actual bottlenecks before shader cache, scheduling or presentation changes. Each new factor requires matched controls and repeatable net benefit.

Do not reopen the rejected block-cache driver, oversized ASG aperture, 6-vCPU configuration or failed direct game Vulkan merely because dependencies changed. New evidence/hypothesis is required. Small repeatable net wins may be retained; no arbitrary gain threshold or lobby-only 60-FPS claim.

### 8. Reconcile compatible patch inventory

Pin accepted engine and graphics revisions. Evaluate platform-tools separately only after startup/auth acceptance. Use official Google Play/Riot update mechanisms, never modify or re-sign Riot binaries. Do not simultaneously change Android image, Google account state, emulator, Xcode and macOS. API36 revision7 remains the initial guest baseline. Host OS and major Android-image upgrades are separate explicit choices if actually required. Record latest verified compatible versus rejected/deferred updates, not an unqualified claim every component is newest.

### 9. Conditional smallest justified emulator patch

Enter only if the official stable package fails and a reproducible boundary has been identified. Prefer an applicable supported upstream fix. Pin source/dependencies, build an unmodified isolated baseline first, then patch the smallest responsible component with ABI/dependency checks. If necessary, stage the official full emulator build; do not build Android OS or alter Riot software. Run all preserved-account/audio/graphics acceptance. Skip this checkpoint as NOT_NEEDED if official binaries suffice, explicitly documenting that decision.

### 10. Complete reproducible packaging and anti-regression gates

The early safety subset must already protect every candidate build. Finalize explicit output/runtime/SDK/AVD/identity/signing/receipt parameters, realpath checks, no alias to incumbent applications or writable disks, stable signing with no ad-hoc fallback, required permission strings, icon and exact-artifact verification. Preserve existing tests and add only focused production-isolation/integrity checks. Reconcile hash receipts for all HighPerf assets. No forced Finder restart, credential recreation or unrelated infrastructure.

### 11. Technical acceptance

All nine existing gate intents remain: protected baseline, signing identity, strict signature, correct icon/identity, appropriate permissions, real audio health, CPU/runtime configuration, native tests, asset/runtime integrity. Extend evidence for account retention, direct launch, controller ownership/protocol, audio/network/graphics correctness, startup, rollback and cross-runtime isolation. Compilation or static gate strings are not live acceptance. Baseline 135 tests is historical; report actual test discovery/count/result for the current source.

### 12. Real gameplay validation

Use three comparable accepted trials with same official client version/settings/geometry and documented warm/cold cache state, workload, host device/thermal conditions. Include startup/lobby, extended heavy combat and at least one complete match; avoid initiating ranked matches without user involvement. Measure distributions rather than a single lobby average. Separate unlike matches from controlled comparisons. Verify audible output, persistent-error absence, login continuity, no disconnect/crash/artifact and no material net regression. Revert rejected factors to the last proven candidate.

### 13. Deliver separate successor

Deliver TFT TURBO 2.app only after all required live evidence. Keep TFT TURBO.app and TFT Ranked.app available and untouched. Record exact source SHA, engine/image/component revisions, manifests, signatures, accepted test/performance/audio/authentication receipts and rollback. Reconcile project records, preserve evidence, finish a clean managed change through Clara delivery. Do not merge/promote a regressing candidate or uninstall the originals.

## Continuity and source boundaries

Use Clara-managed phases and paired preflight/plan/ZenGate with ZenMC where the phase actually introduces multi-stage runtime/recovery risk. Preserve before/after evidence in existing project documents. HANDOFF owns exact resume state, scratchpad owns concise unpromoted constraints/research, operations own execution results. Never store user passwords/tokens/AVD images in source control.

CP1 evidence: inherited source manifest and SOURCE_RECEIPT under `.clara/plans/7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/`; this change's scope and final acceptance under `.clara/plans/fda4732b-70e6-45dd-97ca-cfc2b1f48c6c/`. CP2 identity descriptor and guarded entrypoints are implemented after explicit continuation; exact evidence is CP2_ACCEPTANCE.json. CP3_NOT_STARTED until another explicit continue. Full native runtime integration, account access and any build remain gated.
