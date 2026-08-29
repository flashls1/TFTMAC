# TFTMAC GPU Runtime v2.0 — Phase 0 Remediation Inventory

This file is evidence and execution guidance only. It does not supersede `TFTMAC_GPU_RUNTIME_SSOT.md`, `TFTMAC_FULL_IMPLEMENTATION_PLAN.md`, or `STACK.lock.yaml`.

## Authority state

- Revised SSOT and implementation plan were reviewed together as one coupled authority set.
- ZenGate v2.3 hard gates are clear; calculated result: Q=98, R=5, Z=93 => PASS.
- Exact approved input hashes are frozen in `ssot/AUTHORITY_INPUTS.sha256`.
- Canonical authority files must be present in the repository under the names in that hash file before Phase 0 can PASS.

## Current base

- GitHub authority base: `1d8f681336a5d4f2f5b93fddacb8ce822cc099c5`.
- Managed implementation change was rebased onto that exact `origin/master` before Phase 0 repository writes.

## Confirmed Phase 0 observations

### Host

- Architecture: arm64 — PASS.
- Hardware: Apple M4 Mac mini — PASS.
- macOS: 26.6.2 (25G83) — observed.
- Active Xcode: 26.4 / 17E192 — FAIL against frozen Xcode 26.6 / 17F113 requirement.
- `/Applications` discovery found no Xcode 26.6 installation at observation time.

### Android command-line tools

- `commandlinetools-mac_arm64-15859902_latest.zip` downloaded to the canonical TFTMAC Application Support root.
- SHA-256 verified: `835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e` — PASS.
- Android SDK package installation is blocked pending explicit Android SDK license acceptance evidence; bootstrap intentionally refuses to auto-accept terms.

### Vulkan SDK

- `vulkaninfo` not found in active SDK or standard paths.
- Frozen required SDK remains Vulkan SDK 1.4.357.0 with SHA-256 `539433589c83522e6f31b1c7b418a4167e21597a4a361ab119e1dc0760cf3865`.

### AEMU source freeze

- `emu-master-dev` repo initialization began successfully.
- First `repo sync -c -j8` failed because the internal user volume ran out of free space while packing AEMU prebuilts.
- Failure was storage-only; no source-authority contradiction was observed.
- The v2 tooling now uses `/Volumes/MAC MINI M4/TFTMAC/Build` as the default build/source root instead of the internal Application Support `Build` directory.
- `TFTMAC_BUILD_ROOT` may override that path explicitly for portability.
- When the default external volume is unavailable, the tooling fails closed instead of silently recreating the large build tree on the internal disk.
- Migrate the existing partial internal `Build` tree to the external build root intact, verify it, then resume the same frozen sync. Do not use an Xcode/Developer-directory symlink, do not discard the partial AEMU checkout, do not switch branches, and do not substitute `emu-main-dev`.

## Legacy implementation quarantine

Current `master` predates the v2.0 authority and is donor/legacy evidence, not acceptance proof.

Observed conflicts that must be removed or replaced only after Phase 0 PASS:

- production path is Android 16 / API 36;
- AVD names include `TftLiveStore` and `TftHighEndTablet` instead of `TFTMAC_Live_API37`;
- Swift launcher "Enhanced" mode injects `androidboot.opengles.version=196610`;
- documentation labels `196610` as OpenGL ES 3.2 capability;
- legacy architecture centers `LiveNativeAdapter` / future `UnrealEnhancedAdapter`, while v2.0 freezes one Android 17 built-in-ANGLE/gfxstream/AEMU/MoltenVK architecture with custom ANGLE only as a conditional Phase 5 repair adapter.

None of those legacy claims may satisfy a v2.0 gate.

## Phase 0 open loops

1. Install/select Xcode 26.6 / 17F113 and rerun host preflight.
2. Migrate the existing internal TFTMAC `Build` tree to `/Volumes/MAC MINI M4/TFTMAC/Build`, verify it, remove the verified internal duplicate, and resume the same `emu-master-dev` resolved-manifest sync from the external build root.
3. Complete Android SDK license acceptance, then install/freeze exact API 37 package revisions and create `TFTMAC_Live_API37`.
4. Install/verify Vulkan SDK 1.4.357.0 and capture `vulkaninfo --summary`.
5. Complete resolved AEMU manifest; freeze qemu/aemu/gfxstream/ANGLE/MoltenVK commits and GuestAngle source audit.
6. Freeze MoltenVK v1.4.2 reference commit.
7. Resolve full `opengl-es-cts-3.2.14.1` commit.
8. Generate exact `ssot/vulkan-required-cases.txt` from the pinned CTS tree and dependency map; hash it. Do not remove failing cases later.
9. Materialize the two approved authority documents under canonical repository names and verify their SHA-256 values.
10. Generate `ssot/preflight-report.md`; Phase 0 can pass only when every critical null is resolved.

No Phase 1+ graphics mutation is authorized while any item above remains unresolved.
