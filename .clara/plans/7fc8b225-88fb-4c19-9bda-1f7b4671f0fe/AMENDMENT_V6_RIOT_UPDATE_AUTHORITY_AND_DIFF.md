# Amendment V6 — enforce Google Play current-client authority and audit every Riot update

## User scope change
Flash requires TFTMAC DEV to always preserve access to the latest official Riot/TFT update through Google Play and to capture what each update changes. Every client update must produce a complete before/after inventory/diff plus graphics/gameplay comparison so update-driven gains or regressions are visible and never misattributed to TFTMAC tuning.

## New verified trigger
The live DEV guest on 2026-09-11 was running production package `com.riotgames.league.teamfighttactics` `18.1-5423749` / `8423749`, but Android reported `installerPackageName=null`, `initiatingPackageName=com.android.shell`. PBE was not installed or running. Existing project authority already requires `com.android.vending` as install/update authority, so the live shell-owned package is a regression. A newer official client is available through Riot/Google Play. Current `DEV-B8-WIN-01` remains the TFTMAC configuration winner and must survive the client update unchanged.

## Simplest correct mechanism
Use the existing one official API36 Google Play DEV guest and native ADB path. Do not add a second package authority, mirror, private updater, APK patcher, downloader, or hard-coded Riot version.

1. **Pre-launch Play authority gate** in `TFTMACRuntime.swift` before TFT launch/readiness:
   - require production package name only; reject PBE;
   - query `cmd package get-install-source` and require `com.android.vending`;
   - open the official `market://details?id=com.riotgames.league.teamfighttactics` listing through Android/Google Play;
   - inspect the current Play UI tree. If `Update` or `Install` is present, do not emit `TFT_READY_FOR_USER` / matchmaking-ready state. Surface the official Play UI. If Google auth/consent/MFA is required, surface it without reading credentials.
   - only continue to TFT after Play shows Open/Play/no Update and package installer authority is `com.android.vending`.
   - never compare against a permanently hard-coded Riot version; re-observe versionName/versionCode after every update.

2. **Three-phase update audit** for every detected package transition:
   - `PRE_UPDATE`: force-stop TFT; capture package version/code/install source; `pm path` split list; SHA-256/size of every installed APK/split; full per-entry inventory of every readable APK/split archive entry; stopped-app inventory of readable Riot-owned data/content files with path, size and SHA-256; current graphics/runtime fingerprint.
   - `POST_PLAY_UPDATE`: after Google Play delivery completes and before first TFT launch, repeat the exact package + data inventory and graphics/runtime identity snapshot.
   - `POST_RIOT_INIT`: launch the new official client once, allow Riot's own first-launch content initialization/patching to settle, force-stop TFT, then repeat the data/content inventory and graphics/runtime fingerprint.
   - write machine-readable diffs for `PRE_UPDATE -> POST_PLAY_UPDATE`, `POST_PLAY_UPDATE -> POST_RIOT_INIT`, and overall `PRE_UPDATE -> POST_RIOT_INIT`. Every readable file is classified `ADDED`, `REMOVED`, `MODIFIED`, or `UNCHANGED`; changed entries retain old/new size and SHA-256.
   - produce focused changed-native-library and graphics-pipeline summaries from `lib/arm64-v8a`, package/manifest/version metadata, engine markers, GameActivity identity, selected RHI, ANGLE/gfxstream/MoltenVK/Metal receipts, and relevant DeviceProfile/CVar readbacks.
   - retain manifests/diffs under the DEV application-support evidence tree; do not commit Riot binaries into Git.

3. **Performance attribution gate** after a client update:
   - preserve exact `DEV-B8-WIN-01` configuration and frozen Control/LKG;
   - run a matched post-update baseline using the same native stage/workload protocol before resuming CVar tuning;
   - compare new-client baseline to the last valid pre-update client baseline on mean FPS, 1% low, p95/p99/worst interval, jank/severe/missed-vsync and stability;
   - label the delta `RIOT_UPDATE_GAIN`, `RIOT_UPDATE_REGRESSION`, or `RIOT_UPDATE_NEUTRAL/INCONCLUSIVE`; never promote a `DEV-B8-WIN-##` based solely on a Riot client update.

## Immediate remediation
Capture the current shell-owned 18.1 state as `PRE_UPDATE`, then restore official Google Play ownership/currentness through the existing Play Store guest. Do not delete Riot account data unless Google Play itself requires reinstall; prefer official in-place Play update/repair. Verify production package, `com.android.vending` installer, no Play Update button, current observed version, existing Riot login continuity, current OpenGL/ANGLE route, and unchanged WIN-01/LKG/Control integrity.

## Protected boundaries
- `/Applications/TFTMAC.app` Control and frozen LKG remain immutable.
- No PBE package, third-party mirror, re-signing, binary patching, private updater, credential capture or version hard-pin.
- Riot/Google own package/update/authentication. TFTMAC only observes, routes to official UI, verifies authority/currentness, and records evidence.
- A Riot update may change game binaries/assets and therefore invalidates old-client performance comparability until the new matched baseline exists; it does not erase historical telemetry.

## ZenMC qualification
ZENMC_REQUIRED. The update lifecycle has asynchronous Google Play delivery, optional user auth, package-version transition, first-launch Riot content initialization, restart/recovery, partial snapshot/diff persistence and fail-closed readiness. Model must prove no match-ready state without Google Play ownership/currentness; no post-update optimization before all required audit phases and baseline attribution; no PBE acceptance; interrupted update/audit resumes or remains non-ready rather than silently launching stale/unknown state; Control/LKG are never mutated.

## Acceptance
- ZenMC V6: 100,000 trajectories, zero safety violations.
- Source validation passes.
- Current live DEV package becomes Google Play-owned and Play-current while preserving user Riot session when possible.
- A complete three-phase audit/diff exists for this update and records every readable changed file.
- Post-update graphics/runtime fingerprint is compared to pre-update evidence.
- A matched post-update gameplay baseline is recorded before CVar gain-search resumes.
- Future DEV launch cannot silently reach ready/matchmaking on a shell-owned package or when Play exposes Update/Install.
