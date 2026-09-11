# TFTMAC DEV checkpoint — 2026-09-06

**This is an implementation checkpoint, not a 60 FPS acceptance result.** Signed DEV r17 is installed. Its latest controlled saved-login attempt failed at macOS Keychain access with status `-25293`; the runtime remained responsive and quit cleanly. No real match or gameplay performance gain was validated in this engineering session.

## Workspace and boundaries

- Repository: `flashls1/TFTMAC`; local branch `clara/fix-dev-launch-keychain-prompts-riot-log-bddd2d6c`.
- Worktree: `/Volumes/MAC MINI M4/Clara/Worktrees/flashls1--tftmac/tftmac--bddd2d6c-a2ed-46fb-9e9e-6674bfdf3541`.
- Preserved application baseline: `c26b020d660134699c4ca53113d59f2e2ec7b61d`. Resolve this checkpoint's commit with `git log -1 --format=%H -- AGENT_HANDOFF_2026-09-06.md`.
- DEV: `/Applications/TFTMAC DEV.app`, bundle `com.flashls1.tftmac.dev`, ADB server 5041, serial `emulator-5586`.
- Protected Control: `/Applications/TFTMAC.app`; unchanged core SHA-256 `d3bf7c249a3e5f11b81f778b063e1a8cfe2e7fdeec0537ee6bd8447b1c2268d2`.
- Work locally. No Clara connection, Control installation, publication, quality reduction, userdata reset or replacement app. Existing quality, 1920×1080 display, eight guest CPUs, 6144 MiB guest RAM, audio and transport remain fixed.
- The Decision-Evidence Gate governs the next action: after an enabling repair, immediately attempt the smallest decisive test and prove the mechanism ran. Infrastructure is not performance progress.

## Delivered changes and evidence

| Requirement | Implementation | Evidence and limit |
| --- | --- | --- |
| Recover interrupted boot | Immutable authority/lease/absence checks precede guarded AVD recovery and full mutable validation; first specific startup failure is durable | Interrupted transaction recovery and subsequent launch passed; malformed/tampered cases fail closed |
| Preserve clean shutdown | Bounded logcat shutdown; capture drain before guest exit; driver/profile/configuration restoration | Latest r17 controlled session sealed `STOPPED`; original AVD SHA restored |
| Remember Riot sign-in | DEV-specific Keychain item, exact opaque password bytes, live accessibility recognition/focus checks, authenticated input, one attempt per form, manual cancellation | Three earlier r12 cold launch → saved sign-in → lobby → quit cycles passed; r14 driver reached lobby. Current r17 access is denied, so current login readiness is not established |
| Prevent Keychain wait from freezing runtime | Scoped process-local legacy no-interaction setting; credential read off runtime actor; ACL and secret bytes unchanged | Previous live stack proved `SecItemCopyMatching` blocked. Production reader now returns denial in milliseconds and restores its prior interaction state; live r17 telemetry and quit continue after denial |
| Guarded ANGLE optimization | Allocation/generation/format/offset/range-aware buffer-view and descriptor reuse; original behavior remains fallback | Original reuse build: 64 conformance passes, two skips. Latest instrumentation build needs its own conformance rerun; title/login produced zero eligible creation/reuse operations |
| Repair candidate shader cache compatibility | Actual ANGLE shader-program ABI contributes to advertised version/cache namespace | Rejected r13 crashed with invalid program binary version both with reuse enabled and disabled. r14 changed namespace and successfully launched; preserved raw failures |
| Record actual boundaries | Actual TFT PID/loaded library proof, bounded ANGLE swap aggregates/creation spans, actual drawable `presentedTime` plus source identity, input/resource samples, explicit loss | r17: 4,329 TFT ANGLE swap aggregates, no missing/malformed/lost driver events. Swap identity is not submission or presentation lineage |
| Preserve diagnostic evidence | Sealed raw Perfetto artifacts, analysis after guest exit, failure retention, admission rejection | Actual automatic trigger and readable sealed trace passed in earlier captures; missing-producer and failed-write cases were rejected. Combined healthy admission remains open |

[SHA-256 receipts](docs/receipts/2026-09-06-dev-r17/sha256-receipts.json) bind the source, signed core, three driver libraries, private capture database, validation log and gate records. The committed receipt copies contain no credentials or raw private captures.

Latest native verification: **110 tests passed**, plus source checks and unsigned Release validation. The source hashes were checked again before this commit; only checkpoint documentation/metadata changed afterward. This commit did not rerun a gameplay experiment.

## Exact candidate and commands

Installed DEV core SHA-256:

```text
ba79729f2e9330749bc64475b361e96c8357d741f92f9083c8bc0d02f3fc228d
```

Selected driver: `DriverBuildExchange/dev-observed-reuse-cache-r14`, ANGLE `1166eec4c0b125e9e945196acfc549983ef72b18`, guarded reuse enabled, view diagnostics enabled, capture/replay disabled. Reproducible patch and scripts are in `DriverRuntime/angle1166/`; the loaded library hashes are in the receipts. The pinned build/dependency manifests preserve the original build results separately from the current candidate.

When DEV is stopped and the authorized login test can resume:

```sh
/usr/bin/open -n \
  --env 'TFTMAC_ANGLE_DRIVER_MANIFEST=/Volumes/MAC MINI M4/TFTMAC/DriverBuildExchange/dev-observed-reuse-cache-r14/driver-manifest.json' \
  --env TFTMAC_ENABLE_AUTO_PERFETTO=1 \
  '/Applications/TFTMAC DEV.app'
```

A normal Finder launch does not select this experimental driver. At commit preparation, DEV was already running session `2026-09-06T10-39-44.933Z-1aeec1e4-b16a-4462-95e8-b255aa0d8322`, with no candidate-driver selection event observed. That active session was left untouched and is not a frozen candidate match.

Native verification and DEV-only build:

```sh
/bin/zsh scripts/verify-tftmac.command
/bin/zsh scripts/build-dev-launcher.command
```

The build command produces `dist/TFTMAC DEV.app`; it does not install it. Do not use `install-desktop-launchers.command` for DEV-only work because it also touches Control.

For a closed capture:

```sh
/opt/homebrew/bin/python3 DriverRuntime/angle1166/capture-admission.py '<absolute closed capture directory>'
```

An admission result is diagnostic only. Latest r17 correctly fails admission because its short denied-login test did not trigger/seal an automatic Perfetto capture.

## Current blocker and next decisive test

The saved password was corrected to contain no backslash before the earlier successful sign-ins. Do not change its bytes again or commit any credentials. The item uses service `com.flashls1.tftmac.dev.riot-login.v1`.

The latest controlled app read is denied by macOS (`-25293`). The default Keychain was unlocked, which does not prove this item grants the app access. Protected SecurityAgent UI cannot be operated by the computer-use tool. User authorization for the DEV item must be resolved without weakening access controls. Then immediately retry saved sign-in → lobby → quit; do not stack other infrastructure first.

After that test: close the remaining admission-checker process-replacement rejection gap, obtain one complete healthy sealed recording admission with actual TFT producers, freeze the batch manifest, stop the build VM/compilers, and present DEV for a user-played diagnostic match. Preserve every failed or early-exit run. Do not rebuild, change flags or analyze heavily during play.

## Acceptance still open

- Actual exercise and recoverable time of the buffer-view optimization during gameplay.
- Latest instrumented-driver conformance, including lifetime/storage/range/format/context/fence/cache cases required by the approved plan.
- Full producer relationships and clock uncertainty/coverage; full fault cases; collector overhead ≤1% throughput and ≤0.25 ms added p95.
- Five alternating validated workload repetitions when available, then two complete real matches including late combat and a fresh boot, at unchanged requested quality.
- Consistent actual TFT presentation and unique delivered frames at 60 FPS. Neither a 58 FPS average gate nor a 60 Hz native counter can pass.
- Fresh free-space checks before comparisons: ≥8 GiB internal and ≥20 GiB external. No performance comparison was made for this commit.

## Rollback and private evidence

Diagnostics: `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/HighPerfResume20260905`.

Preserved signed DEV bundles there include `rollback-c26b020.bundle-backup` and `dev-launch-r8-working.bundle-backup`. Restore only DEV after confirming runtime ownership and no running emulator, verify the selected backup signature/hash, and verify original AVD configuration and clean next launch. Do not reset Android userdata or copy anything over Control. Latest original AVD SHA: `b8cccc257dcc114ae5e6d24149514b7149b7e60a580fb74f79ca343823c28125`.

Latest controlled capture: `~/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures/2026-09-06T09-57-20.168Z-a2795625-615f-4b71-9dd6-1a2772297a9c`. The prior stalled 09:38 capture and sample remain preserved as a failed preflight. Raw captures, generated binaries, Keychain data and credentials remain outside Git.

## ZEN GATE DISCOVERY REPORT and scope audit

- The suspected surface-only login polling race did not cause the observed stall. Live sampling reached the credential read. The speculative polling repair and its test were removed before installation. Revisit only with a reproducing case.
- The recurring exact ADB root/unroot connection-closed error became a proven boot dependency; its bounded UID-verified repair is included. The rare recovered-closed branch has no actual runtime exercise receipt yet.
- The admission checker needs explicit rejection of an unverified replacement TFT process before any full healthy readiness claim. That gap is recorded; this checkpoint does not claim admission passed.
- Historical tracking/build manifests retain their original evidence dates and variant scope. Earlier replay/sign-in/conformance results do not prove current gameplay correctness or improvement.

Changed code maps to approved launch/recovery/login, independent input, deferred artifact analysis, native/ANGLE evidence, clock handshake, guarded driver build/selection and required validation. Documentation adds current authority, gates, hashes and remaining gaps. Four pre-existing untracked `.clara/plans/bddd2d6c...` scratch helpers were preserved outside the commit. No unrelated source cleanup, Control change or publication is included.

The approved plan's ZEN GATE V4 execution lock remains in force for continuation: only approved requirements, required validation or a proved blocking dependency may change; record non-blocking discoveries; audit and remove unjustified hunks before completion.
