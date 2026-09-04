# TFTMAC DEV Login-Friction Repair — Implementation Plan

**Change:** `bddd2d6c-a2ed-46fb-9e9e-6674bfdf3541`  
**Base:** `c050c98ec9bd93501c2ce5e0f8583129946b61ab`  
**Request class:** IMPLEMENT_SHIP  
**Target:** `/Applications/TFTMAC DEV.app` only  

## Outcome

Make DEV behave like a production launcher:

```text
launch DEV
-> no macOS Keychain authorization sheet
-> splash / Android boot continues normally
-> TFT opens
-> if Riot login is needed, first unstable MobileFRE instance is recycled automatically
-> user sees only the stable Riot login page
-> user authenticates once in Riot's official UI
-> Riot's own Android session persists in DEV userdata
-> later launches go directly to TFT while that session remains valid
```

TFTMAC never stores Riot credentials.

## Phase 1 — Isolate DEV Android-PIN Keychain storage

Modify `TFTMACGuestUnlockSecretStore` to select a service by runtime mode:

- Control: keep `com.flashls1.tftmac.android-unlock.v2` exactly unchanged.
- DEV: use `com.flashls1.tftmac.dev.android-unlock.v1`.
- Candidate: no new behavior until candidate is built/accepted.

Pass the selected runtime mode from `AppCoordinator` into `loadOrPrompt`.

Do not migrate/read the old shared item automatically. On the first repaired DEV launch, absence of the DEV item opens TFTMAC's existing secure Android-PIN setup dialog once and creates the DEV-owned item. This avoids another macOS SecurityAgent authorization request against Control's ACL.

Add tests proving Control and DEV namespaces differ and the Control service remains frozen.

## Phase 2 — Add bounded Riot login stabilization state

Add a small runtime state machine for official TFT in `advanced_diagnostics` only:

```text
notObserved
-> firstLoginObserved
-> recycling
-> stableLoginReady
```

Rules:

1. Trigger only when `GameFrameTelemetryStatus == .unavailable(.loginPromptActive)`.
2. Run at most once per DEV app session.
3. Immediately block user touch/mouse/keyboard forwarding while recycling.
4. Reassert `settings put secure show_ime_with_hard_keyboard 0`.
5. Record only non-secret telemetry.
6. `am force-stop com.riotgames.league.teamfighttactics`.
7. Wait for the old PID to disappear.
8. Relaunch the official resolved/Splash/Game component using the existing official-package launch helper semantics.
9. Require a new TFT PID and a newly active `MobileFREWebViewActivity` before unblocking input.
10. No loop: if the bounded recovery cannot reach a stable replacement, keep input blocked and raise a native/runtime error instead of repeatedly killing the package.

This reproduces the exact successful runtime transition already observed after the user's Android `Close app`, but performs it before Android reaches the ANR dialog.

## Phase 3 — Keep login stabilization invisible/controlled

The existing startup curtain is one-way after TFT is first revealed. Do not repurpose it into a recurrent activity mask.

Instead, add a bounded input gate in the runtime/coordinator path:

- while Riot stabilization is active, ignore emulator user input and present a small native `Signing in…`/`Preparing Riot login…` overlay if needed;
- after the replacement login activity is proven, remove the gate and restore normal input;
- if the user is already authenticated and no Riot login appears, this path is never entered.

No Android ANR dialog should become actionable to the user.

## Phase 4 — Preserve Riot's own authenticated session

Do **not** add a Riot password vault or credential checkbox to TFTMAC.

Persistence authority is the official TFT Android app's own private userdata/WebView/session state. Keep all of the following unchanged:

- persistent DEV AVD;
- no `pm clear`;
- no `-wipe-data`;
- no package reinstall on launch;
- no token/cookie inspection.

When a Riot login activity transitions back to GameActivity in the replacement process, record a non-secret `RIOT_LOGIN_COMPLETED` marker and issue a bounded guest filesystem `sync` after a short settle period. On normal DEV shutdown, issue `sync` before the existing TFT force-stop/emulator clean-shutdown sequence. This improves durability without reading any credential/session content.

If Riot later expires the session, the official login page may legitimately return and the user authenticates manually.

## Phase 5 — Telemetry

Allowed new events:

- `DEV_UNLOCK_KEYCHAIN_NAMESPACE_SELECTED`
- `RIOT_LOGIN_STABILIZATION_STARTED`
- `RIOT_LOGIN_PROCESS_RECYCLED`
- `RIOT_LOGIN_STABLE`
- `RIOT_LOGIN_STABILIZATION_FAILED`
- `RIOT_LOGIN_COMPLETED`
- `RIOT_SESSION_STATE_SYNC_REQUESTED`

Never log typed characters, username, password, MFA, cookies, tokens, page contents, or screenshots.

## Phase 6 — Tests

Add unit tests for:

1. Control keychain service frozen at v2.
2. DEV keychain service distinct and stable.
3. first login prompt enters recovery once;
4. recovery blocks input;
5. second login observation marks stable without a second recycle;
6. replacement PID must differ from original;
7. recovery timeout fails closed and never loops;
8. authenticated GameActivity path never invokes recovery;
9. session-expired later login can use one new recovery on a new app session;
10. no credential values enter telemetry payloads.

Keep all existing splash/startup tests green.

## Phase 7 — Source acceptance

Run `scripts/verify-tftmac.command` and focused new tests. Update only stale test-count/authority hashes directly caused by this change.

## Phase 8 — DEV build/install acceptance

Use `scripts/build-dev-launcher.command`; install only `/Applications/TFTMAC DEV.app`.

Before and after install verify:

```text
/Applications/TFTMAC.app/Contents/MacOS/TFTMAC
SHA-256 = d3bf7c249a3e5f11b81f778b063e1a8cfe2e7fdeec0537ee6bd8447b1c2268d2
```

## Phase 9 — Live acceptance

### Keychain

First repaired DEV launch may ask once for the Android PIN inside TFTMAC's own secure dialog. It must not require the Mac login/Apple password. Close and relaunch DEV twice; both subsequent launches must retrieve the DEV PIN noninteractively.

### Riot ANR

If Riot login is required:

- first MobileFRE activity may be detected internally;
- input is gated;
- TFT process is recycled exactly once;
- replacement login activity becomes stable;
- user can click username immediately;
- no Android Wait/Close dialog is shown or required.

### Riot session persistence

After the user completes one official Riot login:

1. observe return to GameActivity;
2. sync guest state;
3. cleanly close DEV;
4. relaunch DEV;
5. if Riot's session is still valid, no credentials are requested and TFT reaches GameActivity directly.

If Riot itself requires MFA/re-authentication, that is an external authentication boundary, not a TFTMAC failure.

## Rollback

Revert this managed change and reinstall the previous DEV build. No Control, Riot APK, or AVD data migration is performed.
