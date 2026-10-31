# TFT TURBO — Authoritative Build, Verification & Anti-Regression Protocol

## Successor branch supersession — TFT TURBO 2 / CP2

Both installed TURBO and Ranked apps are protected. The successor's build entrypoint now accepts only the exact new app path and exposes read-only --preflight. Non-preflight build is intentionally blocked until native runtime and candidate packaging integration; no environment flag may override it. The verifier requires --app for the exact candidate, never an implicit original, and --preflight does not run native tests or verify playback. Stable signing must fail closed; no ad-hoc fallback and no forced Finder restart.

Read ssot/turbo2-isolation.json and docs/TFT_TURBO_2_ISOLATION.md before later builds. The new native mode, credentials-preserving clone and live runtime do not exist yet. The 29 CP2 guard tests verify only isolation entry boundaries. Historical G-06 pattern checks below remain insufficient for runtime audio acceptance; CP6 must replace that assumption with actual PCM/audible evidence. Historical commands below are not authorization to build against the old app from the successor branch.

**Current as of:** October 2026  
**Host Target:** Apple Mac mini (`Mac18,5`, Apple M6 SoC: 12 Cores [2 Super + 4 Performance + 6 Efficiency], Metal 4, 16 GB Unified Memory)  
**Operating Target:** `/Users/flash/Desktop/TFT TURBO.app`  
**Protected Invariant (INV-01):** `/Users/flash/Desktop/TFT Ranked.app` (SHA-256: `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`)  
**Tracking Ledger:** [`improvements.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/improvements.md) (Symlink: `implementation.md`)

---

## 1. Executive Mandate for AI Coding Agents

Every AI coding agent operating in this repository **must strictly observe this protocol**. Blindly building or modifying code without running the full verification checklist has repeatedly introduced critical regressions (missing icon badges, broken audio, macOS permission popups, and asset hash check crashes).

> [!IMPORTANT]
> **The Golden Rule:** Never claim a task or build is "done" from compilation alone. Every build delivered to `/Users/flash/Desktop/TFT TURBO.app` must pass **all 9 Pre-Delivery Build Quality Gates** via `/bin/zsh scripts/verify-turbo-build.command`.

---

## 2. The 9 Pre-Delivery Build Quality Gates

| Gate | Check Item | Required Oracle | Automated Command |
| :--- | :--- | :--- | :--- |
| **G-01** | **Protected Invariant (INV-01)** | `TFT Ranked.app` Core SHA-256 == `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee` | `shasum -a 256 "/Users/flash/Desktop/TFT Ranked.app/Contents/MacOS/TFTMACDEVCore"` |
| **G-02** | **Stable Code Signing Identity** | Bundle & Mach-O signed with `TFTMAC Local Code Signing` (preserves TCC permissions) | `codesign -dvv "/Users/flash/Desktop/TFT TURBO.app" 2>&1 \| grep "Authority=TFTMAC Local Code Signing"` |
| **G-03** | **Strict Deep Code Signature** | Strict deep codesign verification passes with exit code 0 | `codesign --verify --deep --strict "/Users/flash/Desktop/TFT TURBO.app"` |
| **G-04** | **Yellow TURBO Banner Icon** | `TFTMAC-TURBO.icns` MD5 == `a8f93ea0c9770af6c0a53d6a8bee57d7`, registered in LaunchServices | `ls -la .../TFTMAC-TURBO.icns` + `lsregister -f` |
| **G-05** | **Declared TCC Entitlement** | `NSRemovableVolumesUsageDescription` present in `Info.plist` (matches Ranked.app) | `plutil -extract NSRemovableVolumesUsageDescription raw ".../Info.plist"` |
| **G-06** | **Audio Subsystem Health** | `audioserver` pre-warmed at boot; ALSA healthy; 682 ms buffer headroom; 0 mid-game root toggles | Proactive restart in `establishGuestAudioSubsystem`; `QEMU_COREAUDIO_BUFFER_SIZE=2048` |
| **G-07** | **Host CPU & Daemons** | `TFTMAC_DEV_VCPU = 8`; `NumRemoteProgramCompileServices = 0`; `PrecompileThreadPoolSize = 0` | `main.c:16` == 8; `DeviceProfiles.ini` daemons == 0 |
| **G-08** | **Native Unit Test Suite** | All 135 native XCTest tests pass with 0 failures | `zsh scripts/test-native-app.command` |
| **G-09** | **DEV HighPerf Asset Integrity** | On-disk asset SHA-256 == `highPerfHashes` in Swift == `profile-transaction.sh` `control_expected` | `testDEVHighPerfAssetsMatchRuntimeReceiptsAndTransactionAuthority` + `build-turbo-app.py` |

---

## 3. Strict Non-Negotiables & Anti-Regression Rules

### Rule 1: Code Signing Discipline
- **NEVER** use ad-hoc signing (`codesign -s -`) for `TFT TURBO.app`.
- Ad-hoc signing computes a new Mach-O `cdhash` on every rebuild, wiping out TCC consent in macOS and triggering repeated permission prompts for local network access and disk access.
- Always use the stable local identity: `"TFTMAC Local Code Signing"`.

### Rule 2: macOS TCC & Removable Volume Entitlements
- **NEVER** strip `NSRemovableVolumesUsageDescription` from `TFT TURBO.app/Contents/Info.plist`.
- Stripping this key does **not** stop macOS from checking disk access; instead, macOS treats background checks by child processes (`adb`, `lsof`) as an undeclared access attempt and pops up a generic system prompt for "Files and Folders / Removable Volumes".
- The key must remain: `"TFTMAC DEV uses the isolated Android diagnostic runtime stored on MAC MINI M4."`

### Rule 3: HighPerf Asset Hash Synchronization
The runtime performs a strict cryptographic integrity check on all 4 HighPerf assets in `tftmac/Assets/DEVHighPerf/` at startup curtain drop. If you edit `DeviceProfiles.ini` or any asset, you **must**:
1. Update `control_expected=<NEW_DEVICE_PROFILES_SHA256>` in `tftmac/Assets/DEVHighPerf/profile-transaction.sh`.
2. Compute the new SHA-256 of `profile-transaction.sh`.
3. Update `Self.highPerfHashes` in `tftmac/Runtime/TFTMACRuntime.swift`.
4. Run `zsh scripts/test-native-app.command` to verify `testDEVHighPerfAssetsMatchRuntimeReceiptsAndTransactionAuthority` passes.

### Rule 4: Host Scheduling & vCPU Allocation
- **NEVER** decrease guest vCPUs below 8.
- Apple M6 has 2 Super + 4 Performance + 6 Efficiency cores. Restricting the guest to 6 vCPUs causes virtio-gpu IRQs to monopolize CPU0, starving Unreal Engine's 7+ worker threads and collapsing FPS to 8–13. Keep `TFTMAC_DEV_VCPU = 8`.

### Rule 5: Audio Protection & Zero Disconnects
- Keep QEMU CoreAudio buffer set to 2048 frames × 16 buffers (**682.6 ms total headroom** at 48,000 Hz) to absorb transient CPU spikes.
- Pre-warm `audioserver` during guest boot (`establishGuestAudioSubsystem`).
- **NEVER** restart `audioserver` or toggle `adbd` root during active gameplay (`recoverGuestPCMOutput` is guarded by `currentExactLayerName == nil`). Doing so severs `wlan0` Wi-Fi and disconnects the ranked match.

### Rule 6: Desktop Icon Visibility
- Always copy `TFTMAC-TURBO.icns` to both `TFTMAC-TURBO.icns` and `TFTMAC-DEV.icns` in `Contents/Resources`.
- Always trigger `lsregister -f`, touch the bundle, and tell Finder to update so the yellow TURBO banner renders immediately on the Desktop.

---

## 4. Standard Rebuild Workflow

To rebuild and verify `TFT TURBO.app`:

```bash
# 1. Ensure you are in the worktree directory
cd "/Volumes/MAC MINI M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe"

# 2. Run the test suite first (validates unit logic and asset hashes)
/bin/zsh scripts/test-native-app.command

# 3. Assemble, package, and sign the application
/usr/bin/python3 scripts/build-turbo-app.py

# 4. Run the automated 9-gate quality verification
/bin/zsh scripts/verify-turbo-build.command
```

---

## 5. Change Tracking & Logging Obligation

Whenever a change is made:
1. Update [`improvements.md`](file:///Volumes/MAC%20MINI%20M4/Clara/Worktrees/flashls1--tftmac/tftmac--7fc8b225-88fb-4c19-9bda-1f7b4671f0fe/improvements.md) Section 4 (Action Log) with:
   - Timestamp
   - Phase (`[BEFORE]` or `[AFTER]`)
   - Action, Reason, and Outcome
2. Update Section 5 (Pre-Delivery Quality Gate) with the exact verification receipts.
3. If new hypotheses or architectural decisions are made, update Section 1 (Metrics) and Section 2 (Hypothesis Register).
