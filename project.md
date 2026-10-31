# TFTMAC Project — Current State & Roadmap

## Current successor workstream — TFT TURBO 2, 2026-10-30

User authorized implementation with a mandatory stop at every numbered checkpoint. Current managed change: `fda4732b-70e6-45dd-97ca-cfc2b1f48c6c`; branch: `clara/tft-turbo-2-fda4732b`; source base: `0a18c7f707730a18072df2bd74f5920ca1f98f56`. The October source snapshot is `04a6ac9673e44714b4cf1524290a4f7cbc64023a`, with 482-file blob/mode parity proven. This is not stale September master.

CP1 source preservation is complete. Flash's continue authorized CP2 application/runtime isolation. A blocked identity descriptor and shared read-only guard now define the separate application/runtime, protect output paths and stop premature builds. Twenty-nine focused tooling tests passed, including real entrypoint rejection checks. Flash authorized CP3 by continuing. CP3's preflight/model are saved, but the tool-platform safety layer blocked the proposed migration-script write before any file copy or product change. CP3 remains blocked and unaccepted; see CP3_BLOCKED.json. Existing Control clone tooling was inspected but not run because it targets a different environment. CP4 has not started. No Turbo2 application has been built or installed; the existing TURBO and Ranked apps, SDK/AVD and Google/Riot account state are unchanged. Exact CP1/CP2 acceptance belongs to the corresponding receipts, not historical runtime PASS rows below.

Snapshot publication preserved all intended October source, tests, scripts, icons and history. The old checkout retains generated Python cache and rejected driver artifacts locally; neither was deleted or copied into the new source branch. Private build inputs remain outside Git.

Implemented CP2 protections: successor builder defaults only to TFT TURBO 2.app, refuses noncanonical/protected paths before seed reads or effects, has no ad-hoc signing fallback and passes its exact output to the verifier. Verifier requires the candidate --app and cannot silently validate TURBO1. Full build/verification is intentionally blocked pending native-mode and candidate-packaging integration, mapped in docs/TFT_TURBO_2_ISOLATION.md. Actual Keychain/login continuity remains unverified. Existing native source retains the audio defect; no emulator version or performance improvement is accepted by CP1/CP2.

The dated October29 sections below remain incumbent baseline/history. Current facts.md supersedes inaccurate Android API and CPU-percentage wording. Do not infer current audio health from historical static build verification.

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
