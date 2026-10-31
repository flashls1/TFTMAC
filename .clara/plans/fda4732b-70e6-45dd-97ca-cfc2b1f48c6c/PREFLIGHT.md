# TFT TURBO 2 — Checkpoint 1 preflight

Date: 2026-10-30 America/Chicago. Project: tftmac. Request class: IMPLEMENT, checkpoint bounded.

## Authority and user outcome

Flash authorized the TFT TURBO 2 plan and required a stop after every numbered checkpoint, resuming only after explicit `continue`. CP1 is source preservation and successor branch creation, not app delivery. The existing TFT TURBO and immutable TFT Ranked applications, account state, SDK and AVD remain untouched.

## Verified source chain

- Existing October worktree: 7fc8b225-88fb-4c19-9bda-1f7b4671f0fe.
- Old tracked HEAD: 70ee2aba4c67fc64864aa35a401b7be26cc665c1; stale master: e0261e2afe3d78453877756c481e5b2932adc008.
- October source snapshot: 04a6ac9673e44714b4cf1524290a4f7cbc64023a.
- Preserved/published source plus receipt: 0a18c7f707730a18072df2bd74f5920ca1f98f56.
- This managed change: fda4732b-70e6-45dd-97ca-cfc2b1f48c6c, branch clara/tft-turbo-2-fda4732b, created by Clara from that exact published SHA.
- Inherited manifest: .clara/plans/7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/TURBO2_CP1_SOURCE_MANIFEST.json. It hashes 482 selected source files and modes. Snapshot preservation receipt is adjacent.
- All 482 Git blobs/modes matched; all six checked installed resources matched source; TURBO core matches its existing build receipt. No claim of a fresh native compile or bit-for-bit source-to-binary reproduction.
- TURBO core: a3955be420b00b1fd13801a5dfcad65fe085fe7e3486a763b6788750acb1ed67.
- Ranked core: 00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee.
- Python cache and rejected block-cache artifact metadata remain in the old worktree and were not deleted or admitted to this source branch. Private build seed and all ignored runtime/account data remain outside Git.

## Scope classification

In scope: source-only project-authority supersession, approved roadmap persistence, CP1 receipt, exact source parity and remote checkpoint, durable handoff. No product source edits, builds, tests requiring runtime, installs, AVD copies, emulator launch, credential reads, new repository, mainline merge, dependencies or host settings.

Existing build script output and validator defaults point to TURBO 1; no such script may run for Turbo2 until CP2 isolation planning arranges protections before any candidate build. Full packaging acceptance remains CP10. Any future update-version assertion from the prior plan is a candidate to verify against official metadata at CP4, not an already installed or independently accepted release.

## Operational route

Use native Clara files.batch for independent document changes, changes.checkpoint for exact-path source-only publication, and messages HANDOFF for the pause. A read-only host verification compares snapshot/current source, branch base, protected installed hashes and staged paths; its compact receipt is the required persistence evidence. Do not use a production build gate to stand in for CP1 preservation, and do not claim CP1 establishes clean audio.

## ZenGate qualification

ZENMC_NOT_REQUIRED for this deterministic source-only slice: no custom runtime lifecycle, recovery state machine, concurrency algorithm or cutover is being introduced. Existing durable Clara/Git transaction semantics are reused. Runtime/AVD stages need their own explicit qualification.

## CP2 amendment — application/runtime isolation, 2026-10-30

Flash explicitly said continue after CP1. This amendment supersedes the CP1-only scope for the current slice, not its historical acceptance. CP2 alone is authorized; stop before CP3. Current base d47c77a91cbc26a15757028c14cd2f28fe493b4a is clean and published. The roadmap defines CP2 success as a verified isolated identity/path contract and guarded build route; it does not authorize guest migration or installation.

### New decisive observations

Operation tft-turbo2-cp2-isolation-discovery-20261030-v1 confirms the proposed Desktop app and Turbo2 runtime roots do not exist or resolve through symlinks. TCP ports 5053,5600,5601,8560 were available at observation. The fourth port is the emulator's adjacent guest ADB transport endpoint, not another ADB server. Availability is not a running reservation; repeat checks at launch. Existing registry reserves server/console/controller sets 5038/5582/8554,5041/5586/8556,5042/5590/unset plus adjacent transport ports. No code or runtime changed.

Read-only source audit establishes: RuntimeMode.swift accepts exactly three current modes and pins the packaged registry SHA and incumbent paths; RuntimeModeAuthority.swift derives per-mode state under TFTMAC/Modes/<state_namespace>; TFTMACRuntime.swift uses the global TFTMAC/State/native-runtime.lease. Both code guards and global lease must remain intact. A new native mode cannot be obtained by merely replacing registry strings. Advanced-diagnostics-only branches also control guest provisioning, saved sign-in, startup, presentation and recovery. Those require explicit integration before any candidate build can be accepted.

Installed TURBO designated requirement includes bundle identifier com.flashls1.tftmac.dev and stable certificate; the proposed different Turbo2 identifier is not equivalent Keychain/TCC authority. Do not promise inherited access. Preserve credentials and require real new-app access proof in CP3/CP5 without deleting old items. No secret was read.

The existing Python builder deletes output before compilation, defaults to TURBO1, retains an ad-hoc signing fallback, and invokes the verifier without target arguments. The verifier hard-codes TURBO1. A changed --output alone could build a falsely labeled candidate with old runtime identity and validate the wrong app. Correct these entry boundaries now; do not try a build to discover the failure.

### Minimal implementation and limits

Add one non-secret future-isolation descriptor under ssot, one shared standard-library Python preflight/path guard, focused tooling tests, and a source-boundary design map. Wire the existing builder and verifier through the guard before any seed read, destructive action, compiler, signing or native test. Only read-only --preflight is permitted at this checkpoint; ordinary build/verification must fail closed until a later phase implements and validates the exact native mode. Define the future app/AVD/root/ports/state/forwarder identity; do not insert fabricated component hashes or enable an unbuilt registry mode. Do not edit Swift runtime source or old runtime-modes.json in CP2.

This is an actual guard implementation, not a claim that a Turbo2 application is ready. Native wiring, independent credential access, actual disk migration and candidate launch are later checkpoint work. Preserve the old builder body as historical scaffolding behind the explicit blocked execution path; correct the signing fallback, verifier target and forced Finder restart before future use. Existing applications and the private seed are never accessed for mutation.

### Routes and proof

Use native Clara files.batch/patch for exact approved source/doc edits; checkpoint the paired plan first. Use enabled project-bound host_exec only to execute the read-only preflight and focused tests with writes limited to disposable fixtures in .build and one .clara acceptance receipt. Reuse native Clara publish and exact remote verification. No project policy, service, deployment, host setting or credential authority changes.

Required proof: descriptor valid; all four ports do not collide with registered endpoints; default and aliased/parent/child/old-app targets rejected before effects; existing builder and verifier cannot start build/native-tests or report old app as Turbo2; signing absence cannot select ad-hoc; active registry/Swift bytes unchanged; original non-secret installed hashes unchanged; CP2 source published clean. XCTest/gameplay not rerun because no native code/build is part of this slice.

ZenGate qualification: ZENMC_NOT_REQUIRED for this deterministic fail-closed validation/identity slice. No custom runtime lifecycle, recovery, concurrent mutation or cutover is introduced; all actual build/launch/migration transitions remain blocked. Focused negative controls exercise the production guard itself. CP3 must model its multi-step disk/cutover lifecycle before enabling effects.

## CP3 amendment — authenticated offline clone and native candidate, 2026-10-30

Flash explicitly continued after CP2. Current clean source/remote HEAD cf2f5211507f47fb617f2be53760fe368c9f7d14. CP3 alone is authorized. The requested outcome is an independently recoverable authenticated clone, proven TFT entry on the incumbent engine, with no writes to original apps/AVD/SDK or original account stores. No engine/graphics upgrade or full-match performance claim.

Readiness operation turbo2-cp3-runtime-readiness-20261030-v1 found no TFTMACDEVCore/qemu process, destination absent, 159GiB free. Vendor qemu-img info --backing-chain in turbo2-cp3-image-metadata-20261030-v1 confirms cache and encryption overlays reference relative same-directory raw files; userdata overlay references same-directory qcow2 base with no further parent; all dirty/corrupt flags false. Copy ALL backing files together. Config's 6CPU/5GiB/default transport values are overridden by the actual current launcher to 8CPU/6144MiB/proven ASG; preserve effective values in the candidate rather than mistaking static config defaults for gameplay truth.

Authoritative vendor guidance: https://www.qemu.org/docs/master/tools/qemu-img.html prohibits modifying live VM disks; info --backing-chain reveals dependencies. https://developer.android.com/studio/run/emulator-commandline documents retained userdata and cold boot without wipe. No original disk is modified by qemu-img. A broad initial discovery command was stopped by host-platform safety before execution; narrowed metadata-only reads succeeded. Do not replay blocked secret-bearing discovery.

Native source audit: preserve original three mode entries/guards and global lease; add exact turbo2 entry, digest and namespace. Reuse existing native forwarder, private bundled DEV provisioning and normal Riot session; no new vault, new account, exported credential, or Keychain ACL rewriting. New Turbo2 unlock route must use only existing owner-only bundled provisioning through the native interface, fail without prompting if unavailable, and never invoke original service deletion/migration. Saved Riot store remains read-only. Explicitly guard old DEV-only experimental routes and preserve audio/graphics baseline. Full successor packaging must be correctly integrated BEFORE replacing CP2 constant build lock; copying a renamed old app is not acceptance.

Clone mechanism: existing global exclusive lease (compatible schema, live PID) while stopped; APFS independent copies of full SDK/AVD to a private staging area and verified immutable backup; exact source and destination manifest parity before identity edits. Reject links to originals and nonlocal backing chains. Rewrite only candidate nonsecret paths/name, ignore invalid QuickBoot on initial cold start; never wipe userdata. Native candidate startup owns its existing global lease; migration releases only its own lease. Interrupted stages remain nonlaunchable and resumable only against exact manifests. Preserve partial data rather than cleaning broadly.

Governed routes: native Clara files/checkpoint for approved source and paired plans; enabled exact-project Full Access for offline filesystem copy/build/validation and the known Runtime-folder path-policy collision (no policy weakening). Native publication/review follows. No credentials enter source or logs. Test/runtime output stays in .build or private Turbo2 directories. Terminal CP3 requires original integrity, full backup/clone proof, stable signed candidate, native tests, authenticated controller and actual official TFT lobby evidence; provider-enforced authentication is a real external blocker, never bypassed.

ZenMC REQUIRED: copy/verify/publish, interrupted partial work, stale source, competing launch, and candidate readiness. Model source and independent post-transition oracle with deliberate invalid transitions must pass before effects. Final pass binds exact executed model SHA and consolidated constraints below.

## CP3 USER_SCOPE_CHANGE — account-free native build, 2026-10-30

Flash now explicitly removes signed-in backup/migration from this checkpoint and assigns account provisioning to local Codex later. CP3_BUILD_ONLY.md supersedes the prior CP3 migration mechanism and acceptance criteria. This is a different operation: no old AVD, account state, private seed or account Keychain reads/copies; no attempt to bypass/retry the prior denied effect. Read-only source discovery confirms compiler/signing availability and the new target absent. Existing NDK/compiler and source-owned helper builders are available; their build outputs remain in this worktree. Build native Turbo2 now; leave unobserved SDK/AVD hashes absent and native runtime selection blocked until CP4. The proposed native build uses only source/public resources, staged assembly, strict signing, exclusive publication and a pending-runtime smoke test. Actual sign-in, TFT startup, audio and gameplay acceptance remain deferred. A new build-state model is required; old migration-model success does not qualify the different design.
