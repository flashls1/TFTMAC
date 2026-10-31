# TFTMAC Build & Anti-Regression Doctrine (Workspace Rule)

Current as of October 2026.

This workspace rule governs all agent sessions operating on the **TFTMAC** codebase. Agents must prioritize thoroughness, verification, and regression prevention over raw speed.

---

## 1. Golden Invariant (INV-01)
- `/Users/flash/Desktop/TFT Ranked.app` (SHA-256: `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`) is an immutable ground truth.
- **NEVER** modify, re-sign, move, or overwrite `TFT Ranked.app`.

---

## 2. The 9 Pre-Delivery Build Quality Gates
No build may be delivered to `/Users/flash/Desktop/TFT TURBO.app` and claimed complete until **all 9 Gates pass**:

1. **G-01 (INV-01 Protected):** Core SHA-256 == `00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee`.
2. **G-02 (Stable Signing):** Signed with `"TFTMAC Local Code Signing"` (never ad-hoc `-`).
3. **G-03 (Strict Deep Codesign):** `codesign --verify --deep --strict` exits 0.
4. **G-04 (Yellow TURBO Icon):** `TFTMAC-TURBO.icns` MD5 == `a8f93ea0c9770af6c0a53d6a8bee57d7`.
5. **G-05 (Declared TCC):** `NSRemovableVolumesUsageDescription` preserved in `Info.plist`.
6. **G-06 (Audio Subsystem):** 2048-frame CoreAudio buffer (682 ms), boot `audioserver` pre-warm, mid-game root guarded.
7. **G-07 (Host CPU & Daemons):** 8 vCPUs (`RankedLauncher/main.c`); remote compiler daemons suppressed in `DeviceProfiles.ini`.
8. **G-08 (Native Tests):** All 135 XCTest unit tests pass with 0 failures (`scripts/test-native-app.command`).
9. **G-09 (Asset Integrity):** 4-way cryptographic hash synchronization across `DeviceProfiles.ini`, `profile-transaction.sh`, `TFTMACRuntime.swift`, and deployed bundle.

Verification is executed via:
```bash
/bin/zsh scripts/verify-turbo-build.command
```

---

## 3. Strict Non-Negotiable Rules
- **NEVER use ad-hoc code signing (`-`):** It breaks TCC consent and triggers macOS permission prompts on launch.
- **NEVER strip `NSRemovableVolumesUsageDescription`:** macOS 15+ flags undeclared volume access without it.
- **NEVER modify `DeviceProfiles.ini` without synchronizing hashes:** Update `profile-transaction.sh`, `TFTMACRuntime.swift`, and run unit tests.
- **NEVER reduce vCPUs below 8:** Apple M6 requires 8 vCPUs to prevent virtio-gpu IRQs from starving Unreal Engine worker threads.
- **NEVER toggle root or restart `audioserver` mid-game:** It disconnects Wi-Fi (`wlan0`) during ranked matches.
- **ALWAYS log changes:** Update `improvements.md` (and `BUILD_PROTOCOL.md`) with timestamps, actions, reasons, and receipts before completing turns.
