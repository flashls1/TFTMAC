# TFTMAC Clean Ownership — Execution Preflight Evidence Handoff

**Purpose:** eliminate redundant rediscovery before executing `TFTMAC_CLEAN_OWNERSHIP_PLAN.md`.

**Status:** REQUIRED IMPLEMENTATION INPUT  
**Authority repository:** `flashls1/TFTMAC`  
**Observed master at preflight creation:** `0bb14a566be22af560548fcf5399e41babef05d5`  
**Observed date:** 2026-08-29  
**Native work to preserve:** change `14d01e7a-b64d-4b7f-b856-e3366885b381`

> **Execution rule:** The coding agent must consume this file before doing repository discovery. Items marked **PROVEN / STABLE** are already discovered facts and should not be re-researched unless the referenced file/hash has changed. Items marked **REMEASURE** are intentionally deferred because they are time-sensitive machine state.
>
> This preflight contains exact legacy identifiers and paths solely so they can be removed correctly. It is an execution artifact. Before the final repository-wide forbidden-reference gate, either remove this file from the tracked tree or replace it with a sanitized post-migration record that contains no retired product identifiers.

---

# 1. Start here — what is already known

Do **not** begin by searching the repository generally. The following work has already been completed:

1. Current master/source authority was reconciled.
2. The legacy product contamination was searched across the repository.
3. CI/validation coupling was identified.
4. Runtime control functions that can still invoke the retired application were identified.
5. SQL/data-model legacy identifiers were identified.
6. The abandoned source-built emulator storage root was identified.
7. Redundant TFT project identities were inspected.
8. The MIT licensing boundary was inspected.
9. A new native Xcode/AppKit/Metal TFTMAC Gate 1 implementation was built successfully.
10. Native unit tests passed.
11. The exact installed Android Emulator controller protocol was frozen from the working stock runtime.

The implementation agent should use the maps below as the starting point and spend discovery effort only where this preflight explicitly says a gap remains.

---

# 2. Current authority and branch state

## 2.1 Repository authority — PROVEN / STABLE at this preflight

```text
project: TFTMAC
repository: flashls1/TFTMAC
default branch: master
master at preflight creation: 0bb14a566be22af560548fcf5399e41babef05d5
implementation plan: TFTMAC_CLEAN_OWNERSHIP_PLAN.md
```

The clean-ownership plan was merged by PR #4.

## 2.2 Native implementation work — MUST PRESERVE

```text
change_id: 14d01e7a-b64d-4b7f-b856-e3366885b381
branch: clara/implement-tftmac-native-mac-app-from-tft-14d01e7a
base/head at last observation: 4e5e62b3410426e06f17c52d2b045a221adcdb52
worktree:
/Volumes/MAC MINI M4/Clara/Worktrees/flashls1--tftmac/tftmac--14d01e7a-b64d-4b7f-b856-e3366885b381
state: dirty worktree containing new Gate 1 source
```

**Hard rule:** checkpoint this change before any destructive storage cleanup or worktree retirement. The code listed in section 3 exists only in this active change until checkpointed/merged.

---

# 3. Native Gate 1 code already written and proven

These files are not design suggestions. They are already present in the active native change and were compiled/tested successfully.

## 3.1 App entry point

**File:** `TFTMAC/App/TFTMACApplication.swift`  
**SHA-256:** `463b4a4f83d3f777fb2f3a26f905c2a8cf44aa56a61d6fca27e9e03a27db1de7`

Current implementation:

```swift
import AppKit

@main
enum TFTMACApplication {
    @MainActor private static var coordinator: AppCoordinator?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let coordinator = AppCoordinator()
        Self.coordinator = coordinator
        application.delegate = coordinator
        application.setActivationPolicy(.regular)
        application.run()
    }
}
```

**Important prior compiler finding:** Swift 6 rejected the retained coordinator as unsafely shared mutable state until it was isolated to `@MainActor`. Do not remove that actor isolation casually.

## 3.2 Application coordinator

**File:** `TFTMAC/App/AppCoordinator.swift`  
**SHA-256:** `054912c1da75cb1cab40a838de2d4112559ff516a0019efeac792aca452aa89f`

Current behavior:

- `@MainActor`
- owns `MainWindowController`
- creates/shows the main window on launch
- activates the app
- terminates after last window closes

## 3.3 Main window

**File:** `TFTMAC/App/MainWindowController.swift`  
**SHA-256:** `0a257cb75580f3196c3a24869ef737d343b9579bffb3693c09ff61ad9126f875`

Current facts:

```text
initial content size: 1280 x 720
minimum size: 960 x 540
title: TFTMAC
style: titled / closable / miniaturizable / resizable / fullSizeContentView
fullscreen behavior: fullScreenPrimary
content view: EmbeddedEmulatorView
```

## 3.4 Metal presentation shell

**File:** `TFTMAC/Presentation/EmbeddedEmulatorView.swift`  
**SHA-256:** `1ea417309119395873c36daf723ad2b6f3a32bf1b1cb8e0be3f58176e259ecf5`

Current proven shell:

```text
base class: MTKView
Metal device: MTLCreateSystemDefaultDevice()
pixel format: bgra8Unorm_srgb
preferred FPS: 60
framebufferOnly: true
continuous drawing: enabled
```

It currently clears/presents the drawable; real emulator frame ingestion is intentionally not implemented yet. Do not mistake this for completed embedded rendering.

## 3.5 Viewport/input mapper

**File:** `TFTMAC/Presentation/ViewportMapper.swift`  
**SHA-256:** `a5a3158be2fb5d0513dbba4298c4849553c2b06df4e429e24430bb70d336984d`

Already implements:

- aspect-fit rectangle calculation;
- centered letterbox handling;
- viewport point -> source coordinate conversion;
- rejection of input outside displayed game content.

This is the intended base for 1920x1080 Android coordinate mapping.

## 3.6 Native Gate 1 tests

**File:** `Tests/TFTMACTests/TFTMACGate1Tests.swift`  
**SHA-256:** `b5bba4165b4c3db761a2d8ddd23a1952e59c0fe956da19260fe19f71bda7e01b`

Existing tests prove:

```text
1920x1080 -> 1600x900 fills exact 16:9 viewport
letterbox area produces no Android touch
viewport center maps to source 960,540
```

These tests are useful regression protection and should survive ownership cleanup.

## 3.7 Build evidence — PROVEN

Successful native Release build operation:

```text
operation: tftmac-native-gate1-build-after-mainactor-20260829
result: SUCCEEDED
exit_code: 0
```

Successful native test operation:

```text
operation: tftmac-native-gate1-tests-quiet-20260829
result: SUCCEEDED
exit_code: 0
```

The first test attempt hit Clara's command-output ceiling due verbose Xcode output, not a logical test failure. `scripts/test-native-app.command` was changed to quiet Xcode output and then succeeded. Preserve quiet-output behavior.

---

# 4. Native Xcode/dependency facts already resolved

## 4.1 Xcode project

`TFTMAC.xcodeproj` exists in the active native change.

Observed build configuration facts:

```text
architecture: arm64
Swift: 6.0
macOS deployment target in generated project: 15.0
Release optimization: -O / whole-module
```

Do not recreate the project from scratch unless it is proven corrupt.

## 4.2 Swift package versions resolved successfully

The first successful resolution/build proved this dependency set works together:

```text
grpc-swift-2            2.4.2
grpc-swift-nio-transport 2.9.1
grpc-swift-protobuf     2.4.1
SwiftProtobuf           1.38.1
```

Transitive versions are frozen in:

```text
TFTMAC.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Do not research substitute gRPC libraries before using this already-resolved graph.

---

# 5. Installed Android Emulator controller authority already frozen

## 5.1 Proven installed runtime

**Installed emulator version:**

```text
Android emulator version 37.1.11.0
build_id 15917651
```

**Installed binary:**

```text
/Volumes/MAC MINI M4/TFTMAC/Runtime/sdk/emulator/emulator
```

## 5.2 Controller proto authority

**Installed proto:**

```text
/Volumes/MAC MINI M4/TFTMAC/Runtime/sdk/emulator/lib/emulator_controller.proto
```

**Vendored proto:**

```text
Vendor/AndroidEmulator/emulator_controller.proto
```

**SHA-256 for both:**

```text
1d62c6bcad5f06621f90ec2bf26c661ba769ccd0f1416b5314d25a68e04eee5f
```

**Provenance file:** `Vendor/AndroidEmulator/SOURCE.json`  
**SHA-256:** `936aed845d7688a71c25daa4d1b1136f9f2b1766fadbca4f50bce4d20051c6f3`

Known source authority recorded there:

```text
emu branch: emu-master-dev
qemu commit: ae9d18d2b6261179fbd57fffec720a04f7bfb053
aemu commit: 3c1ced8a369417db591eb7cd083af5bb2c317975
manifest SHA-256: 28865cd8a162178ba462b296f5714b6b7b6916e0cafcddfc0c5e44aa03f8e8d3
```

**Implementation rule:** generate/use the client from this frozen installed protocol. Do not fetch a random current AOSP proto and assume compatibility.

---

# 6. Current legacy validation coupling — exact locations

This is a required early cutover because deleting old source before replacing validation will deliberately break CI/Clara validation.

## 6.1 GitHub CI

**File:** `.github/workflows/ci.yml`

Current steps include:

```text
Validate repository policy and metadata -> ./scripts/verify-repository.command
Run launcher unit tests and production typecheck -> ./scripts/test-mactician.command
```

The old test invocation is at approximately line 29 in the current file.

**Action:** REWRITE CI before deleting the old launcher/test tree.

Target replacement from implementation plan:

```text
./scripts/verify-tftmac.command
native Xcode Release build
native XCTest
frozen proto verification
Package.resolved verification
SQL/SSOT integrity checks that remain current
forbidden-reference scan
```

## 6.2 Clara registered production validator

The Clara TFTMAC project validator is also currently wired to:

```text
./scripts/test-mactician.command
```

**Action:** update Clara project validation only after the new TFTMAC verifier passes on the exact implementation change.

---

# 7. Runtime-control legacy code — exact hotspots already found

**Primary file:** `tools/tftmac-direct-control.mjs`

Do not perform a blind file-wide rename. Use the classifications below.

## 7.1 Baseline profile naming — MIGRATE/RENAME, preserve values

Current symbol:

```text
DONOR_PROFILE
```

Definition begins around line 21.

The symbol is used throughout:

```text
prepareDonorAVD
startDonorEmulator
donorRuntimeState
startDonorControl
window-fit functions
shutdown restore logic
```

Current runtime values represented by that profile are useful TFTMAC baseline facts; preserve values while moving them to TFTMAC-owned names such as:

```text
BASELINE_PROFILE
prepareBaselineAVD
startBaselineEmulator
baselineRuntimeState
startBaselineControl
```

## 7.2 Legacy baseline IDs — SQL-aware migration required

Current IDs found in code/data:

```text
mactician_compatible_official_v0
mactician_compatible_5gb_v1
mactician_compatible_5gb_flush400_v1
```

Known code locations include approximately:

```text
tools/tftmac-direct-control.mjs:22
tools/tftmac-direct-control.mjs:1406
tools/tftmac-direct-control.mjs:1895
tools/tftmac-direct-control.mjs:2140-2141
tools/tftmac-direct-control.mjs:2257
tools/tftmac-direct-control.mjs:3995
tools/tftmac-direct-control.mjs:4295
tools/tftmac-direct-control.mjs:4731-4732
```

Target names proposed in the plan:

```text
tftmac_official_baseline_v1
tftmac_5gb_baseline_v1
tftmac_5gb_flush400_exp_v1
```

**Do not plain-text replace SQL keys.** See section 9.

## 7.3 Old app launch/stop/audit functions — DELETE

Known functions/dispatches:

```text
launchMacticianControl()              around line 4546
stopMacticianControl()                around line 4557
macticianRuntimeAudit()               later in same section
'action === launch-mactician-control' around line 4725
'action === stop-mactician-control'   around line 4726
```

`tools/tftmac-v2.mjs` also currently allowlists those actions around line 1578.

**Action:** DELETE the functions and remove them from every command allowlist/usage string. They must not remain callable under a renamed alias.

## 7.4 Old installed-app/Application Support probes — DELETE

Known current paths in `tools/tftmac-direct-control.mjs`:

```text
/Applications/Mactician.app
~/Library/Application Support/Mactician/sdk/platform-tools/adb
/Volumes/MAC MINI M4/Mactician/sdk/platform-tools/adb
~/Library/Application Support/Mactician/logs
/Volumes/MAC MINI M4/Mactician
```

These are used by old process/audit/ADB cleanup functions.

**Action:** remove these discovery paths entirely after confirming no current TFTMAC runtime function depends on them.

## 7.5 Legacy icon fallback — DELETE/REPLACE

Known current line near 4473:

```js
const iconSource = path.join(repoRoot, 'branding', 'generated', 'Mactician.icns');
```

This is a direct path from the current TFTMAC build fallback to retired branding.

**Action:** replace with a TFTMAC-owned icon or omit icon copy until a TFTMAC asset exists. Never retain the old asset as fallback.

---

# 8. Legacy product source/assets — known removal groups

Repository search returned hundreds of legacy references. The following groups are already identified and should be processed directly, not rediscovered from scratch.

## 8.1 Launcher implementation — DELETE unless a specific current TFTMAC dependency is proven

```text
launcher/Sources/*
launcher/Tests/*
launcher/Resources/*
launcher/EmulatorHost/*
launcher/Info.plist
```

Known embedded identities include:

```text
dev.sergeinaumov.mactician
dev.sergeinaumov.mactician.game-host
```

These appear in `launcher/Info.plist`, `launcher/Resources/EmulatorHost-Info.plist`, source queue labels, tests, keychain/defaults metadata, and helper targets.

The preferred action is deletion of the obsolete launcher layer, not wholesale renaming of dead source.

## 8.2 Legacy branding — DELETE

Known source assets:

```text
branding/mactician-app-icon.svg
branding/mactician-favicon.svg
branding/mactician-game-host-icon.svg
branding/mactician-mark.svg
branding/mactician-mark-dark.svg
branding/mactician-mark-light.svg
branding/mactician-mark-monochrome.svg
branding/mactician-open-graph.svg
branding/mactician-product-hero.svg
branding/mactician-small-size-test.svg
branding/mactician-social-preview.svg
branding/mactician-wordmark.svg
branding/generated/Mactician.icns
```

Also remove related generation scripts and generated PNG/ICO files.

## 8.3 Legacy build/release/update scripts — DELETE

Known obsolete scripts include:

```text
scripts/build-mactician.command
scripts/build-mactician-icns.pl
scripts/generate-mactician-assets.command
scripts/integration-test-mactician.command
scripts/publish-mactician-update.command
scripts/test-mactician.command
```

Other scripts must be reviewed if they reference legacy Application Support, bundle IDs, old Game Host, hosted game updates, or legacy profile markers.

## 8.4 Legacy docs/metadata — REWRITE

Known files currently centered on the old product:

```text
README.md
CHANGELOG.md
CONTRIBUTING.md
SUPPORT.md
SECURITY.md
NOTICE.md
docs/architecture.md
docs/building.md
docs/releasing.md
docs/reproducibility.md
docs/telemetry.md
docs/troubleshooting.md
.github/pull_request_template.md
.github/repository-metadata.yml
.github/ISSUE_TEMPLATE/bug_report.yml
```

Rewrite them for TFTMAC rather than leaving donor-era product instructions.

---

# 9. SQL and evidence migration map — do not rediscover the key problem

## 9.1 Performance lab

**File:** `ssot/TFTMAC_PERFORMANCE_LAB.sql`

Known current metadata/key references:

```text
line ~527 current_playable_baseline -> mactician_compatible_official_v0
line ~559 baseline config row
line ~560 5 GiB candidate
line ~561 flush400 candidate
line ~574 exp_ram_5gb_ab baseline/candidate references
line ~575 exp_native_frame_trace baseline reference
line ~578 baseline_config_id update
line ~585 supersession note
line ~597 exp_asg_flush400_ab references
line ~598 performance mode A/B baseline reference
line ~599 FPS cap A/B baseline reference
line ~600 graphics preset A/B baseline reference
line ~640 latest closed session label
line ~647 current graphics experiment label
```

**Required implementation:** transactional/idempotent relational migration. Preserve measurements, timestamps, experiment relationships and verdicts. Run `PRAGMA foreign_key_check` before commit.

## 9.2 Engineering map

**File:** `ssot/TFTMAC_ENGINEERING_MAP.sql`

Known legacy-heavy areas include approximately:

```text
~266 tftmac_shell note
~662-672 donor/version/evidence component rows
~697-749 donor documents/version stacks
~792 deployment-target decision tied to donor evidence
~888 version strategy history
~963-1000 legacy docs/runtime profile rows and experiment records
~1021-1025 donor artifact registry
~1344 current presentation candidate naming
~1358 latest closed run naming
~1364 current graphics next action naming
```

**Action classification:**

- current product decisions that TFTMAC has independently reproduced -> rewrite as TFTMAC evidence;
- historical donor-only rows no longer needed for current decision -> remove/compact;
- negative experimental facts still protecting against regression -> preserve result but remove retired product identity where legally/semantically possible;
- relational IDs -> migrate carefully, not string replace.

---

# 10. Current package/update authority — already decided

Do not rediscover or redesign the package lifecycle.

Current product authority is:

```text
Android guest: official Google Play image
TFT package: com.riotgames.league.teamfighttactics
installer/update authority: com.android.vending
Riot content initialization/patching: official Riot application behavior
```

Forbidden to reintroduce:

```text
hosted TFT APK feed
bundled game APK
third-party game update service
APK repacking
APK re-signing
binary patching
manual Riot content patch bundle
```

Existing runtime tooling already has package-state/Play diagnostics that should be kept where they operate on TFTMAC's stock runtime.

---

# 11. Storage map already discovered

## 11.1 Protected runtime — KEEP

The working runtime is under:

```text
/Volumes/MAC MINI M4/TFTMAC/Runtime
```

Known protected sub-authorities include:

```text
/Volumes/MAC MINI M4/TFTMAC/Runtime/sdk
/Volumes/MAC MINI M4/TFTMAC/Runtime/AVD
```

The current working AVD/product state must not be deleted during cleanup.

Also preserve:

```text
Google Play account/session state in AVD
official TFT package and Riot data in AVD
current runtime manifests required by stock control
current package authority evidence
Vendor/AndroidEmulator protocol snapshot
native source/worktree
```

## 11.2 Abandoned source-build tree — PRIMARY RECLAIM CANDIDATE

Known path:

```text
/Volumes/MAC MINI M4/TFTMAC/Build
```

Known contents/uses from earlier work:

```text
repo launcher
AEMU multi-repo checkout
external/qemu source
prebuilts
CMake/Ninja objects
source-build compatibility wrappers
reference/CTS trees
phase1 build logs
failed worker/source-build state
```

Project research recorded the development tree around **131 GB** historically.

Known source references that can recreate/use it:

```text
TFTMAC_FULL_IMPLEMENTATION_PLAN.md ~261-262, 481-496
ssot/phase0-remediation-inventory.md ~43,65
ssot/phase0-source.json ~31+
ssot/TFTMAC_ENGINEERING_MAP.sql ~314-315,444,670
tools/tftmac-v2.mjs constants and Phase 0/Phase 1 source-build functions
```

**Hard sequence:** remove/disable current recreation paths first; prove stock runtime/native build independence; then delete the exact Build candidate.

## 11.3 Native build caches — DISPOSABLE AFTER CHECKPOINT

The active native worktree currently contains large generated `.build/native-release` and `.build/native-tests` trees from Xcode/SwiftPM.

They are useful proof that compilation happened but are not source authority.

After source is checkpointed and Package.resolved is retained, these generated caches are reclaimable and can be regenerated.

Do not treat generated Xcode object files as required evidence.

## 11.4 Exact size/free space — REMEASURE

No exact current byte count was frozen because the live disk probe was rejected by Clara allowlist during the earlier preflight.

At execution time, measure:

```text
free bytes before cleanup
Build tree bytes
Runtime tree bytes
capture/diagnostic bytes
native .build/DerivedData bytes
redundant project/worktree bytes
free bytes after each tier
exact reclaimed bytes
```

This is a machine-state remeasurement, not repository rediscovery.

---

# 12. Redundant project state already inspected

## 12.1 TFTMAC2 — RETIREMENT CANDIDATE

Observed project:

```text
project_id: tftmac2
repository: flashls1/tftmac2
head: 30f9695b757551bad9fc788423e031e46a89f43d
active changes: 0
operations: 0
release: none
```

Contents observed as minimal foundation files only (`facts.md`, `AGENTS.md`, `README.md`, `.clara/project.json`).

**Required remaining work:** one unique-content/commit check, then retire/archive/remove from active Clara catalog.

Do not perform broad rediscovery.

## 12.2 TFTMAC Runtime — UNIQUE-CONTENT REVIEW REQUIRED

Observed project:

```text
project_id: tftmac-runtime
repository: flashls1/tftmac-runtime
main head: a121c2681132428c0b3e04d73d748ffae1b3ffe2
```

One published but unmerged managed change exists:

```text
change_id: 7c24d6df-bb78-4a4d-9c8f-1b4028871f60
branch: clara/phase-2-compatibility-laboratory-reevalu-7c24d6df
head: 994cf8d8524b87cc03c7decb4b253fc7be2253c7
state: published / clean
```

**Required remaining work:** diff that exact head against current TFTMAC knowledge and classify only unique items:

```text
MIGRATE_TO_TFTMAC
ALREADY_SUPERSEDED
REJECTED_OBSOLETE
```

Do not rerun the old compatibility laboratory just to understand the branch.

---

# 13. Licensing boundary already discovered

**Current `LICENSE`:** MIT license with copyright:

```text
Copyright (c) 2026 Sergei Naumov
```

**Current `NOTICE.md`:** describes the old product and third-party components.

The implementation agent must not assume that removing branding permits removing legally required copyright/license notices from substantial retained source.

Efficient path:

1. delete obsolete copied implementation wherever TFTMAC no longer needs it;
2. identify any substantial retained upstream-derived portions;
3. retain required MIT notice for those portions in neutral third-party notices;
4. rewrite/remove obsolete product-specific NOTICE text;
5. if no substantial licensed upstream portion remains, update project licensing metadata truthfully.

This is a code-origin audit, not a branding preservation requirement.

---

# 14. Known exact legacy identifier groups

The repository currently contains the retired product token in hundreds of locations. Do not spend a new session proving that fact.

Known categories already established:

```text
product name in README/docs
bundle IDs
Application Support paths
keychain/defaults/logging subsystem names
launcher source/tests
helper Game Host app
build/release/update scripts
branding source/generated assets
CI and PR templates
runtime control actions
runtime process detection
profile/config IDs
performance-lab keys
engineering-map evidence rows
historical experiment scripts
old update URLs/feed logic
```

Final verification still must run a full forbidden-reference scan because implementation may miss an occurrence, but that scan is **validation**, not discovery.

---

# 15. What to keep from current `tools/tftmac-direct-control.mjs`

Ownership cleanup should not throw away the working TFTMAC runtime harness.

Known useful current capabilities to retain under TFTMAC naming include:

```text
runtime inventory/discovery
AVD preparation for stock runtime
stock emulator start/stop
Google Play account UI
Play certification/diagnostics
package-state capture
TFT launch/restart/status
CoreAudio health/probes
logger health
raw-first capture sealing
fast closed-run analysis
continuous-run analysis
SQLite normalization
SurfaceFlinger counters
native trace capability
window/presentation probes until native embedded replacement is proven
Android back/home/overview/power/volume/rotate/screenshot controls where still used
runtime process audit for TFTMAC/emulator/ADB
native Gate 1 bootstrap/build/test actions added in active native change
```

The cleanup target is legacy product coupling, not wholesale deletion of the proven TFTMAC harness.

---

# 16. Already rejected/obsolete paths — do not restart them

Do not restart source-built AEMU merely because its source tree exists.

Known obsolete research path facts:

```text
AEMU source checkout was moved to external Build root due internal-disk exhaustion
source build entered a 9,854-step Ninja compile
one observed failure was old macOS deployment-target/toolchain compatibility
later project direction explicitly chose released stock Emulator control instead
stock Emulator 37.1.11 is already working
native client freezes installed EmulatorController contract directly
```

Unless a new measured blocker proves a released-emulator limitation that cannot be solved otherwise, source-building AEMU is out of scope.

---

# 17. Implementation order — optimized to avoid duplicated work

The implementation agent should execute in this order:

## A. Preserve current native source

1. review `14d01e7a...`;
2. checkpoint its source files;
3. preserve `Package.resolved` and proto provenance;
4. exclude generated `.build` products from the checkpoint unless intentionally tracked.

## B. Cut validation over before deleting old tests

1. create `scripts/verify-tftmac.command`;
2. make it build/test the native Xcode target and run current static/SQL checks;
3. run it locally;
4. update GitHub CI;
5. update Clara project validation;
6. prove the new validator passes.

## C. Remove obsolete product layers

Use sections 7-9 and 14 as the source map. Delete old launcher/updater/branding paths; rename only active TFTMAC baseline concepts; migrate SQL relationally.

## D. Prove runtime independence

Use existing stock-runtime inventory/package/proto probes. Do not rebuild the runtime. Prove no required path resolves through `/Volumes/MAC MINI M4/TFTMAC/Build` or the retired installed application.

## E. Measure and reclaim storage

Remeasure exact machine bytes, classify candidates, delete by tier, and smoke-test after the large Build deletion.

## F. Retire redundant projects

TFTMAC2 first after unique-content check. TFTMAC Runtime only after exact `994cf8...` unique-content migration/supersession review.

## G. Resume native Gate 2

Continue from the already-built Gate 1 Xcode project into authenticated hidden-emulator `EmulatorController` status/control. Do not recreate Gate 1.

---

# 18. Mandatory implementation-agent no-rediscovery rules

The coding agent MAY re-check a fact only when:

```text
the referenced source hash changed;
the branch/head moved materially;
a required file no longer exists;
a runtime/storage fact is explicitly marked REMEASURE;
a validation run contradicts this preflight;
or a current compile/runtime error proves the recorded fact stale.
```

The coding agent MUST NOT:

```text
repeat broad donor research;
repeat old source-build feasibility experiments;
redesign the dependency stack before using the resolved one;
rebuild the Xcode project from scratch;
redo the legacy-reference inventory as its first task;
retest whether the old launcher is useful;
rerun the old compatibility laboratory to understand its branch;
recreate the abandoned Build tree to inspect it;
reinstall the retired application for comparison;
```

A final repository-wide scan after implementation is required as validation, but it must be treated as a completeness gate rather than a new discovery phase.

---

# 19. Remaining truthful unknowns

These are the only material items intentionally left for execution-time resolution:

1. **REMEASURE:** exact current bytes used by `/Volumes/MAC MINI M4/TFTMAC/Build`.
2. **REMEASURE:** exact free bytes before/after cleanup.
3. **REMEASURE:** exact bytes in captures/native build caches/redundant project roots.
4. **REVIEW:** unique content in `tftmac-runtime` head `994cf8d8524b87cc03c7decb4b253fc7be2253c7` not already represented in TFTMAC.
5. **LEGAL REVIEW:** which substantial upstream-derived source portions, if any, remain after deletion/replacement and therefore require MIT attribution.
6. **IMPLEMENTATION:** generated Swift protobuf/gRPC client sources from the frozen installed proto are not yet committed.
7. **IMPLEMENTATION:** native Gate 2 hidden authenticated EmulatorController connection/status/shutdown is not yet complete.

Everything else above should be treated as existing engineering knowledge, not an invitation to start over.

---

# 20. Preflight completion criteria

This preflight is considered successfully consumed when the implementation agent can begin with the following statement of fact:

```text
I know which current native files already compile and test,
which exact old source groups are obsolete,
which runtime functions need delete vs rename,
which SQL IDs require relational migration,
which validation paths must be cut over first,
which runtime/storage paths are protected,
which bulk Build path is the primary reclaim target,
which project identities are retirement candidates,
and which facts must be remeasured rather than rediscovered.
```

At that point implementation should begin. No second discovery phase is required.
