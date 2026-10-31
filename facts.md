# TFTMAC Facts — Current Operating Authority

## P0 — TFT TURBO 2 account-free native build authority, 2026-10-30

This successor is Clara change `fda4732b-70e6-45dd-97ca-cfc2b1f48c6c`, branch `clara/tft-turbo-2-fda4732b`, from verified October source `0a18c7f707730a18072df2bd74f5920ca1f98f56`. CP1/CP2 are complete. Flash explicitly revised CP3: do not back up/copy the signed-in environment; build now and let local Codex provision accounts later. The revised authority is this change's CP3_BUILD_ONLY.md and appended paired plan. This is a different source-only build, not a retry or bypass of the historical denied migration documented in CP3_BLOCKED.json. STOP after each checkpoint; CP4 requires another continue.

CP3_BUILD_STATUS: ACCEPTANCE_PASS_NATIVE_BUILD_AND_PENDING_STATE_SMOKE. The separate Desktop/TFT TURBO 2.app is installed from source commit d8d3f00e15688dc80e1614f0087b59afe96f0020; core SHA256 4bb69584da7ee410701e293529601071b921346c7db20219258dd6ff14fa3b88. All141 native tests,33 focused tooling tests and9/9 static build gates passed. Stable strict-deep signing,82 source-input hashes and packaged identity are verified. Native smoke displayed the expected CP4 provisioning-pending message, spawned no emulator/ADB and closed normally. Both original applications' checked artifacts/signatures are unchanged. Exact evidence is CP3_BUILD_ACCEPTANCE.json and CP3_NATIVE_SMOKE.json under this change's plan directory. Stop before CP4. No account, TFT startup, audible sound or gameplay performance acceptance is implied.

Both installed Desktop originals and all existing runtime/account state remain protected. The successor builder is now source-only: no private seed, PIN resource, signed-in AVD or saved Riot store is read/copied. Exact-path preflight, required stable signing, staged verification and exclusive no-overwrite publication admit native compilation only. The new native turbo2 registry remains blocked_not_built with absent unobserved SDK/AVD hashes; launch stops before account APIs or emulator startup. No emulator upgrade or account migration occurs in CP3. Local Codex owns later account provisioning; sign-in-dependent acceptance remains deferred, not waived.

Current project-local SDK evidence is Android Emulator 37.1.11/build15917651, Google Play ARM64 API36 image revision7 and platform-tools37.0.1. The older Android34 label below is corrected. Legacy performance percentages below are historical wording: 87.4 to71.2 is a 16.2-percentage-point CPU reduction; 275.5 to234.3 is41.2 points (about15.0% relative), not41.2% relative.

The October29 static G-06/build PASS record does not prove current clean audio. Preserved Oct30 capture evidence contains persistent ranchu PCM EIO; no repair is claimed. Future official engine versions named in the roadmap must be reverified against official release/SDK metadata at CP4 before selection. The 482-file preservation manifest and exact source receipt are under `.clara/plans/7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/`.

Turbo2 identity is com.flashls1.tftmac.turbo2, Desktop/TFT TURBO 2.app; future independent SDK/AVD under TFTMAC/Turbo2/StockShadow; state/captures under TFTMAC/Modes/turbo2. Server/console/guest-ADB/controller ports are 5053/5600/5601/8560, assigned but not persistently reserved. The shared exclusive lease is unchanged. The native registry now contains a fourth, explicitly blocked turbo2 mode; the original three mode records retain field parity. New bundle/forwarder and independent unlock-service names do not establish Keychain/TCC or login access. Actual runtime wiring, effective graphics/audio and retained-session checks remain later acceptance. See docs/TFT_TURBO_2_ISOLATION.md.

The following October29 sections describe the incumbent TURBO baseline and historical build rules, not authorization to overwrite it from this successor branch.

**Updated:** 2026-10-29  
**Operating Baseline:** Personal TFT TURBO Candidate  
**Durable Execution Register:** [`improvements.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/improvements.md) (and [`implementation.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/implementation.md))  
**Build & Verification Authority:** [`BUILD_PROTOCOL.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/BUILD_PROTOCOL.md) | [`AGENTS.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/AGENTS.md)  
**Verification Runner:** [`scripts/verify-turbo-build.command`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/scripts/verify-turbo-build.command)

> [!WARNING]
> Stale documents, legacy notes, and pre-18.3 reports in `docs/` or `TFTDEV-SSOT/` are **historical provenance only**. Do not pull numbers or assumptions from older files without current empirical validation.

---

## 1. Host Hardware Authority (Apple M6)
- **Machine Model:** Apple Mac mini (`Mac18,5`, Model Number `MHQL4LL/A`)
- **Processor:** Apple M6 SoC (arm64e)
  - **12 Physical CPU Cores (3 Hardware Performance Levels):**
    - `hw.perflevel0` (**Super Cores**): 2 physical cores, 192 KB L1i, 128 KB L1d, 20 MB L2 cache
    - `hw.perflevel1` (**Performance Cores**): 4 physical cores, 131 KB L1i, 65 KB L1d, 20 MB L2 cache
    - `hw.perflevel2` (**Efficiency Cores**): 6 physical cores, 163 KB L1i, 98 KB L1d, 8 MB L2 cache
    - Aggregate L2 Cache: 48 MB
  - **GPU:** Apple M6 12-Core Integrated GPU with **Metal 4** support
  - **Memory:** 16 GB Unified Memory (17,179,869,184 bytes)
  - **OS / Toolchain:** macOS 27.0.1 (Darwin 26A434), Xcode 26.6 (Build 17F113)
- **CRITICAL HARDWARE INVARIANT:** The host processor is the **Apple M6**. The prior M4 Mac mini is obsolete historical hardware and is completely replaced. The external volume label `/Volumes/MAC MINI M4` is merely a legacy disk mount point name from an older drive, NOT the host system processor.

---

## 2. Immutable Protected Baseline (INV-01)
- Protected production app: [`/Users/flash/Desktop/TFT Ranked.app`](file:///Users/flash/Desktop/TFT%20Ranked.app)
- Core executable SHA-256: `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`
- Invariant Rule: Strictly read-only. Never modify, re-sign, or overwrite.

---

## 3. Active Optimization Application
- Active candidate app: [`/Users/flash/Desktop/TFT TURBO.app`](file:///Users/flash/Desktop/TFT%20TURBO.app)
- Bundle ID: `com.flashls1.tftmac.dev`
- Packaging Script: `python3 scripts/build-turbo-app.py`
- Runtime Environment: Android Emulator 37.1.11 (build 15917651), StockShadow Google Play ARM64 API36 image revision7, 8 vCPU, 6144 MiB RAM, host GPU, CoreAudio, 1920x1080 @ 60 Hz display.
- Official Game: Riot Teamfight Tactics (`com.riotgames.league.teamfighttactics`).
- ADB Port: 5041 | Console Port: 5586 | Controller Port: 8556.

---

## 4. Verified Operating Truths
1. **Lever 1 Transport Batching is a Verified Win:**
   - 256 KB ASG data ring buffer (`hw.gltransport.asg.dataRingSize=262144`).
   - 64 KB write step size (`hw.gltransport.asg.writeStepSize=65536`).
   - 2000 µs draw flush interval (`hw.gltransport.drawFlushInterval=2000`).
   - Measured Match 8 Impact: RHIThread CPU reduced from 87.4% to 71.2% (-16.2%), host emulator CPU reduced by 41.2% (275.5% -> 234.3%), zero-bottleneck budget tripled (13% -> 36.5%), jank reduced by 23.2%, average FPS increased to 52.38 FPS.
2. **Lever 2 (`block-cache-candidate`) is Empirically Disproven & Rejected:**
   - Tested in Match 9 and caused immediate regression: RHIThread CPU jumped to 89.3%, host CPU to 291.5%, and FPS collapsed to 47.25.
   - Root cause: Hot-path mutex locking in `BufferBlock::getTFTMACCachedView`, early 2048-resident saturation without LRU eviction, and descriptor serial invalidation churn.
   - Rolled back immediately to pure Lever 1 + stock ANGLE.
3. **Startup Stalls Decoupling Diagnosis:**
   - Initial boot stalls (Windows 21 & 24, ~2.1s each) occur identically across all builds during Riot auth and asset unpack on the main thread.
   - Hypervisor sampling proved `gfxstream::host::SyncThread` waits synchronously on `EmulatedEglFenceSync` and `std::shared_future::get()`. Non-render tasks freeze surface presentation because the pipeline remains synchronously coupled across the hypervisor boundary.
4. **Authoritative Build & Verification Protocol (9 Quality Gates):**
   - Every candidate delivered to `/Users/flash/Desktop/TFT TURBO.app` must pass all 9 Pre-Delivery Build Quality Gates via `scripts/verify-turbo-build.command`.
   - **G-01:** Invariant INV-01 (`TFT Ranked.app` Core SHA-256 == `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`).
   - **G-02:** Stable local signing identity `"TFTMAC Local Code Signing"` (TCC permissions preserved across rebuilds).
   - **G-03:** Strict deep codesign verification passes.
   - **G-04:** Yellow TURBO banner icon (`TFTMAC-TURBO.icns` MD5 == `a8f93ea0c9770af6c0a53d6a8bee57d7`).
   - **G-05:** Declared TCC entitlement (`NSRemovableVolumesUsageDescription` preserved in `Info.plist`).
   - **G-06:** Audio subsystem health (682 ms buffer headroom via 2048-frame CoreAudio, boot `audioserver` pre-warm, mid-game root guarded).
   - **G-07:** Host CPU (8 vCPUs) and background compiler daemons suppressed in `DeviceProfiles.ini`.
   - **G-08:** Native test suite passes 100% (all 135 XCTest unit tests pass with 0 failures).
   - **G-09:** DEV HighPerf cryptographic hash integrity (4-way synchronization across `DeviceProfiles.ini`, `profile-transaction.sh`, `TFTMACRuntime.swift`, and deployed bundle).
