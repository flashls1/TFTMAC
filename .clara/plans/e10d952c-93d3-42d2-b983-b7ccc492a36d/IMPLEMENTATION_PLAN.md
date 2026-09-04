---
title: TFTMAC Production Startup Curtain — Implementation Plan
plan_version: 1.0
date_local: 2026-09-04
project: TFTMAC
change_id: e10d952c-93d3-42d2-b983-b7ccc492a36d
request_class: PLAN
implementation_status: READY_AFTER_ZENGATE
base_master_sha: 74c74c48e75db9dc04e105d8e6f2574002fb787d
plan_change_head_sha: 1e544845352547093d600a0e00fdfd1dac3fa88b
asset_sha256: 588258b9bdc1d602e33eeef20209901d1d9acb763817ee5a70bee3a5c911b879
---

# TFTMAC Production Startup Curtain

## 0. User outcome

When the user launches TFTMAC, the first visible application content must be the approved TFTMAC splash artwork. Android/emulator boot, gray/black frames, Android home/SystemUI, PIN/unlock, and other startup implementation details continue normally behind the curtain but are never shown to the user. The curtain leaves only after official TFT/Riot content is safe to interact with and a fresh source frame from that post-eligibility state has successfully reached the native Mac presenter.

Normal success path:

```text
launch TFTMAC
-> native window appears already covered by TFTMAC splash
-> emulator/controller/ADB/unlock/TFT launch continue underneath
-> exact TFT GameActivity SurfaceView becomes available
-> capture current source-frame sequence as eligibility baseline
-> a later source frame successfully completes native Metal presentation
-> 250 ms native fade
-> curtain removed
-> EmbeddedEmulatorView becomes first responder
-> user sees TFT
```

Manual-login exception:

```text
active Riot MobileFREWebViewActivity
-> capture eligibility baseline
-> wait for newer successfully presented source frame
-> reveal so the user can authenticate in official Riot UI
```

There is no timeout that reveals Android/SystemUI/PIN.

## 1. Current architecture and why the artifact belongs here

Current AppKit launch order is already compatible with this feature:

- `AppCoordinator.applicationDidFinishLaunching` creates `MainWindowController`, calls `showWindow(nil)`, activates the app, then resolves runtime configuration and starts `TFTMACRuntimeController`.
- `MainWindowController` currently makes `EmbeddedEmulatorView` the whole `NSWindow.contentView`.
- `EmbeddedEmulatorView` begins consuming controller frames as soon as they arrive.
- Existing `gameFrame` callback already feeds `GameFrameTelemetryWindow` into the view.
- `GameFrameTelemetry` already identifies the exact TFT Unreal `GameActivity` BLAST SurfaceView and active Riot `MobileFREWebViewActivity`.
- The approved FTS splash asset already exists on this managed change.

The implementation therefore adds one bounded native presentation layer; it does not alter the Android runtime.

## 2. Scope and invariants

1. **First-visible-frame:** no underlying `EmbeddedEmulatorView` content may become visible before the startup curtain is installed.
2. **No-Android-reveal:** Android/SystemUI/PIN frames cannot reveal the curtain.
3. **Fresh-frame:** eligibility alone is insufficient; a source sequence newer than the eligibility baseline must successfully complete host presentation.
4. **Input:** emulator touch/mouse/keyboard forwarding is unavailable while the curtain is active.
5. **Failure:** pre-reveal failure leaves the curtain visible and shows a native error on top.
6. **One-way:** once revealed, the startup curtain never returns in the same app session.
7. **Manual-auth:** active official Riot login may reveal only after the same fresh-frame proof, because project authority requires credentials/MFA/consent to remain manual.
8. **No-timeout:** elapsed time may change native copy but may never expose Android.
9. **Runtime-noninterference:** no AVD, emulator, controller, renderer, graphics, PIN, or package behavior changes are part of this feature.
10. **Diagnostic-noninterference:** consumer curtain logic applies to `officialTFT`; owned diagnostic probe behavior remains available.

## 3. Minimal state model

Implement a pure state reducer independent of AppKit:

```swift
enum StartupCurtainState {
    case covered
    case eligible(reason: Eligibility, baselineSequence: UInt32?)
    case revealed
    case failed(message: String)
}

enum StartupCurtainEligibility {
    case tftGameActivity
    case riotLogin
}
```

Inputs are semantic events, not raw timers:

```swift
.runtimeConfigured(workload)
.gameFrameStatus(GameFrameTelemetryStatus)
.sourceFramePresented(sequence)
.runtimeFailed(message)
```

Rules:

- startup begins `covered`;
- `.available` GameFrameTelemetry while official TFT is active => `eligible(.tftGameActivity, baseline=currentPresentedSequence)`;
- `.loginPromptActive` => `eligible(.riotLogin, baseline=currentPresentedSequence)`;
- if an eligible activity disappears before a qualifying fresh presentation, return to `covered`;
- only `sourceFramePresented(sequence > baseline)` may move eligible -> revealed;
- runtime error before reveal -> failed;
- revealed and failed are terminal with respect to curtain visibility;
- timers never move covered/eligible to revealed.

The reducer is the source of truth. Views render the reducer state; callbacks do not manipulate alpha/visibility independently.

## 4. Phase 1 — Bundle the approved image

Files:
- `tftmac/Assets/TFTMAC-Splash-1920x1080.png`
- `TFTMAC.xcodeproj/project.pbxproj`

Actions:
1. Verify the current FTS asset SHA remains `588258b9bdc1d602e33eeef20209901d1d9acb763817ee5a70bee3a5c911b879`.
2. Verify actual pixel dimensions before bundling.
3. If not exactly 1920×1080, perform one deterministic high-quality size normalization that preserves the approved artwork/content and record old/new SHA-256. No redesign or re-generation is authorized.
4. Add the PNG to the TFTMAC target Resources build phase.
5. Add a build/resource assertion proving the compiled app bundle contains the image and `NSImage` can load it.

Gate 1: built bundle contains one loadable splash resource with expected identity and no unrelated resource changes.

## 5. Phase 2 — Native curtain view

Create `tftmac/Presentation/StartupSplashView.swift`.

Responsibilities only:
- draw the splash image aspect-fill across current bounds;
- remain opaque so gray/black/Android content cannot leak through;
- handle fullscreen/window resize without exposing underlying content;
- capture pointer input while visible;
- accept first responder while visible so keyboard input does not reach Android;
- optionally draw a native error panel when state is `.failed`;
- expose no emulator/runtime logic.

Do not create a second `NSWindow`; keep the feature in the main hierarchy to avoid ordering/fullscreen races.

## 6. Phase 3 — Main-window composition

Refactor `MainWindowController` to:

```text
NSWindow
└── root container
    ├── EmbeddedEmulatorView
    └── StartupSplashView
```

Requirements:
- create both views before `showWindow(nil)`;
- pin both to all four edges;
- keep splash above emulator view;
- start splash visible at alpha 1;
- `focusStartupCurtain()` before runtime start;
- `revealStartupCurtain()` performs one 250 ms fade, hides/removes splash after animation completion, and moves first responder to `EmbeddedEmulatorView`;
- reveal is idempotent.

## 7. Phase 4 — Fresh host-presentation proof

`EmbeddedEmulatorView` is the correct place to prove a frame actually reached the native presenter.

Add the smallest explicit signal, for example:

```swift
var onSourceFramePresented: ((UInt32) -> Void)?
var latestSuccessfullyPresentedSourceSequence: UInt32? { get }
```

Semantics:
- signal only after a command buffer successfully completes;
- signal refers to the source sequence actually sampled for that presentation;
- repeated presentations of an old source must not satisfy a “new frame after eligibility” test;
- marshal callback to the main actor;
- do not change frame acquisition, mailbox behavior, texture upload, Metal timing, or presentation cadence.

## 8. Phase 5 — Coordinator wiring

`AppCoordinator` owns startup UX state because it already connects runtime callbacks to the window.

Launch:
1. Create `MainWindowController` with splash already installed.
2. Show window.
3. Focus splash, not emulator view.
4. Resolve runtime configuration.
5. If workload is not `officialTFT`, disable consumer curtain and preserve diagnostic behavior.
6. Start runtime normally.

Existing `gameFrame` callback:
- pass window to `EmbeddedEmulatorView` exactly as today;
- feed status into pure startup reducer;
- `.available` is normal TFT eligibility;
- `.loginPromptActive` is manual Riot-login exception;
- no other unavailable status may reveal.

`onSourceFramePresented`:
- feed sequence into reducer;
- if reducer becomes `.revealed`, perform one-time fade/focus transfer.

Existing status/error callback:
- non-error status remains telemetry-only;
- pre-reveal error => reducer `.failed` and native error on splash;
- post-reveal error => preserve current `EmbeddedEmulatorView.setStatus` behavior;
- no new retry flow in this scope.

## 9. Phase 6 — Unit tests

Add `Tests/TFTMACTests/StartupCurtainStateTests.swift`.

Mandatory cases:
1. cold-boot Android frames do not reveal;
2. elapsed time does not reveal;
3. GameActivity eligibility + stale/same sequence does not reveal;
4. GameActivity eligibility + newer completed source sequence reveals;
5. GameActivity lost before fresh frame returns to covered;
6. active Riot login + stale sequence does not reveal;
7. active Riot login + newer completed sequence reveals;
8. runtime error before reveal becomes failed and remains covered;
9. no event can re-cover after reveal;
10. no event can recover failed startup into exposed Android content;
11. owned probe workload bypasses consumer curtain without changing official-TFT semantics;
12. reveal is idempotent.

Add resource/build assertions for splash resource and new source/test target membership.

## 10. Phase 7 — Source acceptance

Run `./scripts/verify-tftmac.command`.

Required:
- all existing native tests pass;
- all new curtain tests pass;
- Xcode build path used by verifier remains healthy;
- `git diff --check` passes;
- no unrelated source/runtime files changed.

A stale test/document expectation caused directly by this approved hierarchy/resource change is an IN_SCOPE DETAIL; unrelated failures remain deferred.

## 11. Phase 8 — Live startup acceptance

After source acceptance, perform a bounded official-TFT launch.

Visual win condition from first visible window until reveal:

VISIBLE:
- only approved TFTMAC splash artwork;
- native error only if startup fails.

NEVER VISIBLE:
- initial dark/gray renderer state;
- Android boot/default/home screen;
- Android PIN/unlock UI;
- internal ADB/controller status;
- stale pre-TFT emulator frame.

Normal success:
`splash -> exact GameActivity available -> newer source frame completes native presentation -> ~250 ms fade -> TFT visible and interactive`.

Functional acceptance:
- Android boot/unlock/TFT launch still complete behind curtain;
- official TFT package and GameActivity unchanged;
- audio unaffected;
- input blocked before reveal and works immediately after;
- fullscreen transition does not flash Android;
- app close/stop cleanup unchanged;
- no second Android polling loop;
- no meaningful presenter FPS regression.

Manual Riot login acceptance:
- startup noise stays hidden;
- active Riot login becomes eligible;
- fresh presentation proof occurs;
- curtain reveals;
- user can enter credentials/MFA/consent manually;
- curtain does not reappear after login/GameActivity transition.

## 12. Failure acceptance

Before reveal:
- runtime identity/ADB/controller/unlock/TFT launch failure keeps splash visible;
- error is presented natively on splash;
- Android remains hidden;
- no timeout forces reveal.

After reveal:
- existing runtime error presentation remains authoritative;
- curtain does not return.

## 13. Telemetry

Only bounded startup UX events if needed:
- `STARTUP_CURTAIN_SHOWN`
- `STARTUP_CURTAIN_ELIGIBLE`
- `STARTUP_CURTAIN_REVEALED`
- `STARTUP_CURTAIN_FAILED`

Payload may include eligibility reason, monotonic elapsed ms, baseline/revealed source sequence, runtime mode/workload. Never record credentials, PIN, typed content, screenshots, or Riot account data.

## 14. Rollback

Entirely host-source/UI scoped. Revert this managed change/PR to restore current behavior. No AVD, guest, package, runtime, or user-data migration exists.

## 15. Implementation order

1. resource identity/bundle integration;
2. pure state reducer + unit tests;
3. StartupSplashView;
4. MainWindowController container;
5. host-presented-source callback;
6. AppCoordinator wiring;
7. focused tests;
8. full verifier;
9. bounded live official-TFT startup acceptance;
10. exact diff review against scope lock;
11. publish/deliver only if separately requested by the implementation completion layer.

## 16. Definition of done

- first visible app content is approved splash;
- Android boot/default/PIN never exposed;
- GameActivity normal path requires fresh successful host presentation;
- Riot login exception remains usable/manual;
- no timeout exposes Android;
- input cannot leak through splash;
- pre-reveal failure remains covered/user-readable;
- reveal is one-way/idempotent;
- fullscreen transition is clean;
- existing runtime behavior/graphics path unchanged;
- all tests/verifier pass;
- one live launch proves user-visible sequence end to end.
