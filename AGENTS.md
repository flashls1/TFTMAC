# AGENTS.md — AI Coding Agent Operating Briefing & Architecture Guide

**Current as of:** October 2026  
**Host Target:** Apple Mac mini (`Mac18,5`, Apple M6 SoC: 12 Cores [2 Super + 4 Performance + 6 Efficiency], Metal 4, 16 GB Unified Memory)  
**Operating Target:** `/Users/flash/Desktop/TFT TURBO.app`  
**Protected Invariant (INV-01):** `/Users/flash/Desktop/TFT Ranked.app` (SHA-256: `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`)  
**Tracking Ledger:** [`improvements.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/improvements.md) (Symlink: `implementation.md`)  
**Build Protocol:** [`BUILD_PROTOCOL.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/BUILD_PROTOCOL.md)  
**Verification Runner:** [`scripts/verify-turbo-build.command`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/scripts/verify-turbo-build.command)

---

## 1. Grounding & Purpose

You are operating in the **TFTMAC** codebase. This project provides a customized, high-performance macOS native container and Android diagnostic runtime for playing Riot Games' **Teamfight Tactics (TFT)** at 60 FPS on Apple Silicon.

As an AI coding agent, you must balance **speed with thoroughness**. Rushing changes without running build verification has caused severe regressions in the past. To ensure quality and prevent regressions, you must follow the strict protocols documented here.

---

## 2. Critical Invariants & Hardware Ground Truth

### Invariant INV-01: Protected Ground Truth App
- Location: `/Users/flash/Desktop/TFT Ranked.app`
- Core SHA-256: `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`
- **Rule:** This application is immutable ground truth. **NEVER modify, delete, move, or overwrite it.**

### Hardware Authority: Host Machine is Apple M6
- The physical host running this code is an **Apple M6 Mac mini** (`Mac18,5`, 12 CPU cores, Metal 4 GPU, 16 GB RAM).
- Notice: `/Volumes/MAC MINI M4` is merely an external USB drive volume label from an older machine. It does **not** reflect host architecture or CPU capabilities.

---

## 3. The 9 Pre-Delivery Build Quality Gates

Before declaring any build or task complete, all 9 gates must pass:

```
+-----------------------------------------------------------------------------------+
|                            THE 9 BUILD QUALITY GATES                              |
+-------+----------------------------------+----------------------------------------+
| Gate  | Check Item                       | Verification Method                    |
+-------+----------------------------------+----------------------------------------+
| G-01  | Protected Invariant (INV-01)     | Core SHA-256 == 00566b69d805b544...    |
| G-02  | Stable Code Signing Identity     | Signed with 'TFTMAC Local Code Signing'|
| G-03  | Strict Deep Code Signature       | codesign --verify --deep --strict == 0 |
| G-04  | Yellow TURBO Banner Icon         | TFTMAC-TURBO.icns MD5 verified         |
| G-05  | Declared TCC Entitlement         | NSRemovableVolumesUsageDescription in  |
|       |                                  | Info.plist                             |
| G-06  | Audio Subsystem Health           | 2048 frame buffer (682ms), boot restart|
|       |                                  | audioserver, mid-game root guarded     |
| G-07  | Host CPU & Daemons               | 8 vCPUs; 0 remote compiler daemons     |
| G-08  | Native Unit Test Suite           | All 135 XCTest tests pass (0 failures) |
| G-09  | DEV HighPerf Asset Integrity     | 4-way hash sync (INI, SH, Swift, App)  |
+-------+----------------------------------+----------------------------------------+
```

Automated verification command:
```bash
/bin/zsh scripts/verify-turbo-build.command
```

---

## 4. Strict Non-Negotiable Anti-Regression Rules

### Rule 1: Code Signing Discipline (No Ad-Hoc `-`)
- **NEVER** use `codesign -s -` (ad-hoc signing).
- Ad-hoc signing generates a dynamic cdhash on every rebuild, invalidating macOS TCC entitlements and popping up permission dialogs for local network and file access.
- **ALWAYS** sign with identity: `"TFTMAC Local Code Signing"`.

### Rule 2: TCC Removable Volume Entitlements (Never Strip)
- **NEVER** remove `NSRemovableVolumesUsageDescription` from `Info.plist`.
- Stripping this string causes macOS 15+ to trigger "Files and Folders" permission popups when background processes (`adb`, `lsof`) inspect volume mounts.
- Keep value: `"TFTMAC DEV uses the isolated Android diagnostic runtime stored on MAC MINI M4."`

### Rule 3: HighPerf Asset Hash Synchronization
The splash curtain validates SHA-256 hashes of all 4 HighPerf assets at startup (`TFTMACRuntime.swift:highPerfHashes`). If you modify `DeviceProfiles.ini`:
1. Calculate its new SHA-256: `shasum -a 256 tftmac/Assets/DEVHighPerf/DeviceProfiles.ini`
2. Update `control_expected=<NEW_HASH>` in `tftmac/Assets/DEVHighPerf/profile-transaction.sh`.
3. Calculate new SHA-256 of `profile-transaction.sh`.
4. Update `Self.highPerfHashes` in `tftmac/Runtime/TFTMACRuntime.swift`.
5. Run unit tests (`scripts/test-native-app.command`) to ensure `testDEVHighPerfAssetsMatchRuntimeReceiptsAndTransactionAuthority` passes.

### Rule 4: Host Scheduling & vCPUs (Keep 8)
- **NEVER** reduce guest vCPUs below 8.
- The M6 host has 12 CPU cores. Restricting guest vCPUs causes virtio-gpu interrupts to starve Unreal Engine worker threads, collapsing frame rates to 8–13 FPS.

### Rule 5: Audio Protection & Zero Disconnects
- Keep QEMU CoreAudio buffer set to 2048 frames × 16 buffers (682 ms headroom) at 48,000 Hz.
- Pre-warm `audioserver` at boot in `establishGuestAudioSubsystem`.
- **NEVER** restart `audioserver` or run `adbd root` during active gameplay (`recoverGuestPCMOutput` is guarded by `currentExactLayerName == nil`). Toggling root resets Android `wlan0` Wi-Fi and disconnects the player from the live ranked match.

### Rule 6: Yellow TURBO Banner Icon
- Ensure `TFTMAC-TURBO.icns` is copied to both `TFTMAC-TURBO.icns` and `TFTMAC-DEV.icns` in `Contents/Resources`.
- Register with LaunchServices (`lsregister -f`) and refresh Finder so the desktop displays the yellow banner immediately.

---

## 5. Canonical Build & Verification Workflow

To rebuild and verify `TFT TURBO.app`:
```bash
# 1. cd to workspace root
cd "/Volumes/MAC MINI M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe"

# 2. Package and verify (compiles core, stub, signs, and executes 9-gate verification)
python3 scripts/build-turbo-app.py
```

---

## 6. Durable Tracking Ledger

Every modification, test result, and architectural finding must be logged in [`improvements.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/improvements.md):
- **Section 1:** Current Performance Metrics & Delta Table
- **Section 2:** Hypothesis Register & Verification Ledger
- **Section 3:** Invariant Register (INV-01 through INV-04)
- **Section 4:** Action Log (chronological timestamps with `[BEFORE]` / `[AFTER]` evidence)
- **Section 5:** Pre-Delivery Build Quality Gate receipts
