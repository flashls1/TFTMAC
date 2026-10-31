# TFTMAC GPU Runtime SSOT

**Status:** CURRENT OPERATING RUNTIME SSOT & EVIDENCE REGISTER  
**Reconciled:** 2026-10-27  
**Project:** TFTMAC  
**Primary Execution Authority:** [`improvements.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/improvements.md) (and [`implementation.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/implementation.md))

> [!IMPORTANT]
> **Stale Document Notice:** Historical receipts, pre-18.3 notes, and September 2026 documentation across `docs/` and `TFTDEV-SSOT/` are **historical provenance only**. They are not current operating authority. All forward progress, empirical measurements, and hypothesis testing are tracked exclusively in [`improvements.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/improvements.md).

---

## 1. Protected Production Baseline (INV-01)

- **Target App:** [`/Users/flash/Desktop/TFT Ranked.app`](file:///Users/flash/Desktop/TFT%20Ranked.app)
- **Protected Core SHA-256:** `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`
- **Invariant Policy:** **READ ONLY.** Never modify, overwrite, or re-sign [`TFT Ranked.app`](file:///Users/flash/Desktop/TFT%20Ranked.app). It serves as the immutable ground-truth baseline.

---

## 2. Active Optimization Target: TFT TURBO

- **Application Bundle:** [`/Users/flash/Desktop/TFT TURBO.app`](file:///Users/flash/Desktop/TFT%20TURBO.app)
- **Bundle Identifier:** `com.flashls1.tftmac.dev`
- **Build Script:** `python3 scripts/build-turbo-app.py`
- **Runtime Mode:** `advanced_diagnostics`
- **Host Hardware:** Apple Mac mini (`Mac18,5`, Apple M6 SoC: 12 Cores [2 Super + 4 Performance + 6 Efficiency], 12-Core GPU [Metal 4], 16 GB Unified Memory).
- **Hardware Authority Notice:** The active platform is Apple's M6. The older M4 Mac mini is obsolete historical hardware. The path `/Volumes/MAC MINI M4` is strictly a legacy external USB drive volume label.
- **Hardware Profile:** 8 vCPU, 6144 MiB RAM, host GPU, CoreAudio, 1920x1080 @ 60 Hz display.
- **RHI Path:** Unreal Engine 4.27 Mobile $\rightarrow$ OpenGL ES 3.2 $\rightarrow$ ANGLE Vulkan $\rightarrow$ gfxstream / virtio-gpu $\rightarrow$ Host MoltenVK $\rightarrow$ Metal 4 on Apple M6 12-Core GPU.

---

## 3. Active & Proven Optimization Levers (Current Truth)

### Lever 1: ASG Virtio-GPU Transport Batching (**PROVEN WIN — ACTIVE**)
- **Locked Active Parameters in TFT TURBO:**
  - `hw.gltransport=virtio-gpu-asg`
  - `hw.gltransport.asg.dataRingSize=262144` (**256 KB**)
  - `hw.gltransport.asg.writeStepSize=65536` (**64 KB**)
  - `hw.gltransport.asg.writeBufferSize=1048576` (**1 MB**)
  - `hw.gltransport.drawFlushInterval=2000` (**2.0 ms** batch window)
- **Hard Memory Aperture Bound:**
  - In QEMU's `AddressSpaceGraphicsContext`, the guest kernel PCI driver enforces a maximum aperture of 2.0 MB:
    $$\text{asgDataRingSize} + \text{asgWriteBufferSize} + 12\text{ KB} \le 2\text{ MB}$$
  - The current 256 KB ring + 1 MB write buffer consumes 1.29 MB, safely fitting within the aperture.
- **Empirical Match 8 & 10 Results (vs. Match 7 Baseline):**
  - **Severe Hitch Rate ($p99 \ge 100$ ms):** Reduced from **4.81%** to **3.19%** (-33.7% project record low).
  - **RHIThread CPU:** Reduced from **87.42%** to **71.22%** (-16.20% absolute drop).
  - **Host Emulator CPU:** Reduced from **275.47%** to **234.27%** (-41.20% CPU saved on macOS host).
  - **Zero-Bottleneck Time within 60 FPS:** Tripled from **13.0%** to **36.5%**.
  - **Jank Frequency:** Reduced by **23.2%** (from 10.3 to 7.91 jank/window).
  - **Average Effective FPS:** Increased from **50.34** to **52.38 FPS**.
- **Status:** **PERMANENTLY PROVEN & LOCKED IN.**

---

## 4. Evaluated & Rejected Candidates (Do Not Resurrect)

### Lever 2: In-Driver `block-cache-candidate` Buffer View Cache (**REJECTED**)
- **Candidate Tested:** `block-cache-candidate` (`libGLESv2_angle.so` SHA `c4467dffd7475dd0c1b011707e68bd7e480465eb20cdbbdc0c626873c7b90ad0`).
- **Match 9 Empirical Measurement:**
  - Average FPS collapsed to **47.25 FPS** (-5.13 FPS regression).
  - RHIThread CPU spiked to **89.32%** (+18.10% regression).
  - Host CPU overloaded to **291.52%** (+57.25% regression).
  - Jank surged to **14.00 jank/window** (+77% increase).
- **Causal Defect:**
  1. `BufferBlock::getTFTMACCachedView` acquired a mutex-locked `std::map` on the hot path for every buffer lookup.
  2. Rigid 2,048-resident cap with no LRU eviction saturated early in the match, converting every call into lock contention + map traversal miss + fallback creation.
  3. `mHasTFTMACBorrowedViews` forced descriptor serial invalidation upon helper release, multiplying descriptor set rebinding churn on the Vulkan submit thread.
- **Status:** **REJECTED FOR PERFORMANCE; ROLLED BACK TO STOCK ANGLE.**

---

## 5. Next Staged Candidates

1. **Host-Side Vulkan/Metal Pipeline Cache (`VkPipelineCache`):**
   - Retain host Metal PSOs persistently across runs so MoltenVK never pauses execution on dynamic spell effects.
2. **Unreal Dynamic Mesh Batching CVars:**
   - Configure Unreal Engine's `DeviceProfiles.ini` to batch draw calls (`r.MeshDrawCommands.DynamicInstancing=1`), reducing raw buffer descriptor updates sent to the driver.
