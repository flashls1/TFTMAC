# Changelog

## Unreleased

### DEV test ledger — 2026-09-10 results-first pass

This section is the running test/version ledger for the current TFTMAC DEV optimization line. Preserve the installed/frozen DEV build identity separately from experiment outcomes: a test result does **not** silently change the app release version. Each new experiment should append its exact delta, workload, outcome, measured evidence, integration decision, reasoning, and rollback state so completed work is not rediscovered or repeated.

**Current test authority**

- DEV application release identity: **TFTMAC 2.3.0 (build 8)**. Test-ledger identifiers below do not change this release identity.
- Test series identity: `DEV-B8-2026-09-10-A` — Results-First optimization pass for this exact Build 8 line.
- Client scope: official live `com.riotgames.league.teamfighttactics` `18.1-5423749` (`versionCode 8423749`).
- Runtime: `/Applications/TFTMAC DEV.app`, advanced diagnostics / StockShadow.
- Fixed comparison geometry: `1920x1080`, `320 DPI`, `60 Hz`, `8 vCPU`, `6144 MiB`, host GPU, OpenGL/ANGLE.
- ANGLE revision: `1166eec4c0b125e9e945196acfc549983ef72b18`.
- Accepted AVD baseline SHA-256: `b8cccc257dcc114ae5e6d24149514b7149b7e60a580fb74f79ca343823c28125`.
- Test protocol: one hypothesis at a time; record `WIN`, `NO WIN`, or `INCONCLUSIVE`; keep proven wins; restore baseline after failures; do not create extra infrastructure merely to explain a loser.
- Standing versioning policy: preserve the frozen LKG separately and never rewrite it to match the current experiment winner. Improvements advance the DEV working configuration version-by-version; each verified improvement becomes the next working winner, each failed or inconclusive test remains logged with its reason, and testing continues forward from the latest proven winner. Historical controls remain available for comparison and rollback.

#### Baseline — CONTROL_GREEN

**Outcome:** `PASS / HISTORICAL CONTROL`  
**Integration:** keep as immutable comparison evidence; do not overwrite it when a later setting wins.

- Current official TFT client, `1920x1080`, 8 vCPU, 6144 MiB, OpenGL/ANGLE.
- Original LKG cache properties included `debug.egl.blobcache.multifile=true`, `debug.angle.feature_overrides_disabled=preferSubmitAtFBOBoundary`, and `syncMonolithicPipelinesToBlobCache` in the enabled ANGLE feature list.
- Native authoritative combat windows: 1-1 = **48.83 FPS**; 1-2 = **53.65 / 44.57 / 53.61 FPS**.
- Normal shutdown and exact AVD restoration passed.

#### P1 — Buffer-view retention / `dev-observed-reuse-cache-r14`

**Outcome:** `NO WIN`  
**Integration:** `NO` — do not promote; do not build more split-reason infrastructure during the fast-pass.

- Candidate loaded and executed against the real official client.
- `retainedBindings=0`, `retainedSyncs=0`, `unchanged=0`.
- Real-match mean: **57.21 FPS**; **106/147** windows were below 60 FPS.
- Continuous-60 target failed and the intended retention mechanism never activated.
- Reasoning: the candidate did not provide the optimization it was designed to provide. Preserve the evidence for later factor isolation only if this family is explicitly reopened.

#### WIN-01 / P2 — Cache / remove `syncMonolithicPipelinesToBlobCache`

**Test configuration identity:** `DEV-B8-WIN-01`  
**Outcome:** `VERIFIED WIN`  
**Integration:** `YES — RETAIN AS WORKING CACHE WINNER`.

**Exact delta**

- Keep `debug.egl.blobcache.multifile=true`.
- Keep `debug.angle.feature_overrides_disabled=preferSubmitAtFBOBoundary`.
- Keep the normal expose feature support.
- **Remove only `syncMonolithicPipelinesToBlobCache` from `debug.angle.feature_overrides_enabled`.**

**First valid current-client comparison**

- 1-1: **48.78 FPS vs 48.83 CONTROL** — effectively neutral; p95 **23.10 ms vs 20.55 ms**.
- 1-2, three-window mean: **55.68 FPS vs 50.61 CONTROL (+10.0%)**.
- 1-2 mean p95: **20.59 ms vs 23.39 ms (-11.9%)**.
- 1-2 mean p99: **27.12 ms vs 31.29 ms (-13.3%)**.
- One candidate window contained a 70.38 ms maximum interval, so the first run was treated as provisional rather than immediately promoted.

**Confirmation / later-stage evidence**

- Confirmation resumed at later Trials progress and reached 1-3/1-4/1-5 cleanly; the early-stage measurement gate was missed, but the native telemetry remained valid.
- Same-stage 1-4 comparison: **54.48 FPS vs 52.07 CONTROL (+4.6%)**.
- 1-4 p95: **22.41 ms vs 30.33 ms (-26.1%)**.
- 1-4 p99: **29.27 ms vs 37.47 ms (-21.9%)**.
- 1-4 severe intervals: **0 vs 3**.

**Exact 30-window 1-5 head-to-head**

- Mean FPS: **54.92 vs 55.73 CONTROL (-1.5%)**.
- Median FPS: **55.35 vs 57.56 CONTROL (-3.8%)**.
- Mean p95: **19.72 ms vs 23.45 ms — 15.9% better**.
- Mean p99: **27.21 ms vs 33.74 ms — 19.4% better**.
- Jank per window: **67.9% lower**.
- Missed-vsync per window: **70.3% lower**.
- Severe intervals: **1 vs 7**.
- Worst interval: **57.88 ms vs 100.09 ms — 42.2% better**.

**Decision reasoning**

This is a verified **frame-pacing / tail-latency win**, not a claim that mean FPS increases at every stage. The setting materially reduces stalls, missed presentation work, jank, severe intervals, p95/p99 latency and worst-frame behavior while keeping average FPS broadly comparable. Earlier 1-2 and 1-4 samples also showed higher mean FPS. The combination is therefore a better gameplay configuration and is retained as the working cache winner.

**Verification / rollback**

- Both candidate and matched control verified official client `18.1-5423749`, 1920x1080, 8 vCPU, 6144 MiB and OpenGL/ANGLE.
- Exact requested properties were read back before TFT startup.
- Candidate and matched-control cleanup restored the exact AVD baseline.
- Installed DEV/LKG integrity passed.
- No profiler, unbounded trace, VM, runtime copy or new app build was used.
- After verification, no TFT runtime, `xctrace`, Instruments or orphaned `DTServiceHub` process remained active.

#### P3 — Direct Vulkan

**Outcome:** `NO WIN`  
**Integration:** `NO` — preserve the OpenGL/ANGLE working route.

- A bounded canary using the LKG plus only the Vulkan RHI delta was attempted; the lab-side overlay attempt was inconclusive because post-launch ADB root did not become effective, and rollback passed.
- Existing DEVHighPerf authority already contains the decisive behavior: removing the Vulkan-disable flag selected direct Vulkan, then Trials loading produced Metal vertex-descriptor / missing-attribute failures.
- Reasoning: direct Vulkan is not a fast win on this build and would require a separate compatibility repair effort. Do not open that repair loop during this pass.

#### Follow-up — Queue Submit Inline / `-VulkanQueueSubmitWithCommands`

**Outcome:** `NO WIN / BOOT-INCOMPATIBLE`  
**Integration:** `NO`.

- Prior official-client attempt had boot-failed under low-storage conditions, so the same existing one-setting DEV preset was retested once with adequate storage.
- Native telemetry sealed `queue_submit_inline` against workload `official_tft` with exactly one emulator-feature override: `-VulkanQueueSubmitWithCommands`.
- Emulator/ADB again failed to reach readiness; no FPS result was fabricated.
- Exact AVD restoration, DEV/emulator shutdown and installed app/LKG integrity passed.
- Reasoning: the failure reproduced without the earlier storage confounder, so treat the setting as boot-incompatible for this fast-pass and do not start a repair loop.

#### Existing completed transport results — do not rerun in this pass

- `virtual-queue-off`: `NO WIN / REJECTED_BELOW_60`. Prior official-client run reached combat but produced repeated 40–59 FPS windows and severe stalls.
- `fence-contexts-off`: `NO WIN / REJECTED_BELOW_60`. Prior official-client run reached combat and remained below the continuous-60 requirement with severe stalls.
- ASG draw flush `400 µs`: historical/experimental evidence already exists and current authority says not to recycle it as a new result; retain `800 µs` for this pass.
- Inverse `preferSubmitAtFBOBoundary` test: `INCONCLUSIVE / NOT ACTUALLY APPLIED`. The installed DEV correctly reapplied the LKG disabled-feature property before TFT, so no performance conclusion was drawn and no new override mechanism was built.

#### Current working test configuration after verified wins

**Working test profile:** `DEV-B8-WIN-01` — first verified optimization winner layered on TFTMAC 2.3.0 build 8. Future verified wins should receive the next `DEV-B8-WIN-##` ledger identity while the app release stays 2.3.0 build 8 unless the product itself is intentionally versioned.

- `debug.egl.blobcache.multifile=true`
- `debug.angle.feature_overrides_enabled=exposeNonConformant*:exposeES32ForTesting`
- `debug.angle.feature_overrides_disabled=preferSubmitAtFBOBoundary`
- OpenGL/ANGLE remains the selected game RHI.
- 1920x1080 / 320 DPI / 60 Hz / 8 vCPU / 6144 MiB remain fixed.
- Historical LKG with global sync remains preserved as the matched control, but **global monolithic pipeline sync is no longer part of the preferred working test configuration**.

**Current scoreboard:** one verified fast win — `cache-no-global-sync`; buffer retention, direct Vulkan, queue-submit-inline, virtual-queue-off and fence-contexts-off are not promoted.

### Documentation

- Reconciled current Build 8 runtime, automatic-logging, and graphics-causality
  status across the human-readable project record.
- Recorded the latest 42m27s automatic graphics capture as performance evidence
  while retaining internal attribution as unknown.
- Added the sanitized two-game capture review for the Sep 7 and Sep 8 long TFT
  sessions, including frame-window tails, presenter repeats, host timings, and
  the remaining causal-coverage gaps.
- Added the evidence-gated fast-wins 60 FPS plan, starting with the existing
  prebuilt ANGLE view-reuse candidate and defining the immediate decision test.
- Recorded the first fast-wins experiment in
  `docs/receipts/2026-09-08-fast-wins-r1/angle-reuse-gate.md`: the candidate
  ANGLE files were mapped by TFT, but the run failed the surface/ready
  lifecycle gate before gameplay and produced no FPS evidence.
- Recorded the stock DEV lifecycle comparator in
  `docs/receipts/2026-09-08-fast-wins-r1/stock-dev-lifecycle-comparator.md`:
  stock reached `TFT_READY_FOR_USER` and sealed cleanly, so the first failure
  is candidate-specific or a candidate/path interaction; no gameplay FPS
  conclusion is made.
- Archived obsolete launch/profile/source-build entrypoints under
  `docs/history/2026-08-31-pre-build8/` and replaced them with current pointers.

### Changed

- Split repository/CI verification from the local-only installed-runtime and
  signing audit; CI no longer depends on `/Applications`, an external runtime,
  a private signing identity, credentials, or captures.
- Updated GitHub checkout to `actions/checkout@v7.0.1` while retaining Node 24.
- Reconciled machine-readable runtime, retained-evidence, engineering-map, and
  performance-lab authority around stock Build 8 and the planned isolated
  causal logger.
- Separated historical Build 8 signing acceptance from the current-host
  `CSSMERR_TP_NOT_TRUSTED` audit and its missing login-keychain identity.
- Established TFTMAC as the sole product and repository identity.
- Replaced legacy validation with the native TFTMAC build/test verifier.
- Preserved the proven native AppKit/Metal Gate 1 implementation and frozen installed EmulatorController protocol.
- Removed obsolete launcher, hosted update/feed, helper-host, and branding layers.
- Moved runtime authority to the stock Google Android Emulator and official Google Play TFT lifecycle.
- Began relational migration of retained performance evidence to TFTMAC-owned identifiers.
- Retired source-built emulator work from the normal product path.

### Current target

- Native macOS application bundle: `com.flashls1.tftmac`.
- Stock Android Emulator 37.1.11.
- Official Google Play package `com.riotgames.league.teamfighttactics`.
- 1920x1080 / 60 Hz target on Apple Silicon.
