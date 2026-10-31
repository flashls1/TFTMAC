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
