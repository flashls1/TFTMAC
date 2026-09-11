# Preflight — TFTMAC overnight official-client optimization lab

Date: 2026-09-10
Change: `ff2f318b-245d-418a-b86f-e07d55b19826`
Completion class: IMPLEMENT_SHIP

## User outcome
Build and start a production-grade unattended optimization laboratory using the already-installed LKG-identical `TFTMAC DEV.app`, without another full app/runtime clone, with official-client-only evidence, fast fail-before-game iteration, complete per-field telemetry, deterministic rollback/resume, and an overnight campaign that can continue without the ChatGPT browser session.

## Controlling current authority
- User-supplied Sept-10 reuse-existing-LKG implementation plan in the current conversation.
- `/Volumes/MAC MINI M4/TFTFINALBOSS/TFTMACREBUILD.md` and frozen `/Volumes/MAC MINI M4/TFTFINALBOSS/LKG-2026-09-10/` are build/recovery authority; stale project narrative does not override them.
- Corrected `/Volumes/MAC MINI M4/TFTFINALBOSS/TFTMAC_OPTIMIZATION_OPPORTUNITIES_2026-09-10.md` is current-client optimization authority.
- Current workload: `com.riotgames.league.teamfighttactics`, version `18.1-5423749`.

## Verified host/runtime facts
1. `/Applications/TFTMAC DEV.app` and the frozen LKG `TFTMAC DEV.app` are recursively identical. Core launcher, core executable, DeviceProfiles, transaction script, runtime registry, and Vulkan probe hashes match.
2. Accepted Sept-10 launch actually used `-cores 8 -memory 6144`, 1920x1080, 320 DPI, 60 Hz, host GPU.
3. Installed app/runtime already provides advanced-diagnostics launch, external `TFTMAC_ANGLE_DRIVER_MANIFEST`, driver staging/hash verification/load verification/rollback, saved-login flow, native telemetry, and capture machinery.
4. Existing historical autonomous/performance scripts and candidate manifests contain PBE package/profile references and are inadmissible as the new campaign authority.
5. Current official-client evidence keeps three active optimization families only: buffer-view retention diagnosis/repair; existing cache application/reuse validation; bounded clean direct-Vulkan compatibility screen. CPU/RAM/compiler-count/memory-policy sweeps are removed.
6. Native RHI telemetry can misclassify VkInstance/capability evidence as selected Vulkan; V1 must correct selected RHI externally without rebuilding the app.
7. Current native evidence is fragmented across per-session SQLite and sidecars; the overnight controller needs one campaign database and one run identity linking all artifacts.
8. The app bundle's stock-shadow registry still contains historical `vcpu=6`, but runtime source defaults advanced diagnostics to `TFTMAC_DEV_VCPU` or 8; every launch must explicitly set and independently verify 8/6144.
9. No existing data deletion is authorized in this change.

## Simplest correct architecture
Do not create another app, SDK, emulator or AVD. Add small source-controlled external controller/analyzer scripts plus a small runtime `OvernightLab` install. Reuse `/Applications/TFTMAC DEV.app` and existing StockShadow. Runtime/config candidates require no app build; ANGLE candidates build only the three ANGLE libraries; app rebuild is outside the normal campaign and allowed only for a proven blocker.

## Required acceptance
- Installed DEV and frozen LKG hashes unchanged.
- New official-client runner never consumes PBE candidate/evidence input.
- Runtime identity verifies live package/version/activity/surface and 8/6144/1080p before scoring.
- One campaign/run identity links variables, provenance, coverage, failures, rollbacks and results.
- Every material variable has baseline/requested/effective/verification fields.
- Decision-critical telemetry producer coverage is explicit; incomplete evidence produces INCONCLUSIVE.
- RHI selected value uses explicit Unreal selection/init precedence.
- Same deterministic failure is quarantined; no unbounded waits/retries.
- Rollback verified before next candidate; inability to prove baseline is a hard campaign stop.
- Resume after forced interruption reconciles real host/guest state.
- No app/runtime copies are created.
- Baseline official-client autonomous Tocker smoke succeeds if Riot/network state allows; human-only CAPTCHA/MFA is an AUTH_BLOCKED external state, never bypassed.
- First buffer observability candidate uses component-only ANGLE build/deployment through existing host and separates grouped rejection reasons.
- Morning report/artifacts generated.
- Unattended campaign process is started locally under `caffeinate` and checkpointed durably.

## Blocker policy
Ordinary compile/boot/ADB/UI/telemetry/candidate failures are recoverable or quarantined and cannot become a reason to stop implementation. Only an unresolvable external authentication requirement, unavailable Riot service, or inability to restore the LKG-derived baseline may become TRUE_EXTERNAL_BLOCKER.