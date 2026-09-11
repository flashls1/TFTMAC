# Changelog

## Unreleased

### Riot/Google Play package-authority regression discovered — 2026-09-11

- Live DEV audit found the production package `com.riotgames.league.teamfighttactics` at `18.1-5423749` / `8423749`, but package install source was `installer=null`, `initiatingPackageName=com.android.shell` rather than `com.android.vending`.
- PBE was explicitly absent; the foreground process/activity was the production Riot package, so the defect is stale/update ownership, not wrong-server/PBE selection.
- A newer official Riot/Google Play client was available. The existing project contract already required Google Play ownership, so the live shell-owned state is a regression and the old client is not valid as the continuing matchmaking/performance authority.
- New mandatory rule: each client update captures `PRE_UPDATE`, `POST_PLAY_UPDATE`, and `POST_RIOT_INIT` inventories, complete readable-file before/after diffs, package/split hashes, engine/native-library/graphics-pipeline identity changes, and a matched gameplay baseline before optimization resumes.
- `DEV-B8-WIN-01` remains the TFTMAC configuration winner; client-update remediation must preserve it and must not mutate protected Control/LKG.

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
- Promotion rule: **VERIFIED REPEATABLE NET IMPROVEMENT = integrate and keep; NOT VERIFIED / INCONCLUSIVE / REGRESSION = log, do not integrate, restore the latest verified winner, and move to the next test.** There is no fixed positive-gain percentage floor. A candidate does not need to reach 60 FPS or improve every metric. Small regressions in secondary metrics are acceptable when the overall gameplay/system result is better and there is no correctness, stability, compatibility, or severe-tail regression that outweighs the gain.
- Evaluation weighting: FPS remains a heavily weighted metric but is not the sole optimization target. Frame pacing, p95/p99/worst-frame latency, jank, missed-vsync behavior, CPU/RHI efficiency, memory behavior, allocation/churn, stalls, stability, input responsiveness, and other measured system costs may establish a verified net win even when mean FPS is flat or slightly lower.
- Compounding rule: every new candidate is tested on top of the latest verified working winner, not repeatedly against the untouched LKG. Continuous useful 60 FPS is the ultimate target, while each experiment asks only whether the tested delta produces a repeatable net improvement. Retain small proven wins so later changes can compound with them. A multiplicative/synergistic benefit is a hypothesis to verify, never an assumption; each combined working version must still pass its own bounded acceptance comparison before promotion.
- Mandatory synchronized record-book rule: after every completed DEV optimization test, update this ledger before starting the next candidate. Also update `project.md` whenever current winner/configuration/test state changes, and update `facts.md` whenever the result changes a current hard fact, mandatory rule, runtime/client identity, protected boundary, or authoritative configuration. The record books must describe the current state before another test begins.

#### Optimization goal doctrine — 2026-09-11

**Outcome:** `CUMULATIVE SMALL-GAINS STRATEGY ADOPTED`

- Continuous useful 60 FPS remains the ultimate target, but no individual candidate must independently reach 60 FPS.
- The prior executable +5% weighted-FPS floor conflicted with the cumulative strategy because it could discard legitimate small gains before they had a chance to compound.
- Small valid improvements are now eligible for `PROMISING`, must pass confirmation, and become the next `DEV-B8-WIN-##` only when the net improvement is repeatable and free of material correctness/stability/compatibility/tail regressions.
- Neutral, invalid, or losing candidates are logged and rolled back; the pass then moves to the next research-exposed setting rather than expanding into speculative infrastructure.
- `HOME_RUN` remains a useful label for unusually large/broad wins; it is not the only kind of improvement worth retaining.

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

#### Valid one-factor impact retest — 2026-09-11

**Campaign:** `incremental-20260911T203403Z-cc03b671`  
**Outcome:** `NO NEW WINNER / WIN-01 PRESERVED`  
**Integration:** `NONE` — every non-winning candidate was rolled back to `DEV-B8-WIN-01`; installed DEV integrity, frozen LKG integrity, codesign, AVD restoration, profile restoration and runtime cleanup passed.

This is the first pass after repairing the DEV-only profile transaction far enough to obtain real candidate CVar execution and matched native 1-5 combat evidence. It resolves the earlier infrastructure-only uncertainty without changing the protected Control or frozen LKG.

- **`r.pso.PrecompileThreadPoolSize 4 -> 2` — `NO WIN / REJECTED`.** Matched control: 57.617 FPS, 39.594 1% low, 18.989 ms p95, 25.966 ms p99, 0.00529 jank rate. Candidate: 50.120 FPS, 22.838 1% low, 31.828 ms p95, 49.588 ms p99, 0.19461 jank rate. Delta: **-13.01% mean FPS, -42.32% 1% low, +67.61% p95 interval, +90.97% p99 interval**, with severe intervals introduced. Candidate CVar effectiveness was proven and rollback passed. Do not recycle this value in the current pass.
- **`r.ShaderPipelineCache.BackgroundBatchSize 20 -> 4` — `INCONCLUSIVE / NOT INTEGRATED`.** The matched control was valid. Candidate startup proved the profile transaction/rollback path, but the official client remained on the Riot credential screen for the bounded login window and ended `AUTH_BLOCKED` before 1-5 measurement. This is **not** a performance rejection; one clean retest remains warranted before this candidate is retired.
- **`a.Budget.BudgetMs 6.0 -> 5.0` — `NO WIN / REJECTED`.** Matched control: 57.895 FPS, 29.661 1% low, 23.011 ms p95, 33.627 ms p99, 0.03099 jank rate, 0.00563 severe rate. Candidate: 52.873 FPS, 37.954 1% low, 19.612 ms p95, 26.097 ms p99, 0.01326 jank rate, zero severe intervals. The candidate materially improved tails (**+27.96% 1% low, -14.77% p95, -22.39% p99**) but reduced mean FPS **8.67%**. Under the net-gameplay doctrine that mean loss outweighs the tail improvement here; do not integrate.
- **`a.Budget.BudgetMs 5.0 -> 4.0` — `SKIPPED_PARENT_NOT_ACCEPTED`.** The 5 ms parent did not win, so 4 ms was not admitted.
- **Rollback/integrity:** all completed runs restored the latest verified winner and reported rollback verified. Post-campaign static authority verified installed DEV, frozen LKG, PBE exclusion and codesign; no owned DEV/emulator process remained.

`DEV-B8-WIN-01` therefore remains the exact next-test baseline. Continue only with unresolved or new evidence-backed one-factor settings; retain any repeatable net improvement even when small, but do not reinterpret a material regression as a win.

#### V4 shader-background clean-retest attempt — 2026-09-11

**Campaign:** `incremental-20260911T210746Z-64c4f370`
**Outcome:** `INCONCLUSIVE / AUTH_BLOCKED / NOT INTEGRATED`
**Integration:** `NONE` — `DEV-B8-WIN-01` remains the working winner.

- The matched `DEV-B8-WIN-01` control completed valid 1-5 combat measurement and rollback.
- The one-factor candidate `r.ShaderPipelineCache.BackgroundBatchSize 20 -> 4` applied successfully, but the official client remained on the Riot credential screen for the full bounded login window. No candidate 1-5 performance window exists, so this run is not a performance rejection or gain.
- Candidate cleanup restored the profile, AVD, DEV application integrity and frozen LKG integrity, but the run recorded `rollback_verified=false` because the verifier sampled ADB `get-state` immediately after fallback QEMU shutdown while the dead serial was still retiring from ADB. Immediate independent post-failure proof showed `QEMU=NONE`, `DEV=NONE`, ADB serial absent, installed DEV integrity PASS, frozen LKG integrity PASS and codesign PASS.
- The recorded failed run is preserved exactly as evidence; its rollback bit is not rewritten. A governed bounded transport-quiescence verification repair is required before another candidate is admitted.

#### OvernightLab authority/evidence reconciliation — 2026-09-10

**Outcome:** `TOOLING RECONCILED / TELEMETRY PRESERVED`
**Integration:** `YES` — this changes the logger/control-plane rules, not the DEV performance winner; `DEV-B8-WIN-01` remains the working baseline.

- Updated OvernightLab authority to schema 2 and made `DEV-B8-WIN-01` the normal control baseline.
- Normal session properties now use the current winner: multifile cache ON, `preferSubmitAtFBOBoundary` disabled, and **no** `syncMonolithicPipelinesToBlobCache`.
- Frozen LKG hashes/cache properties remain separate historical comparator authority; current installed DEV integrity and frozen LKG integrity are verified independently instead of requiring them to be permanently identical.
- Historical CPU/RAM/configuration drift no longer causes evidence deletion: telemetry is preserved and labeled `DATA_ONLY_NONCOMPARABLE` when it is not valid for current promotion.
- Client/RHI/core-pipeline mismatch is recorded, marked data-only, and stops the intended current experiment after identity capture rather than being mistaken for current-route evidence.
- Effective vCPU/RAM are parsed from the actual QEMU command and recorded rather than copied from expected values.
- Native evidence provenance now inherits the run's promotion admissibility.
- Resolved candidates remain in the manifest with status/reason, but the automatic queue contains only current working control. Buffer retention remains a logged NO WIN, no-global-sync is integrated, old global-sync cache is historical comparator only, and direct Vulkan remains a logged rejected core-route candidate.
- Root-only cache inventory is now opt-in; property readback/native frame telemetry remain the ordinary non-disruptive evidence path.
- Self-test and fault-test pass with explicit checks for current-winner baseline, drift retention, RHI precedence and no-root cache inventory default.
- Existing campaign/database outputs remain useful historical data and are not discarded solely because of minor authority drift.

#### Authority reconciliation — 2026-09-10

**Outcome:** `CURRENT-DOC TRUTH RECONCILED`.

- Verified installed DEV identity: `com.flashls1.tftmac.dev`, TFTMAC 2.3.0 build 8.
- Verified effective DEV execution from current source plus live QEMU receipts: **8 vCPU / 6144 MiB**, 1920×1080 / 320 dpi / 60 Hz, host GPU/CoreAudio, ports `5041/5586/8556`.
- Verified static StockShadow restoration file remains 6 vCPU / 5120 MiB; this is intentionally a sealed baseline, not the effective live DEV profile.
- Verified current official client `18.1-5423749` / `8423749` and current selected game RHI `OPENGL_ES_ANGLE`.
- Corrected authority rules so `facts.md` is first project authority and `project.md` is the living state wiki; credible newer evidence must be validated and used to update those files before a plan/change is finalized.
- Added the clean-workspace completion rule: the selected managed change cannot be called complete with accidental dirty Git state.
- Historical Control values (6 vCPU / 5120 MiB / ports 5038/5582/8554) remain valid only when explicitly labeled protected Control/history and no longer describe the current DEV optimization baseline.

#### Post-merge OvernightLab continuity — 2026-09-11

**Outcome:** `SOURCE MERGED / LIVE-LAYER RECOVERY REQUIRED`
**Performance integration:** `NONE` — `DEV-B8-WIN-01` remains the current winner; no performance candidate was run or promoted.

- PR #9 passed exact-SHA `Validate TFTMAC` CI on `9674294dd557a8ed7250c34deb6e9ca3f8d05f86` and squash-merged to `master` as `bf61c21a723f2f132834acedda860efbb2223d42`.
- The merged source retains the reconciled schema-2 OvernightLab authority, current-winner control manifest and telemetry policy.
- After Clara closed the merged `ff2f318b...` worktree, the ignored derived OvernightLab campaign/database/screenshots that existed only under that worktree were no longer locally present. Bounded recovery searches found no copy in the remaining TFTMAC worktrees, live TFTMAC root, Trash, Clara durable areas searched, Spotlight results, or local Time Machine snapshots. The project must not represent those derived files as recovered.
- The authoritative native DEV capture store remains present under `~/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures`. Twelve relevant Sept. 10 capture directories were directly observed for the campaign window, each with `TFTMAC_NATIVE_RUNTIME.sqlite`; the final 22:43 UTC session `2026-09-10T22-43-10.664Z-a5718134-6211-4bcb-8bd6-c17b134e8a6f` remains present with a 7,368,704-byte native database.
- Recovery therefore uses surviving native session evidence plus the synchronized record books. A fresh live OvernightLab may be initialized from current authority, but historical derived campaign rows/results must not be synthesized merely to replace deleted local output.
- This continuity repair does not reopen buffer retention, direct Vulkan, queue-submit-inline, virtual-queue-off, fence-contexts-off, historical global-sync, or any other resolved fast-pass candidate.

#### Four-hour incremental optimization sweep — 2026-09-11

**Campaign:** `incremental-20260911T082151Z-1f32770a`
**Outcome:** `DEADLINE_COMPLETE / NO NEW WINNER`
**Integration:** `NONE` — `DEV-B8-WIN-01` remains the verified working winner.
**Final working profile SHA-256:** `45d6465040ef8b7298cd8da000208e4ee0be924c65a20326900267f25adf5c9c`.

- `r.pso.PrecompileThreadPoolSize 4 -> 2`: **INCONCLUSIVE / NOT INTEGRATED**. A valid matched 1-5 control completed, but candidate apply failed because ADB shell privilege was not restored after the root profile-overlay transaction. No admissible candidate performance windows exist.
- `r.ShaderPipelineCache.BackgroundBatchSize 20 -> 4`: **INCONCLUSIVE / NOT INTEGRATED**. The matched control completed; candidate apply again failed on ADB unroot. No candidate performance conclusion is allowed.
- `a.Budget.BudgetMs 6.0 -> 5.0`: **INCONCLUSIVE / NOT INTEGRATED**. The matched control completed; candidate apply failed because ADB root did not become effective.
- `a.Budget.BudgetMs 5.0 -> 4.0`: **SKIPPED** exactly as planned because the 5 ms parent was not accepted.
- No candidate entered the cumulative working stack, so no `DEV-B8-WIN-02` identity is created.
- Three valid post-queue `DEV-B8-WIN-01` stability soaks at stage 1-5 averaged **57.687**, **58.657**, and **59.789 FPS** respectively. Their mean p95 values were **20.677**, **19.716**, and **19.092 ms**; mean p99 values were **34.411**, **29.954**, and **23.170 ms**. A fourth soak was inconclusive after the expected ADB device disappeared, but rollback still passed.
- Every recorded run verified DEV/emulator shutdown, profile restoration, installed DEV integrity, and frozen LKG integrity. Protected Control/LKG was not modified.
- The campaign also repaired blocking controller/classifier defects encountered while obtaining valid evidence: cross-line OCR falsely forming `ERROR`, missing Tocker 1-5 score-only combat-phase recognition, process-local monotonic deadline persistence, and abort-on-inconclusive stability soak behavior. These are tooling/controller repairs, not performance wins.
- The three candidate settings remain **unresolved, not rejected**. A future campaign must first make the DeviceProfiles bind-overlay root/unroot transaction reliable, then may retest the same evidence-backed queue. Do not add these settings to the historical no-recycle list from this run.
- Full terminal decisions, native capture IDs/hashes, stability evidence, and next-test boundary are recorded in `.clara/plans/25f21f7e-ba86-4e3d-832d-9984522811c0/FINAL_RESULTS.md`.

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
