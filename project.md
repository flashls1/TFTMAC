# TFTMAC Project — Current State & Roadmap

**Status:** ACTIVE OPTIMIZATION & DECOUPLING PIPELINE  
**Updated:** 2026-10-29  
**Host Hardware:** Apple Mac mini (`Mac18,5`, Apple M6: 12 Cores [2 Super + 4 Performance + 6 Efficiency], 12-Core GPU [Metal 4], 16 GB Unified Memory)  
**Hardware Authority Notice:** The active platform is Apple's M6. The older M4 Mac mini was a prior inferior machine. The `/Volumes/MAC MINI M4` path is strictly an external USB drive volume label.  
**Active App Target:** [`/Users/flash/Desktop/TFT TURBO.app`](file:///Users/flash/Desktop/TFT%20TURBO.app)  
**Primary Execution Authority:** [`improvements.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/improvements.md) (and [`implementation.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/implementation.md))  
**Build & Verification Authority:** [`BUILD_PROTOCOL.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/BUILD_PROTOCOL.md) | [`AGENTS.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/AGENTS.md)

---

## 1. Proven Progress & Operating Winner

1. **Lever 1 — Transport Batching (ACTIVE WINNER):**
   - Expanded ASG virtio-gpu ring buffer from 32 KB to 256 KB.
   - Set 64 KB write steps and 2000 µs flush intervals.
   - Result: RHIThread CPU reduced by 16.20% (87.4% $\rightarrow$ 71.2%), Host CPU reduced by 41.2% (275.5% $\rightarrow$ 234.3%), Zero-bottleneck 60 FPS gameplay tripled (13% $\rightarrow$ 36.5%), and jank cut by 23.2%.
2. **Pre-Flight Resilience & 9-Gate Quality Protocol:**
   - Hardened `startADBServer` with automatic socket clean and 3-attempt backoff retry loop.
   - All 135 XCTest unit tests verified passing (`0 failures`).
   - Deep codesigning strictly verified on `TFT TURBO.app` using stable identity `"TFTMAC Local Code Signing"`.
   - All 9 Pre-Delivery Build Quality Gates enforced via `scripts/verify-turbo-build.command`.
3. **Protected Baseline Invariant (INV-01):**
   - [`/Users/flash/Desktop/TFT Ranked.app`](file:///Users/flash/Desktop/TFT%20Ranked.app) is an immutable ground truth (`00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`) and is never modified.

---

## 2. Empirically Rejected Pathways (Do Not Resurrect)

1. **Guest Driver In-Memory Block Cache (`block-cache-candidate`):**
   - **Result:** Severe performance drop in Match 9 (FPS dropped to 47.25, RHIThread CPU regressed to 89.3%, host CPU spiked to 291.5%, jank surged by 77%).
   - **Root Cause:** Mutex lock contention on hot path, rapid 2,048-resident saturation without eviction (converting cache into pure overhead), and descriptor serial invalidation churn.
   - **Decision:** Permanently rejected and rolled back to Stock ANGLE.

---

## 3. Forward Decoupling Roadmap

- **Tier 1 (Complete):** Transport Batching (256 KB ring, 2.0 ms flushes).
- **Tier 2 (Under Investigation):** Decoupling buffer/mesh update frequency via Unreal Engine CVars (`r.MeshDrawCommands.DynamicInstancing=1`).
- **Tier 3 (Planned):** Host-Side Persistent Pipeline Cache (`VkPipelineCache`) to prevent MoltenVK Metal PSO compilation freezes.
- **Tier 4 (Planned):** Decoupled triple-buffered display presentation fences.
