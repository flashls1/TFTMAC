# TFTMAC Pipeline Settings & Tuning Reference

**Reference reconciled:** 2026-09-10 America/Chicago.
**Authority:** this file is a detailed tuning/reference catalog, **not an independent SSOT**. Read `facts.md` first and `project.md` second; when this file conflicts with them, the authority records govern until validated newer evidence is used to update those records.
**Hardware target:** Apple M4 Mac mini (`Mac16,10`), 10 physical CPU cores (4 performance + 6 efficiency), 10 GPU cores, 16 GiB unified memory, macOS 26.6.2 / build 25G83. Fixed CPU/GPU MHz values are not project-authoritative.
**Current DEV execution:** TFTMAC DEV 2.3.0 build 8, 1920×1080 / 320 dpi / 60 Hz, **8 vCPU / 6144 MiB**, host GPU/CoreAudio, OpenGL ES through ANGLE, current winner `DEV-B8-WIN-01`. vCPUs are virtual scheduling resources; they do not reserve or dedicate an equal number of physical M4 host cores.

> **DEVELOPMENT TARGET LOCK — 2026-09-04:** The protected Control app at `/Applications/TFTMAC.app` is the stable known-good launcher and is not a development target. All new settings, UI, graphics, runtime, and experiment changes go to `/Applications/TFTMAC DEV.app` / `advanced_diagnostics` first. DEV may be promoted into a full production release only through a separate explicit Flash-authorized release process after acceptance. Until then, no DEV build/install step may overwrite or mutate Control.

---

## 1. Pipeline Architecture Overview

The graphics and gameplay pipeline operates as four serial stages:
$$\text{Displayed FPS} = \min\Big(\mathbf{F_{\text{Unreal Engine}}},\; \mathbf{F_{\text{SurfaceFlinger}}},\; \mathbf{F_{\text{gRPC PIPE}}},\; \mathbf{F_{\text{macOS Metal}}}\Big)$$

Every bottleneck discovered in testing maps directly to one of these four operational layers.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Layer 1: Unreal Engine (Inside TFT APK)                                      │
│   • DeviceProfiles.ini  • GameUserSettings.ini  • CVars                      │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ BLASTBufferQueue
┌──────────────────────────────────────▼───────────────────────────────────────┐
│ Layer 2: Android Guest OS & Compositor (Android 16 Emulator)                 │
│   • SurfaceFlinger  • Hardware Display HAL  • Process Nice Priority          │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ gfxstream ASG Ring Buffer & gRPC
┌──────────────────────────────────────▼───────────────────────────────────────┐
│ Layer 3: Virtualization & Hardware Bus (QEMU / Apple Hypervisor)             │
│   • PCI BAR  • ASG Shared Memory  • -vsync-rate Timer                        │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ streamScreenshot RPC
┌──────────────────────────────────────▼───────────────────────────────────────┐
│ Layer 4: Host Native App & Metal Presenter (macOS)                           │
│   • SwiftNIO HTTP/2  • Frame Mailbox  • CAMetalLayer Presenter               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Layer 1: Unreal Engine In-Game Settings & CVars

Riot's current TFT mobile client is verified to use Unreal Engine. This project does not claim a specific Unreal major version without direct current evidence. On Android, the observed configuration path uses Unreal Device Profiles and user settings.

### A. Device Profile Hierarchy & Overrides
* **Target Guest File**: `/sdcard/Android/data/com.riotgames.league.teamfighttactics/files/UnrealGame/TFT/TFT/Saved/Config/Android/DeviceProfiles.ini`
* **Provisioned By**: `TFTMACRuntime.swift -> provisionTFTDeviceProfiles`

| Setting / CVar | Stock Android Value | TFTMAC High-Perf Value | Operational Impact & Rationale |
| :--- | :--- | :--- | :--- |
| `tft.DefaultFrameRateLimit` | `30` | `60` | Unlocks 60 FPS nominal budget during boot, splash, menus, and asset loading (bypasses mobile battery-saving throttle). |
| `t.MaxFPS` | `0` or `30` | `60` | Hard clamp on the engine rendering loop; matches the 60 Hz hardware VSYNC clock. |
| `r.VSync` | `0` (or dynamic) | `1` | Forces strict VSYNC pacing; eliminates tearing and prevents CPU spin-waiting. |
| `a.StripOddFramesWhenFrameStripping` | `1` | `0` | **Restores full 60 FPS champion animations.** Stock profile strips every odd animation frame to save mobile CPU. |
| `a.StripFramesOnCompression` | `1` | `0` | Disables animation compression frame stripping. |
| `r.SkeletalMeshForceLOD` | `1` | `0` | Prevents forced low-detail LOD on champion and Little Legend 3D models. |
| `r.Streaming.PoolSize` | `300` | `1000` | Expands texture streaming memory pool to 1 GB (utilizes M4 unified memory). |
| `r.Streaming.PoolSizeForMeshes` | `25` | `250` | **Eliminates combat hitching.** Stock 25 MB pool forced constant disk paging during 8-player combat; 250 MB keeps all units cached. |
| `r.RenderTargetPoolMin` | `0` | `100` | Pre-allocates 100 MB of render targets (3x mobile forward-shading requirement) while freeing 300 MB of guest RAM for OS disk/asset page caching. |
| `r.pso.PrecompileThreadPoolSize` | historical `4` | current value must be read from the verified DEV profile/receipt | Controls background PSO compilation concurrency. It does **not** permanently reserve physical or virtual cores for GameThread/RHIThread; validate any change as a one-factor DEV candidate. |
| `p.ClothPhysics` | `0` | `1` | Enables cape and cloth simulation physics on champions (~0.5 ms CPU budget under <=30 champions). |
| `grass.Enable` | `0` | `1` | Enables 3D interactive arena foliage and grass. |
| `r.MaterialQualityLevel` | `0` (Low) | `1` (High) | Enables full PBR material shaders and normal maps. |
| `tft.Audio.DeviceTier` | `Low` | `High` | Restores full-fidelity audio assets and spatial effects. |
| `tft.Audio.PlayOnlyOneArenaAtATime` | `true` | `false` | Enables full board audio staging without artificial sound muting. |
| `tft.Audio.RestrictNumberOfAmbientSounds`| `true` | `false` | Restores high-definition ambient environment audio. |
| `r.MobileContentScaleFactor` | `0.0` (dynamic) | `1.0` | Locks rendering scale 1:1 with the physical 1080p display buffer. |
| `r.DynamicRes.FrameTimeBudget` | Dynamic | `16.666666` | Anchors dynamic resolution scaling directly to a 16.67 ms (60 FPS) frame budget. |
| `r.DynamicRes.MinScreenPercentage` | `70` | `85` | Provides emergency 15% load-shedding relief floor during particle bursts while rendering at 100% (native 1080p) during standard play. |

---

## 3. Layer 2: Android Guest OS & Compositor Settings

Configured automatically over adb during the boot and gameplay preparation phase.

| Setting / Property | Command / Property | Value | Impact & Bottleneck Resolved |
| :--- | :--- | :--- | :--- |
| **System Min Refresh Rate** | `settings put system min_refresh_rate` | `60.0` | Prevents Android 16 display scheduler from dropping refresh rate when UI is idle. |
| **System Peak Refresh Rate** | `settings put system peak_refresh_rate` | `60.0` | Prevents SurfaceFlinger from phase-jittering between 60 Hz and 120 Hz. |
| **SurfaceFlinger Timestamping** | `setprop service.sf.present_timestamp` | `1` | Enables hardware presentation timestamps required for accurate jitter/latency measurement. |
| **SurfaceFlinger Debug Overlay** | `setprop debug.sf.showupdates` | `0` | Disables debug visual updates that waste GPU rasterization. |
| **TFT Process Priority** | `renice -n -20 -p <pid>` | requested negative nice value | Requests higher CFS scheduling preference for the TFT process. `nice -20` is **not** Linux real-time scheduling and does not guarantee that background work cannot preempt game threads. |
| **Background Wellbeing Daemon**| `pm disable-user com.google.android.apps.wellbeing` | Disabled | Eliminates boot-time CPU storms from GMS app wellbeing and usage tracking scanners. |
| **Virtual AC Power** | `dumpsys battery set ac 1` | `1` | Forces virtual AC power state; stops Android from entering battery saver mode. |
| **Stay Awake While Plugged In** | `settings put global stay_on_while_plugged_in` | `7` | Prevents screen timeout or lockscreen activation during benchmarks. |
| **Low-Latency Audio Sink** | `setprop debug.stagefright.audio.sink` | `1` | Routes game audio through low-latency stagefright direct sink. |
| **Audio Fast Track Multiplier** | `setprop af.fast_track_multiplier` | `2` | Expands fast-track mixer ring buffer to eliminate audio crackling. |
| **Deep Audio Buffer** | `setprop audio.deep_buffer.media` | `1` | Prevents audio underruns during burst disk I/O. |
| **SurfaceFlinger Latch Unsignaled** | `setprop debug.sf.latch_unsignaled` | `1` | Bypasses fence wait locks when GPU finishes ahead of compositor latch. |
| **SurfaceFlinger GL Backpressure** | `setprop debug.sf.enable_gl_backpressure` | `0` | Disables compositor backpressure stalls. |

---

## 4. Layer 3: Virtualization & Hardware Bus (QEMU / gfxstream)

The translation layer between the guest Linux kernel and the macOS host hardware.

| Setting / Parameter | Location | Value | Critical Hardware Constraint |
| :--- | :--- | :--- | :--- |
| **ASG Write Buffer Size** | `asgWriteBufferSize` in AVD config | `1_048_576` (1 MiB) | **HARDWARE PINNED**: Exceeding 1 MiB causes fatal QEMU PCI BAR crash (`External address size too small`). Must never exceed 1 MiB. |
| **Hardware VSYNC Rate** | Emulator argument `-vsync-rate` | `60` | Hardware interrupt clock for the virtual display controller. Aligns 1:1 with 16.666 ms frame intervals. |
| **GPU Acceleration Mode** | Emulator argument `-gpu` | current DEV `host` | Uses the stock emulator host-accelerated gfxstream path. Current TFT selects OpenGL ES through ANGLE; Vulkan/gfxstream/MoltenVK/Metal are downstream layers. |
| **Guest vCPU Allocation** | effective launch profile / QEMU `-cores` | **`8` current DEV** | Gives the guest 8 virtual CPUs scheduled by the hypervisor/host. This does not dedicate eight physical cores or reserve two physical cores for macOS. The sealed AVD restoration file may still contain `hw.cpu.ncore=6`. |
| **Guest RAM Allocation** | AVD `config.ini` (`hw.ramSize`) | `6144` (6 GiB) | Gives Android adequate heap without pressuring macOS unified RAM. |
| **Crash Report Consent** | Emulator argument `-crash-report-mode` | `disabled` | Bypasses modal Google crash reporting consent dialogs on boot. |
| **Boot snapshot policy** | effective current DEV QEMU command | **cold / `-no-snapshot`** | Current verified DEV/LKG test launches are cold/no-snapshot for reproducibility. Historical quickboot experiments do not describe the current optimization baseline. |

---

## 5. Layer 4: Host App & Metal Presentation (macOS)

The native Swift app presenting frames to the physical Mac mini display.

| Component / Setting | Implementation | Design Function |
| :--- | :--- | :--- |
| **Single-Frame Mailbox** | `FrameMailbox.swift` | Single-slot overwrite buffer. Completely prevents buffer queue backlog; if host drops a tick, it presents the freshest frame rather than lagging behind. |
| **Metal Render Pipeline** | `EmbeddedEmulatorView.swift` | Fullscreen oversized single triangle vertex shader with bilinear clamp-to-edge sampling into `bgra8Unorm_srgb` `CAMetalLayer`. |
| **Multi-Activity Aware Sampler** | `GameFrameTelemetry.swift` | Automatically differentiates between `MobileFREWebViewActivity` (Riot web login) and `GameActivity` (3D game engine). Prevents false 0 FPS alarms. |
| **Damage-Driven Stream Awareness** | `updatePerformanceOverlay()` | Displays `TFT LOGIN (IDLE)` and `PIPE IDLE` when Android posts 0 dirty rectangles during static authentication forms. |

---

## 6. Mandatory Software Constraints & Hard-Locked Invariants

These settings cannot be modified. They represent strict safety, stability, hardware, and architectural boundaries where deviation results in immediate crash, memory corruption, or fatal desynchronization.

| Invariant / Setting | Hard-Locked Value | Failure Signature if Violated | Architectural Root Cause |
| :--- | :--- | :--- | :--- |
| **ASG Write Buffer Maximum** | `1_048_576` bytes (1 MiB) | Fatal QEMU abort: `External address size too small` | QEMU's PCI BAR address window allocation for Apple Silicon hypervisor is strictly bounded to 1 MiB. |
| **ASG Data Ring Size** | `32_768` bytes (32 KiB) | Ring synchronization stall / deadlocks | Larger rings exceed the virtio-gpu-asg kernel driver's lockless single-producer ring assumptions. |
| **ASG Write Step Size** | `16_384` bytes (16 KiB) | Command stream underruns or pipeline hitching | Empirically proven optimal balance between packet dispatch overhead and buffer exhaustion. |
| **gRPC Message Ingress Cap** | `16_777_216` bytes (16 MiB) | gRPC error: `RESOURCE_EXHAUSTED` (Socket teardown) | Standard gRPC limit is 4 MiB. A 1080p uncompressed frame is 8,294,400 bytes ($\sim 8.3\text{ MB}$) and requires a 16 MiB window. |
| **Display Interrupt Clock** | `-vsync-rate 60` | Phase beat jitter ($8\text{ ms} \leftrightarrow 25\text{ ms}$ alternating) | Physical QEMU virtual display timer. Setting Android to 120 Hz with a 60 Hz hardware clock creates permanent micro-stutter. |
| **Riot Performance Mode Beta** | **OFF (Hard Locked)** | Tail latency collapse ($p99 > 500\text{ ms}$) | Historical testing proved Riot's mobile beta throttles Unreal simulation threads unpredictably. |
| **MoltenVK Synchronous Queue**| `0` (Disabled / Async) | 40% overall frame rate collapse | Synchronous submits block the host render thread waiting for GPU completion, destroying pipeline overlap. |
| **MoltenVK Max Command Buffers**| `64` | Metal command buffer pool contention | Values of 128/256 increased memory pool churn without improving throughput. |
| **Dual Runtime Port Isolation** | Control: `5038/5582/8554`<br>DEV: `5041/5586/8556` | `Address already in use` or ADB session theft | Guarded by atomic runtime lease. Both runtimes can never share ports or run simultaneously. |
| **ADB Session Launch Chain** | `/usr/bin/open` via `RuntimeHost` | ADB status `unauthorized` | Launching emulator from background daemons or injecting `ADB_VENDOR_KEYS` breaks the macOS user security session. |
| **Riot Signed Binary Integrity** | Stock Google Play APK | Anti-cheat kick / App launch crash | Riot verifies package signatures (`signatures=PackageSignatures`). APK code or shaders must never be tampered with. |
| **Metal Texture Pixel Format** | `.bgra8Unorm_srgb` | High CPU overhead from software pixel conversion | Must match `CAMetalLayer` native scanout format on Apple Silicon. |

---

## 7. The Discovery Knowledge Base: How We Log & How We Unlocked It

Standard diagnostic tools repeatedly failed to provide truthful data because of the hybrid virtualization stack. Here is the forensic record of how each logging mechanism was discovered and built:

### A. The Game-Frame Telemetry Discovery (`dumpsys SurfaceFlinger --latency`)
* **Why Standard Tools Failed**: Android developers normally use `dumpsys gfxinfo`. However, `gfxinfo` only tracks View-based UI (`ViewRootImpl`). Because Unreal Engine bypasses the Android View hierarchy and renders directly to a native Vulkan `SurfaceView` (`SurfaceView[com.riotgames...GameActivity](BLAST)`), `gfxinfo` returned completely empty data.
* **How We Discovered the Solution**: We analyzed the Android compositor source code and found that SurfaceFlinger maintains a circular 128-entry hardware presentation ring buffer for every active BLAST layer:
  * Line 0: Nanosecond VSYNC refresh period (e.g. `16666667` for 60 Hz).
  * Lines 1–128: Triples of `[desiredPresentTime, actualPresentTime, frameReadyTime]`.
* **The Math**: By parsing the actual presentation timestamps, filtering out system sentinels (`0`, `0x7FFFFFFFFFFFFFFF`), and tracking intervals between consecutive actual presentation timestamps, we constructed an exact 1-second rolling telemetry window measuring `effectiveFPS`, `1% low`, `p95`, `p99`, `jankCount`, and `missedVsyncEquivalents`.

### B. The Login Screen Trap Discovery
* **The Mystery**: During initial boot and login, our telemetry reported 0 FPS with status `AVAILABLE`, logging 990 seconds of total failure and pulling the average down to 0.21 FPS.
* **How We Discovered the Cause**: We investigated `dumpsys SurfaceFlinger --list` and discovered that when Riot presents account login, it launches `MobileFREWebViewActivity` (a Chromium HTML webview) on top of Unreal Engine. Android automatically puts `GameActivity` into `PlayerBase::pause()`. Unreal literally stopped rendering frames. Because our sampler was hardcoded to only look for `GameActivity`, it reported the paused surface as a 0 FPS crash.
* **The Fix**: We updated `GameFrameTelemetrySampler` to detect `MobileFREWebViewActivity`. When active, it returns `.unavailable(.loginPromptActive)` and the HUD displays `TFT LOGIN (IDLE)`, keeping the database free of false degradation records.

### C. Host vs. Guest Causal Attributions (`PipelineEventV1` & Timelines)
* **The Mystery**: When frame drops occurred during 8-player combat, was the bottleneck in QEMU's ASG decoder, the Vulkan driver, MoltenVK translation, or the Apple M4 Metal GPU?
* **How We Discovered the Solution**:
  1. We designed `PipelineEventV1`: an exact 96-byte C++ binary event structure with SHA-256 segment chaining.
  2. We instrumented `gfxstream-backend` and `MoltenVK` using Vulkan 64-bit timeline semaphores (`VK_KHR_timeline_semaphore`).
  3. In live run `causal-hook-timeline-20260903-r6`, across 99,480 events and 10,796 frames, total host graphics latency averaged **0.792 ms mean (<5% of a 16.67 ms frame)**:
     * ASG Decode $\to$ MoltenVK Entry: `0.004 ms`
     * Host Submit (Site 1002): `0.019 ms`
     * MoltenVK Translation (Site 2003): `0.106 ms`
     * Metal GPU Execution (Site 2005): `0.683 ms`
  4. **Bounded finding**: that instrumented span measured low host graphics latency for the sampled work and shifted suspicion upstream. It did **not** prove that 100% of all combat latency is guest shader compilation or disk I/O across every current run.

### D. The Observer Effect Trap
* **The Mystery**: Early automated telemetry runs suffered worse combat stuttering than unmonitored runs.
* **Historical profiling finding**: one earlier 6-vCPU match generated **4,253 child processes** from aggressive polling and also used a bounded Perfetto/ftrace capture. That combination was considered intrusive and was removed from the preferred measurement path. Do not generalize it as proof that tracing always completely starves RHIThread/AudioFlinger; current profiling must remain bounded.
* **The Fix**: We restricted `dumpsys SurfaceFlinger --list` to run only when the active layer is lost or reports 0 frames, cached `currentGamePID`, and disabled automatic Perfetto dumps during normal interactive play (`TFTMAC_ENABLE_AUTO_PERFETTO=1` required).

### E. Apple Silicon M4 CPU/GPU Routing & Thread Allocation Architecture
* **Hardware boundary**: the Apple M4 Mac mini has 10 CPU cores (4 performance + 6 efficiency) and 10 GPU cores sharing unified memory. This project does not treat fixed P/E-core MHz values as an authoritative runtime fact because macOS dynamically manages frequency.
* **GPU scheduling boundary**: the Android guest does not directly allocate physical M4 GPU cores. The current path ultimately submits work to Metal, and macOS/Metal own GPU scheduling. A prior bounded instrumented sample measured about 0.68 ms of Metal GPU work for its sampled frames; that does not prove every 1080p frame finishes in 0.68 ms or that every workload continuously occupies all 10 GPU cores.
* **CPU/quality tuning history**:
  * Current DEV uses **8 vCPUs**, not 6. vCPU count does not dedicate or reserve physical host cores; it changes the guest scheduler's available virtual CPUs.
  * PSO worker-count experiments can reduce or increase contention, but a worker count does not permanently reserve vCPUs for GameThread/RHIThread and cannot be claimed to eliminate context-switch starvation without a matched result.
  * Dynamic-resolution floors can trade image quality for load shedding when enabled, but no setting guarantees uninterrupted 60 FPS. Any such change requires its own verified DEV comparison.
  * Cloth physics (`p.ClothPhysics=1`) is confirmed safe: with a realistic match ceiling of $\le 30$ active units on screen, cloth simulation consumes only $\sim 0.5\text{ ms}$ of `GameThread` time (<3% of frame budget).
### F. Dormant ActivityRecord Leashes & Damage-Driven PIPE Telemetry Truth
* **The Dormant Leash Trap**: When an Android sub-activity (e.g., Riot's `MobileFREWebViewActivity` webview login) finishes and is dismissed, WindowManager destroys the window (`WIN DEATH`), but SurfaceFlinger retains a dormant parent leash layer in the layer hierarchy:
  `Surface(name=ActivityRecord{...MobileFREWebViewActivity})`.
  A naive substring match (`output.contains(tftMobileFREActivity)`) permanently flags the runtime as `.loginPromptActive`, blinding the telemetry sampler from ever hooking back onto the active `SurfaceView[...GameActivity](BLAST)` layer.
  * **The Solution**: `GameFrameTelemetry.hasActiveLoginPrompt(in:)` explicitly ignores `ActivityRecord` leashes and `SnapshotStartingWindow` layers. Only genuine, non-leash window layers trigger the login prompt state.
* **Damage-Driven gRPC Frame Streaming**: QEMU's gRPC `streamScreenshot` is **damage-driven by design**. When an on-screen interface is static (e.g., waiting on user credentials or during a process stall), Android marks 0 dirty rectangles and gRPC delivers 0 frames (`source_fps = 0.0`). This is normal power-saving guest compositor behavior, not a graphics rendering bottleneck.
* **Process Priority Maintenance Across PID Restarts**: when the game PID changes, the runtime can reapply its configured nice-priority request. This preserves the requested scheduling preference; it is not a guarantee of Linux real-time scheduling.

### G. 32-Minute Combat Match Forensics, Memory Audit & 8-vCPU DEV Routing
* **Match Forensic Analysis (`2026-09-04T17-50-10.043Z`, 892 Windows / ~32 Minutes)**:
  * **Overall Average FPS**: **55.80 FPS** (58.6% of all sample windows ran at flat 58–61 FPS).
  * **Planning / Shopping Phases**: Consistently locked at **58.6–59.8 FPS**, frame times 17.3–18.4 ms, guest CPU load ~320%.
  * **Combat Drops**: During large late-game combat rounds (16–22+ moving champions casting spells), CPU load surged to **380%–510%**, stretching frame times to 25–31 ms and pulling frame rates down into the **45–53 FPS** range (1% low: 33.27 FPS).
* **Definitive Memory Audit (Host vs. Guest)**:
  * **Guest Android RAM (5,120 MB)**: Android consumed only ~3.2 GB out of 5.1 GB. Available memory averaged **1,705 MB** (minimum 1,533 MB). Zero LowMemoryKiller events occurred; Android had >1.5 GB of free headroom at all times.
  * **macOS Host RAM (16 GB Unified)**: Available host RAM was **2,938 MB average** (min 2,620 MB) with 7.2 GB compressed and 1.7 GB swap.
  * **Historical memory finding**: this 5,120-MiB match had adequate guest headroom and showed host compression/swap. It supports avoiding an unproven jump to 8 GiB, but it does not make 5,120 MiB an eternal 'exact sweet spot.' Current verified DEV uses **6144 MiB**, which is the authoritative working value unless a later measured candidate changes it.
* **The current 8-vCPU DEV allocation**:
  * Current DEV launches are verified at `-cores 8`. This provides eight guest vCPUs while host scheduling remains macOS/Hypervisor-owned; it does **not** create two dedicated physical host cores or prove GameThread/RHIThread are unconstrained.
* **Historical Unreal combat optimizations**:
  * `p.ClothPhysics=0`: Disables CPU vertex cloth simulation on 20–30 combat units, reclaiming 5–8 ms of GameThread frame budget.
  * `r.DynamicRes.OperationMode=1`: Activates the Dynamic Resolution master switch with an 85% safety floor (`r.DynamicRes.MinScreenPercentage=85`) and 16.67 ms budget (`r.DynamicRes.FrameTimeBudget=16.666666`).
  * `r.pso.PrecompileThreadPoolSize=2`: Restricts PSO precompile threads to 2, preventing worker threads from swamping vCPUs during combat.
* **Clean Snapshot Teardown**:
   * In `TFTMACRuntime.swift -> stop()`, issuing `am force-stop com.riotgames.league.teamfighttactics` 300 ms before `adb emu kill` closes active Vulkan swapchains and device instances, eliminating QEMU's `UNSUPPORTED_VK_APP` snapshot save failure and enabling 2–3 second fast snapshot resumes on subsequent boots.
