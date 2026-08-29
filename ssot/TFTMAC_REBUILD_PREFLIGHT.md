# TFTMAC Rebuild Preflight — Fact Base Before Specification

**Status:** ACTIVE PREFLIGHT — specification is intentionally not frozen yet  
**Date:** 2026-08-28  
**Purpose:** Replace assumption-driven implementation with a fact-driven product specification using current TFTMAC evidence, the successful Mactician run on the target Mac, current Mactician open-source code, and explicit product requirements.

---

## 0. Governing rule

This document is the decision boundary between research and the next TFTMAC specification.

The next spec may contain only:

1. facts already proven by current TFTMAC evidence;
2. facts reproduced on the target Mac;
3. source-verified donor behavior that we deliberately choose to adopt;
4. explicit product requirements from the user;
5. clearly labeled unresolved decisions with a bounded preflight probe.

The existing `TFTMAC_GPU_RUNTIME_SSOT.md` and `TFTMAC_FULL_IMPLEMENTATION_PLAN.md` remain historical planning inputs, but their source-built-AEMU critical path is **not automatically authoritative for the rebuild**. No new source-AEMU work should resume merely because the old plan says to do so.

Donor research remains quarantined in:

`ssot/donors/TFTMAC_DONOR_RESEARCH.sql`

Nothing enters production truth merely because Mactician or another donor did it.

---

# 1. Evidence classes

Every fact in the rebuild must be attributable to one of these classes.

| Class | Meaning |
|---|---|
| `PROJECT_PROVEN` | Proven by current TFTMAC project artifacts or probes. |
| `TARGET_HOST_PROVEN` | Observed directly on the target Mac Mini M4. |
| `DONOR_SOURCE_VERIFIED` | Present in current open-source donor code/manifests. |
| `DONOR_AUTHOR_MEASURED` | Published by the donor author with a described controlled measurement. |
| `TARGET_RUNTIME_OBSERVED` | Observed in the actual Mactician runtime/log on this Mac. |
| `USER_OBSERVED` | Direct user observation during actual use; requires instrumentation before becoming a quantitative engineering claim. |
| `PRODUCT_REQUIREMENT` | Required behavior regardless of donor implementation. |
| `UNKNOWN` | Must be resolved before the corresponding spec section is frozen. |

---

# 2. Target Mac — proven facts

Source: `ssot/host-preflight.json`, `ssot/STACK.lock.yaml`.

| Fact | Value | Class |
|---|---|---|
| Host | Mac mini | `PROJECT_PROVEN` |
| Model | Mac16,10 | `PROJECT_PROVEN` |
| Chip | Apple M4 | `PROJECT_PROVEN` |
| RAM | 16 GB | `PROJECT_PROVEN` |
| Architecture | arm64 | `PROJECT_PROVEN` |
| macOS | 26.6.2 build 25G83 | `PROJECT_PROVEN` |
| Installed Xcode | 26.6 / 17F113 | `PROJECT_PROVEN` |
| Additional Xcode | 26.4 / 17E192 | `PROJECT_PROVEN` |
| Current macOS SDK | 26.5 | `PROJECT_PROVEN` |
| Google Emulator control version already known | 37.1.11 | `PROJECT_PROVEN` |

### Rebuild consequence

The target host is already proven capable of running Google Android Emulator 37.1.11 with hardware acceleration and the Mactician graphics path. The rebuild does not need to prove basic Apple-Silicon virtualization feasibility again.

---

# 3. Storage — new hard direction

## 3.1 Proven/current state

The old TFTMAC path created a very large AEMU source/build workspace on `/Volumes/MAC MINI M4/TFTMAC` and made the external volume mandatory for Build and Runtime roots.

Mactician demonstrates a much thinner product model:

- it ships a native Mac launcher rather than an AEMU source tree;
- it downloads verified released Android components;
- its current README requires 25 GiB of free disk headroom for downloads, extraction, the AVD, game assets, and updates;
- its documented initial download is about 2.3 GB before extraction and provisioning.

Sources:
- https://github.com/tweet9ra/mactician
- https://sergeinaumov.dev/writing/how-i-built-mactician

## 3.2 Product requirements

1. **No 100+ GB or ~200 GB source/build tree is a production dependency.**
2. Source-built AEMU becomes optional research material only unless a measured blocker requires a custom emulator binary.
3. TFTMAC runtime storage must be a bounded installed runtime, not a development checkout.
4. Runtime location must not be hardcoded to one external volume.
5. Default runtime may live in normal macOS Application Support when space permits.
6. A user-selectable external runtime location may be supported for large game/runtime state.
7. The installer must show required and expected disk space before downloading.
8. A cleanup inventory must distinguish:
   - shippable runtime;
   - caches safe to delete;
   - user game/AVD state;
   - optional development source;
   - diagnostic artifacts.
9. Stateful AVD images must never be placed in File Provider/cloud-offloaded storage.

## 3.3 Preflight unknown

`UNKNOWN-STORAGE-01`: Measure a clean direct-Google TFTMAC runtime after install and after one fully patched live TFT session. Freeze exact installed-size budget in the spec only after measurement.

---

# 4. Mactician current upstream — source facts we can legally use

Current public repository:

`https://github.com/tweet9ra/mactician`

License: MIT. The license explicitly allows use, copy, modification, merge, publication, distribution, sublicensing, and sale, provided the copyright/permission notice is retained in copies or substantial portions.

Current repository facts observed 2026-08-28:

| Area | Current donor fact | Class |
|---|---|---|
| App | Native SwiftUI launcher | `DONOR_SOURCE_VERIFIED` |
| Version | 1.1.0 build 45 | `DONOR_SOURCE_VERIFIED` |
| Minimum macOS | 12.0 | `DONOR_SOURCE_VERIFIED` |
| Emulator | Google Android Emulator 37.1.11 | `DONOR_SOURCE_VERIFIED` |
| Guest generation | Android 36 ARM64 | `DONOR_SOURCE_VERIFIED` |
| Installer | Direct verified Android component downloads | `DONOR_SOURCE_VERIFIED` |
| Integrity | SHA-256 verification of runtime components/game splits | `DONOR_SOURCE_VERIFIED` |
| Lifecycle | `needsInstall -> installing -> ready -> launching -> playing -> stopping`, plus failed/recovery states | `DONOR_SOURCE_VERIFIED` |
| AVD ownership | Dedicated AVD create/provision/start/stop/repair/reset | `DONOR_SOURCE_VERIFIED` |
| Settings | Resolution, UI scale, Android RAM, vCPU, language, graphics controls | `DONOR_SOURCE_VERIFIED` |
| FPS | Native FPS overlay service exists | `DONOR_SOURCE_VERIFIED` |
| Audio | Emulator audio recovery service exists | `DONOR_SOURCE_VERIFIED` |
| Input | Native macOS input/hotkey bridge exists | `DONOR_SOURCE_VERIFIED` |
| Recovery | Repair and destructive Reset are distinct | `DONOR_SOURCE_VERIFIED` |
| Updates | Sparkle update mechanism for Mac app | `DONOR_SOURCE_VERIFIED` |
| Diagnostics | Optional extended diagnostics + telemetry notice/service | `DONOR_SOURCE_VERIFIED` |
| Release | Developer ID signing, hardened runtime, notarization | `DONOR_SOURCE_VERIFIED` / author-documented |

Relevant source layout includes:

- `launcher/Sources/CoreModels.swift`
- `launcher/Sources/InstallerService.swift`
- `launcher/Sources/LauncherModel.swift`
- `launcher/Sources/LauncherSettingsView.swift`
- `launcher/Sources/LauncherStateViews.swift`
- `launcher/Sources/LauncherTheme.swift`
- `launcher/Sources/LauncherView.swift`
- `launcher/Sources/RuntimeController.swift`
- `launcher/Sources/FPSOverlayService.swift`
- `launcher/Sources/EmulatorAudioRecoveryService.swift`
- `launcher/Sources/InputBridgeService.swift`
- `launcher/Sources/HostedGameUpdate.swift`
- `launcher/Sources/LauncherTelemetryService.swift`
- `launcher/Sources/LauncherUpdateController.swift`

### Rebuild consequence

We do not need to reinvent the launcher/state-management/product-shell patterns. We may fork or adapt the MIT implementation and then replace the game-delivery, fullscreen/presentation, performance, branding, and runtime policies that do not meet TFTMAC requirements.

---

# 5. Proven working graphics recipe from Mactician

Author engineering source:

`https://sergeinaumov.dev/writing/how-i-built-mactician`

The donor's working conceptual path is:

```text
TFT OpenGL ES
    -> Android ANGLE
    -> Vulkan
    -> Android Emulator gfxstream / MoltenVK
    -> Apple Metal
```

The donor proved that forcing the game itself to direct Vulkan was not the correct boundary. The working route kept the game's GLES renderer and translated beneath it.

The donor also proved:

- native Android Emulator presentation was substantially better than scrcpy because scrcpy added guest CPU video encoding and incorrect input semantics;
- zsh `BG_NICE` could silently reduce QEMU priority to nice=5; normal priority mattered;
- simply adding more vCPU/RAM did not cure the active bottleneck;
- DeviceProfiles/runtime behavior could matter more than visible in-game graphics settings;
- ASG transport materially outperformed legacy `pipe` in a controlled scene;
- cold repeated measurements are mandatory because one-run wins frequently disappeared.

These are engineering priors, not automatic current settings.

---

# 6. Actual successful Mactician run on this exact Mac

Source: copied live runtime log at `artifacts/mactician-live.log` plus direct user observation.

## 6.1 Host/guest runtime facts observed

Mactician successfully launched a runtime on the Apple M4 with:

- Android Emulator 37.1.11;
- Android 36 ARM64 Google APIs image;
- gfxstream;
- Apple M4 selected through MoltenVK;
- Vulkan 1.4.x host path reported by MoltenVK;
- guest ANGLE;
- `virtio-gpu-asg` graphics transport;
- ASG write buffer 1,048,576 bytes;
- ASG write step 16,384 bytes;
- ASG data ring 32,768 bytes;
- 1920x1080 framebuffer;
- 320 DPI;
- 60 Hz;
- 6 guest cores;
- 6144 MB guest RAM;
- audio enabled;
- asynchronous MoltenVK queue submission;
- 64 active Metal command buffers;
- fast math;
- PSO watcher/scheduling adjustments;
- donor graphics profile identified in the log as `osft`;
- `preferSubmitAtFBOBoundary` disabled in ANGLE.

The successful log explicitly reported:

```text
TFT is running: Unreal OpenGL ES -> guest ANGLE -> Vulkan -> Metal
```

and a real TFT process was launched.

## 6.2 Important conformance fact

The successful donor runtime also reported:

```text
ANGLE enabled features: exposeNonConformantExtensionsAndVersions:exposeES32ForTesting
```

and exposed GLES 3.2 to the guest.

This is a **donor compatibility technique**, not automatically a TFTMAC shipping requirement. The old TFTMAC SSOT forbids claiming genuine GLES 3.2 merely through nonconformant version exposure.

The rebuild spec must explicitly choose between:

A. compatibility-first parity with the donor exposure mechanism; or
B. genuine feature-complete ES 3.2 without the exposure shortcut.

The decision must be based on whether current live TFT actually executes features that the host/guest path cannot provide, not on ideology or version strings.

---

# 7. Actual game/update failure we observed

## 7.1 Successful user-visible sequence

The actual user experience was:

1. Mactician installed successfully after one reinstall retry.
2. TFT launched.
3. TFT downloaded a patch.
4. The user logged in.
5. The user joined a party with another current TFT player.
6. When the party attempted to start a game, Riot reported that the game versions did not match.
7. The user restarted Mactician to allow the patch/update state to settle.
8. Subsequent launches failed.

## 7.2 Log evidence

Mactician repeatedly reported:

```text
Hosted TFT feed unavailable, using bundled fallback: Invalid TFT release
```

or:

```text
Game update availability check failed: Invalid TFT release
```

After the failed restart, Android itself still booted successfully, but Mactician then encountered:

```text
stat: '/data/user/0/com.riotgames.league.teamfighttactics': No such file or directory
The owner of TFT private data could not be determined.
```

Mactician then intentionally shut down the emulator. The visible `Snapshots have been disabled by the user` message occurred during shutdown and was not the root cause.

## 7.3 Product consequence

**TFTMAC must not depend on a third-party hosted game-package feed for current live TFT.**

The next architecture uses authoritative upstream delivery directly:

```text
Google Android repository -> Android runtime components
Google Play -> TFT application install/update authority
Riot services -> in-game patch/content/authentication/matchmaking
```

No Sergei/Mactician game feed is a production dependency.

No public APK mirror is a production dependency.

No Riot APK is committed to the repository.

---

# 8. Direct Google/Riot delivery — required architecture

## 8.1 Android runtime components

TFTMAC downloads required Google Android components directly from official Google endpoints and verifies them locally.

Mactician already source-verifies its Android SDK component URLs to `https://dl.google.com`, proving this distribution pattern is simple and productized.

## 8.2 TFT package authority

Primary requirement:

- use a Google Play-enabled guest where practical;
- user signs into Google Play inside Android;
- install official `com.riotgames.league.teamfighttactics` through Google Play;
- Google Play handles APK/split delivery and application updates;
- Riot handles its own in-game content patching;
- TFTMAC records installed package name, versionName, versionCode, signature/certificate identity, and split inventory for diagnostics;
- TFTMAC never invents a current version number from a third-party feed.

## 8.3 Update UX

The launcher needs explicit states:

```text
Game missing
Game installed
Google Play update required/check requested
Riot content patching/incomplete
Ready to play
Version mismatch/recovery guidance
```

The launcher must not treat a missing private-data directory as an opaque fatal crash. It must identify whether the package is missing, not initialized, mid-update, or damaged and present a targeted repair path.

---

# 9. Guest choice — not yet frozen

There are two materially different donor/current paths:

### Candidate A — single official Google Play guest

- official Play-enabled ARM64 Android image;
- Google Play directly owns TFT install/update;
- no root dependency;
- simplest user product;
- preferred architecture if graphics/performance requirements can be met.

### Candidate B — authority/execution split, only if required

- Play-enabled guest is package/update authority;
- rootable execution guest is used only if required for runtime-only graphics/profile controls;
- exact official package splits may be transferred locally only after identity/signature/hash verification;
- no third-party package feed.

### Current rule

Do **not** build Candidate B speculatively.

`UNKNOWN-GUEST-01`: Prove whether Candidate A can launch current live TFT with the required graphics path and acceptable performance. Only if it fails for a root-owned requirement may Candidate B enter the spec.

Android 36 and the existing API 37 Play image are both evidence-bearing candidates. Do not select based on newest/oldest labels alone.

---

# 10. Source-built AEMU — demoted from critical path

## Proven facts

The old plan required building AEMU from `emu-master-dev`. Phase 1 encountered a sequence of host-build compatibility problems and most recently failed because the build adapter forced a macOS 10.14 deployment target while source required `std::filesystem` availability from 10.15+.

Separately, Mactician proves that stock Google Emulator 37.1.11 can execute the relevant graphics stack on Apple Silicon.

## New rule

The normal rebuild starts with the stock released Google emulator.

Source-built AEMU is justified only by a specific measured requirement such as:

- a missing emulator feature that cannot be enabled/configured in stock;
- a confirmed gfxstream defect requiring a patch;
- native presentation integration impossible through supported stock boundaries;
- a performance bottleneck proven inside AEMU/gfxstream source rather than elsewhere.

If none of those occurs, no source AEMU build is part of production.

---

# 11. Performance — current facts and new acceptance behavior

## 11.1 Donor measured facts

Mactician's author reports:

- ASG vs legacy pipe in the same early combat scene: about **40.1 FPS vs 29.6 FPS**;
- reproducible control series around **40.60 / 36.03 / 27.83 FPS** at progressively heavier stages;
- the heavy-stage target of 57 FPS was **not reached**;
- 128 Metal command buffers looked good once but failed cold confirmation;
- forced submit thread regressed performance;
- aggressive PSO prewarm caused crashes;
- higher resolution was not always materially slower because tested scenes were often CPU/RHI/transport bound.

This donor evidence means a lobby overlay showing 60 FPS is not sufficient evidence of a smooth product.

## 11.2 User-observed target-Mac behavior

The user observed:

- approximately 60 FPS in light conditions;
- dramatic transient drops, including a reported drop to roughly 6 FPS while entering/loading activity;
- experience felt glitchy despite the 60 FPS overlay.

This is `USER_OBSERVED`, not yet a controlled benchmark.

## 11.3 Product requirement

TFTMAC performance acceptance must include:

- lobby/light scene;
- game transition/load into match;
- early combat;
- middle combat;
- late/heavy combat;
- shop/board rapid interaction;
- a second warm match after caches are populated.

Metrics:

- presented FPS;
- p50/p95/p99 frame interval;
- >33.3 ms jank percentage;
- >100 ms stalls;
- host CPU;
- host GPU where measurable;
- guest CPU saturation;
- memory pressure;
- shader/PSO worker activity;
- input-to-visible-response latency.

The existing TFTMAC 60 Hz contract remains a candidate target:

```text
average >= 58 FPS
p95 <= 20 ms
p99 <= 33.334 ms
jank <= 1%
```

but the spec must pair these with heavy-scene evidence rather than averages that can hide 6–20 FPS collapses.

`UNKNOWN-PERF-01`: Establish the target-M4 stock-emulator baseline with the donor-compatible graphics path using one fixed heavy scene and one transition measurement before selecting optimization work.

---

# 12. Resource allocation

## Facts

- target Mac has 16 GB total RAM;
- actual Mactician run used 6 vCPU / 6144 MB;
- donor author found that blindly adding CPU/RAM was not causal on his M1 Max;
- TFTMAC historical profiles already considered 6/6144 and 8/8192.

## Requirement

Do not hardcode “more is better.”

Initial target-M4 control:

```text
6 vCPU / 6144 MB
```

Only one bounded comparison is justified initially:

```text
6/6144 control
vs
one alternate profile chosen from measured host pressure
```

No broad CPU/RAM matrix.

---

# 13. Native macOS UI — required product direction

## Donor facts

Mactician already provides a solid native SwiftUI product shell with:

- install/progress UI;
- Play/Stop lifecycle;
- settings menus;
- resolution;
- UI scale;
- CPU/RAM controls;
- graphics controls;
- language;
- hotkeys;
- Repair;
- Reset;
- app update controls;
- diagnostics/feedback concepts;
- clear state-specific UI.

Mactician intentionally keeps the launcher and the running Android Emulator window side by side and provides a macOS **window-fill** shortcut. This is not the same as one native fullscreen game application.

## New hard requirements

TFTMAC must:

1. be a native macOS application;
2. have normal macOS menu-bar behavior;
3. support true macOS fullscreen using the green-window/fullscreen convention and keyboard shortcut;
4. present the game without visible Android Emulator chrome in normal play;
5. make the game visually feel like the application content, not a second utility window the user has to resize;
6. preserve direct/high-performance presentation and must not regress to a scrcpy-like encode/stream path;
7. preserve correct mouse, keyboard, scroll, right-click and focus semantics;
8. provide seamless exit from fullscreen;
9. handle display changes and Retina scaling without making the guest framebuffer lie about its real render size;
10. support 1920x1080 as the initial guaranteed profile and adapt the native window to the physical display.

`UNKNOWN-UI-01`: Select and prove the presentation boundary. The prototype must compare direct emulator presentation against the chosen native fullscreen integration for FPS, frame-time, input latency and window behavior. The implementation may use a custom host/helper only if it preserves the direct-rendering characteristics.

This unknown must be resolved **before** the final UI architecture is frozen.

---

# 14. Display and render profiles

Initial guaranteed product target:

```text
1920x1080 @ 60 Hz
```

Requirements:

- fullscreen window size and actual guest render size are separately measurable;
- no stretched 1280x720 pretending to be 1920x1080;
- UI scaling is independently configurable from actual render resolution;
- dynamic resolution must be observable and not silently defeat quality settings;
- higher-resolution profiles may exist later but do not ship until 1080p heavy-match performance is acceptable.

Do not prioritize 1440p/4K while late-game 1080p performance is unstable.

---

# 15. Graphics tuning — what we inherit and what we do not

## Strong donor priors to reproduce first

- stock Emulator 37.1.11;
- host GPU acceleration;
- ANGLE below TFT GLES;
- Vulkan beneath ANGLE;
- gfxstream;
- MoltenVK -> Metal;
- ASG instead of legacy pipe;
- 16 KiB ASG write step as a control candidate;
- normal host process scheduling priority;
- no scrcpy rendering path;
- async MoltenVK / bounded command buffers as later performance candidates;
- persistent and reversible graphics/profile changes;
- cold-run confirmation before promotion.

## Explicitly not inherited blindly

- nonconformant ES 3.2 exposure as final proof;
- donor `osft` profile name/assumptions;
- stale PBE package hashes;
- donor hosted TFT feed;
- private/bundled Riot APK delivery;
- root requirement unless Candidate A proves insufficient;
- 1440p as primary profile;
- 128/256 Metal command buffer experiments;
- rejected prewarm/submit-thread experiments;
- any tuning whose exact current ANGLE/gfxstream/MoltenVK version differs without remeasurement.

---

# 16. Audio, microphone and voice

## Proven

The target runtime successfully produced game audio. Mactician includes explicit emulator audio recovery logic.

## Requirements

TFTMAC must support:

- stable output audio;
- host microphone transport into Android when enabled;
- macOS microphone permission UX;
- an explicit microphone on/off control;
- no silent microphone activation;
- diagnostics that distinguish “host mic unavailable” from “Android mic unavailable” from “game does not implement voice.”

`UNKNOWN-AUDIO-01`: Determine whether the current live TFT Android package declares/uses microphone/voice functionality. Emulator microphone transport is a product capability regardless, but the spec must not promise Riot in-game voice unless the current client supports it.

---

# 17. Installer and recovery requirements

Borrow the successful product pattern from Mactician, but remove its package-feed weakness.

Required states:

```text
Needs Install
Downloading Android Runtime
Creating Device
Google Play Setup Required
TFT Missing
TFT Updating
Riot Content Updating
Ready
Launching
Playing
Stopping
Repairing
Failed with specific recovery action
```

Required actions:

- Install;
- Play;
- Stop;
- Check/Refresh game state;
- Open Google Play/TFT update path;
- Repair runtime without deleting game state when possible;
- Recreate AVD when runtime corruption is proven;
- Reset only as destructive last resort;
- Export diagnostics;
- optional send-feedback/send-diagnostics flow.

Recovery must be state-aware. A missing package or private-data directory must trigger package recovery, not a generic emulator shutdown.

---

# 18. Diagnostics requirements

The launcher should expose useful diagnostics without requiring Terminal.

Minimum UI-visible diagnostics:

- installed TFT versionName/versionCode;
- Android version/image;
- Emulator version;
- graphics path summary;
- current framebuffer/density/refresh;
- CPU/RAM allocation;
- current FPS;
- p95/p99 frame time over recent window;
- severe-stall counter;
- audio state;
- microphone state;
- Google Play/package state;
- last recovery action;
- log export.

Optional extended diagnostics may include host model/macOS/memory/CPU count and applied runtime profile, with explicit user consent.

No Riot password, session token, Google credential, serial number, or unfiltered private game state should be sent by diagnostics.

---

# 19. App updates vs game updates

These are separate systems.

### TFTMAC application update

- signed/notarized native Mac application;
- Sparkle or equivalent signed update mechanism is acceptable;
- app bundle is replaceable without deleting runtime/user state.

### Android runtime update

- update only when current compatibility testing approves a new Google Emulator/system image;
- do not auto-upgrade a known-good emulator merely because Google published a newer one.

### TFT update

- Google Play is application package authority;
- Riot in-game updater is content authority;
- launcher observes current installed state and guides official update flow;
- no third-party hosted TFT package feed.

---

# 20. Security / trust boundaries

Preserve:

- Riot login occurs inside official TFT client;
- Google login occurs inside Google Play/Android;
- TFTMAC does not request or proxy Riot credentials;
- no Riot APKs or Android userdata committed to Git;
- no third-party APK mirrors as production authority;
- runtime component hashes/integrity are recorded;
- native Mac release is signed/notarized;
- diagnostic upload is explicit and sanitized;
- destructive Reset requires confirmation.

---

# 21. Existing TFTMAC work to retain

The rebuild does **not** mean throwing away everything already learned.

Retain/reuse:

- host preflight and machine discovery;
- Google Android component/version discovery;
- current external/internal storage migration knowledge;
- package inspection tools;
- ADB isolation and serial management;
- capability probes where they answer a current question;
- performance/frame-time methodology;
- historical benchmark/rejected-experiment database;
- known ASG findings;
- MoltenVK/ANGLE/gfxstream research;
- Apple signing/notarization work;
- native shell code where useful;
- update/rollback/diagnostic design;
- engineering map and donor research database.

Demote/archive from critical path:

- giant AEMU source checkout/build requirement;
- custom-AEMU toolchain adaptation unless later evidence requires it;
- stale Android/PBE package pins;
- experimental graphics variants already rejected;
- assumptions that newest Android/Xcode is automatically best.

---

# 22. Immediate spec blockers — bounded and small

The next product specification does **not** require another massive research campaign. It requires only these bounded preflight answers:

### P1 — Direct official game delivery

Prove one clean Google Play-enabled ARM64 guest can install/update current live TFT through official Google Play and reach Riot login without any third-party package feed.

**Pass:** package installed from Play, package metadata captured, Riot login opens.  
**Fail owner:** guest/Play compatibility only.

### P2 — Working graphics parity on the Play guest

Apply the minimum donor-compatible runtime controls that do not require root and attempt current TFT launch.

**Pass:** real TFT UI launches and stays alive.  
**Fail owner:** identify exact root-owned/profile/graphics requirement before considering a second execution guest.

### P3 — Performance baseline on target M4

Measure one transition and one fixed heavy scene using stock Emulator 37.1.11 + chosen guest.

**Pass:** produces trustworthy FPS/frame-time/stall evidence.  
**Purpose:** determine the actual bottleneck before optimization.

### P4 — Native fullscreen presentation prototype

Demonstrate a fullscreen native macOS presentation route that hides emulator chrome and preserves direct-render performance/input characteristics.

**Pass:** native fullscreen works and does not materially regress direct emulator control.  
**Fail:** keep direct emulator window as temporary control and investigate presentation boundary only.

### P5 — Storage bill of materials

Measure clean runtime + AVD + fully patched TFT + realistic update headroom.

**Pass:** exact product storage budget frozen; no 100+ GB source tree required.

These five answers are enough to write the new implementation spec.

---

# 23. Proposed rebuilt product architecture — provisional until P1–P5

```text
TFTMAC.app (native SwiftUI)
|
|-- Installer / state machine
|-- Settings / profiles
|-- Fullscreen presentation controller
|-- Input bridge
|-- Audio + microphone controller
|-- FPS/frame-time diagnostics
|-- Repair/reset/diagnostics
|-- Signed app updater
|
+--> Official Google Android components
     |
     +--> Stock Android Emulator 37.1.11 control
          |
          +--> Play-enabled ARM64 Android guest
               |
               +--> Google Play
               |    +--> official live TFT package
               |
               +--> Riot patch/auth/game services
               |
               +--> TFT GLES
                    -> ANGLE
                    -> Vulkan
                    -> gfxstream
                    -> MoltenVK
                    -> Metal
                    -> Apple M4
```

No third-party TFT package feed appears in this architecture.

Source-built AEMU is outside the normal box and enters only as a measured repair adapter.

---

# 24. Product win condition for the upcoming spec

The next spec should define “done” as a user product, not a graphics experiment.

At minimum:

1. Install TFTMAC like a normal signed/notarized Mac app.
2. Install the Android runtime without Android Studio or Terminal.
3. Obtain current live TFT from official Google Play/Riot paths.
4. Launch, authenticate, join a party, enter a current live match, and complete it without version mismatch.
5. Present TFT as a native-feeling fullscreen Mac application with emulator chrome hidden.
6. Keep mouse/keyboard/audio stable.
7. Support host microphone transport and truthfully report whether the current game implements voice.
8. Maintain acceptable late-game frame pacing, not just 60 FPS in the lobby.
9. Repair package/runtime damage without unnecessary full resets.
10. Show useful FPS/version/runtime diagnostics in the UI.
11. Update the Mac app independently of Android/game state.
12. Keep product storage bounded and remove giant source-build trees from the normal install.
13. Depend on Google/Riot for authoritative game delivery, not a community-maintained TFT package feed.
14. Preserve user state across app updates.
15. Fail with a specific recovery action rather than an unexplained emulator shutdown.

---

# 25. Preflight decision summary

### Already decided

- Rebuild around the working donor recipe and our existing TFTMAC knowledge.
- Mactician is a donor/reference, not a production dependency.
- MIT launcher/product-shell code may be forked/adapted with required license notice retained.
- Use stock Google Emulator first.
- Direct Google/Riot package/update authority.
- No third-party hosted TFT feed.
- No giant AEMU source tree in the normal product.
- Native SwiftUI Mac application.
- True fullscreen/native-feeling game presentation is required.
- 1080p/60 is the first guaranteed target.
- Heavy-match frame pacing matters more than lobby FPS.
- Installer/Repair/Reset/diagnostics/FPS concepts are required product features.

### Must be proven before final spec freeze

- exact Play-enabled Android guest/version;
- whether root is avoidable for current live TFT;
- exact compatibility mechanism needed for current live renderer;
- target-M4 heavy-scene baseline and bottleneck;
- native fullscreen presentation boundary;
- clean installed storage footprint;
- current TFT microphone/voice capability.

### Explicitly not a blocker anymore

- rebuilding AEMU from source;
- reproducing every historical graphics experiment;
- maintaining a private/community TFT package feed;
- solving every Vulkan/GLES theoretical capability before proving the current game path;
- downloading every Xcode/Android/emulator version.

---

# 26. Source index

Current Mactician source/research used as donor evidence:

- https://github.com/tweet9ra/mactician
- https://github.com/tweet9ra/mactician/blob/master/LICENSE
- https://github.com/tweet9ra/mactician/tree/master/launcher/Sources
- https://github.com/tweet9ra/mactician/blob/master/launcher/Sources/CoreModels.swift
- https://github.com/tweet9ra/mactician/blob/master/launcher/Sources/LauncherModel.swift
- https://github.com/tweet9ra/mactician/blob/master/launcher/Sources/InstallerService.swift
- https://github.com/tweet9ra/mactician/blob/master/launcher/Sources/LauncherSettingsView.swift
- https://github.com/tweet9ra/mactician/blob/master/launcher/Sources/RuntimeController.swift
- https://sergeinaumov.dev/writing/how-i-built-mactician

Current TFTMAC evidence:

- `ssot/host-preflight.json`
- `ssot/STACK.lock.yaml`
- `ssot/TFTMAC_ENGINEERING_MAP.sql`
- `ssot/donors/TFTMAC_DONOR_RESEARCH.sql`
- `docs/TFTMAC_GRAPHICS_ARCHITECTURE.md`
- `artifacts/mactician-live.log`

---

**Preflight state:** READY FOR P1–P5 EXECUTION. The next implementation specification should be written only after these bounded proofs are recorded.
