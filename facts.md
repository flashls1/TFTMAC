# TFTMAC Facts — Current Operating Authority

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
- Runtime Environment: StockShadow Android 34 emulator (build 15917651), 8 vCPU, 6144 MiB RAM, host GPU, CoreAudio, 1920x1080 @ 60 Hz display.
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
