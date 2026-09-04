# TFTMAC Continuation Handoff — 2026-09-04

Copy this entire document into the next agent. Treat it as the authoritative pointer to current state, then verify the cheap, drift-prone facts locally before changing anything.

---

## 1. Mission & Current Status

**Mission:** Deliver a sustained, locked 60 FPS native macOS gaming experience for official Teamfight Tactics (Unreal Engine 4 on Android 16) running on the Apple Silicon M4 Mac mini (`Mac16,10`, 10 CPU / 10 GPU cores, 16 GB unified memory, macOS 15.6.2).

**Current Status:**
- **32-Minute Live Match Completed (12:50 PM – 1:23 PM Local Time)**:
  - Telemetry capture `2026-09-04T17-50-10.043Z` recorded 892 2-second presentation windows.
  - **Overall Average FPS**: **55.80 FPS** (massive improvement over historical 0.21–30 FPS).
  - **58–61 FPS (Target Band)**: **523 windows (58.6% of the entire match ran at solid 60 FPS)**.
  - **Planning / Shopping**: Flat **58.6 – 59.8 FPS** with 17.3–18.4 ms frame times and ~320% guest CPU load.
  - **Combat Drops**: Late-game combat (16–22+ units casting spells, moving) experienced CPU load spikes to **380%–510%**, pulling frame rates down into the **40–53 FPS** range (1% low: 33.27 FPS).
  - **Host Presentation**: Flat **60.00 FPS** (P95 Metal GPU execution: 0.72 ms, 0 dropped frames).

---

## 2. Definitive Memory Audit: Is RAM Good? Do We Need 8 GB?

> [!IMPORTANT]
> **Definitive Finding: Keep Guest RAM at 5,120 MB (5 GB). Do NOT increase to 8 GB.**

### Guest Android RAM (5,120 MB Allocation)
- Android only consumed **~3.2 GB** at peak combat.
- Available guest memory averaged **1,705 MB** (minimum was 1,533 MB).
- **Zero LowMemoryKiller (LMK) kills** occurred. Android was not under memory pressure and had >1.5 GB of free headroom at all times.

### macOS Host RAM (16 GB Unified Memory on Apple Silicon M4)
- Total Host RAM: **16 GB** (shared unified memory for CPU and Metal GPU).
- During the match, available host RAM was **2,938 MB average** (min: 2,620 MB), with **7.2 GB compressed** and **1.7 GB swap**.
- **The Unified Memory Trap**: If guest RAM is increased from 5 GB to 8 GB (+3 GB), macOS must commit an additional 3 GB of pinned hypervisor pages from the host pool.
- Because the host only has ~2.6 GB of uncompressed free RAM, an 8 GB VM allocation would push macOS into severe memory exhaustion, triggering aggressive page compression and active disk swapping.
- On Apple Silicon's unified memory bus, memory bus saturation from swapping causes immediate Metal GPU presentation stutter and severe frame drops.
- **Verdict**: 5,120 MB is the exact sweet spot. 8 vCPUs should be paired with 5,120 MB RAM.

---

## 3. Implemented Solutions & Architectural Improvements

### A. 8-vCPU Allocation for DEV Mode (`RuntimeModeAuthority.swift`)
- In `effectiveProfile(savedProfile:selection:)`, for `.advancedDiagnostics` (DEV mode), dynamically resolves `vCPU: 8` (or honors `TFTMAC_DEV_VCPU` if set), while leaving Control release untouched at 6 vCPUs.
- Passes `-cores 8` to QEMU and writes `hw.cpu.ncore = 8` in the AVD configuration transaction.
- On the 10-core Apple M4 (4 Performance + 6 Efficiency cores), 8 vCPUs provides the guest with the horsepower required to absorb 510% combat load spikes across `GameThread`, `RHIThread`, audio, and worker pools, while reserving 2 dedicated physical cores on the host for macOS WindowServer and the Metal presentation loop.

### B. UE4 In-Game Combat Optimization (`provisionTFTDeviceProfiles`)
- **Disabled Champion Cloth Physics (`+CVars=p.ClothPhysics=0`)**:
  - Disables CPU vertex cloth simulation on 20–30 combat units, reclaiming **5–8 ms of GameThread frame budget** per frame during combat.
- **Activated Dynamic Resolution Master Switch (`+CVars=r.DynamicRes.OperationMode=1`)**:
  - Master switch enabled with `+CVars=r.DynamicRes.MinScreenPercentage=85` and `+CVars=r.DynamicRes.FrameTimeBudget=16.666666`.
  - If a sudden multi-ultimate cascade occurs, UE4 temporarily scales resolution down by up to 15% (to 1632×918) to preserve a flat 60 FPS presentation, recovering to 1080p the instant the burst clears.
- **Tuned PSO Precompile Pool (`+CVars=r.pso.PrecompileThreadPoolSize=2`)**:
  - Restricted background shader precompile worker threads to 2 (down from 4), preventing worker threads from swamping vCPUs during combat.

### C. Quickboot Snapshot Clean Shutdown (`TFTMACRuntime.swift -> stop()`)
- In `stop()`, issuing `am force-stop com.riotgames.league.teamfighttactics` 300 ms prior to `adb emu kill` closes active Vulkan swapchains and device instances.
- Eliminates QEMU's `snapshot save failed: UNSUPPORTED_VK_APP` blocker, enabling 2–3 second fast snapshot resumes on subsequent boots.

### D. Telemetry HUD Precision & Damage-Driven PIPE Truth
- **Dormant Leash Trap Fixed (`GameFrameTelemetry.swift`)**:
  - `hasActiveLoginPrompt(in:)` filters out dormant `ActivityRecord` leashes and `SnapshotStartingWindow` layers left behind when the login webview closes.
  - Telemetry immediately hooks onto `SurfaceView[...GameActivity](BLAST)`, accurately displaying `TFT 60 · 1% 60 · P99 18ms` without false sticky login readings.
- **Process Priority Maintenance**:
  - In `observeGameProcess`, re-applies `renice -n -20 -p <observedGamePID>` on every observed game PID (including replacement processes after ANR crashes), guaranteeing sustained real-time CPU priority.

---

## 4. Exact Workspace & Authority

- **Local Worktree**: `/Volumes/MAC MINI M4/Clara/Worktrees/flashls1--tftmac/tftmac--215ec5a3-6554-4ca3-95db-1525433bb20f`
- **GitHub Repository**: `https://github.com/flashls1/TFTMAC.git`
- **Remote**: `origin`
- **Branch**: `clara/implement-wave-b-runtime-mode-selection--215ec5a3`
- **Protected Boundaries / Development Doctrine**:
  - Control app at `/Applications/TFTMAC.app` (port 5038, serial `emulator-5582`) is the protected stable known-good launcher. **Do not rebuild, patch, overwrite, replace, or install development work over Control.** Its executable SHA-256 `d3bf7c249a3e5f11b81f778b063e1a8cfe2e7fdeec0537ee6bd8447b1c2268d2` was restored/re-verified after an accidental 2026-09-04 test install.
  - DEV app at `/Applications/TFTMAC DEV.app` (port 5041, serial `emulator-5586`, bundle `com.flashls1.tftmac.dev`) is the active isolated engineering target for all new features and experiments.
  - Control remains available as the stable rollback/playable launcher while DEV evolves. The exclusive runtime lease may require Control to be cleanly closed to run DEV, but that never authorizes mutating Control.
  - Promotion from DEV into a full production release is a separate explicit Flash-authorized release operation after DEV acceptance. Until promotion is authorized, only the DEV install may be replaced by development builds.

---

## 5. Verification & Deployment Receipts

- **Verification Suite**: `./scripts/verify-tftmac.command` $\to$ **55/55 native tests passed (0 failures, PASS)**.
- **DEV App Build**: `./scripts/build-dev-launcher.command` $\to$ Built and signed `dist/TFTMAC DEV.app` cleanly (PASS).
- **Desktop Install**: `./scripts/install-desktop-launchers.command` $\to$ Deployed to `/Applications/TFTMAC DEV.app` and linked to `/Users/flash/Desktop/TFTMAC DEV.app` (PASS).
- **Single Source of Truth**: Updated [`settings.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--215ec5a3-6554-4ca3-95db-1525433bb20f/settings.md) with Section 7.G.
