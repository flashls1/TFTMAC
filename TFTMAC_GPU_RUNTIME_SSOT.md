# TFTMAC Runtime Reference

**Status:** SUPPORTING RUNTIME REFERENCE — `facts.md` + `project.md` are current authority
**Reconciled:** 2026-09-10
**Project:** TFTMAC

## Protected production/Control runtime (historical/playable rollback)

TFTMAC uses the released Google Android Emulator already proven on the target Apple Silicon host. Source-built AEMU is retired from the normal product path and is not required for build, launch, test, repair, or release.

```text
Runtime root: /Volumes/MAC MINI M4/TFTMAC/Runtime
Android Emulator: 37.1.11.0 (build 15917651)
ADB server: donor port 5038
Emulator console: 5582
AVD: TFT_Ultra_Tablet
Guest image: official Google Play ARM64 image
Target display: 1920x1080 / 60 Hz
Package: com.riotgames.league.teamfighttactics
Installer/update authority: com.android.vending
```

The protected normal-play Control is historically `tftmac_5gb_native_v1` at 6 vCPU / 5120 MiB, High graphics, 60 FPS, Performance OFF. Those values describe Control/history, **not the current DEV optimization baseline**.

## Current DEV optimization runtime

```text
Application: /Applications/TFTMAC DEV.app / com.flashls1.tftmac.dev / 2.3.0 build 8
Runtime: /Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow
AVD: TFTMAC_Diagnostic_StockShadow_R1
ADB / console / controller: 5041 / 5586 / 8556
Display: 1920x1080 / 320 dpi / 60 Hz
Effective launch: 8 vCPU / 6144 MiB / host GPU / CoreAudio
Official TFT: 18.1-5423749 / 8423749
Selected RHI: OpenGL ES through ANGLE
Working winner: DEV-B8-WIN-01
```

The static StockShadow AVD restoration file remains 6 vCPU / 5120 MiB. Current source defaults `advanced_diagnostics` to 8 vCPU and retains the 6144-MiB locked DEV profile; live QEMU receipts prove `-cores 8 -memory 6144`. The static file is therefore restoration state, not the effective current DEV launch.

The launcher boundary is frozen: TFTMAC starts its packaged `TFTMAC Emulator Host.app` through `/usr/bin/open -n -W --env ... --args ...` in the logged-in user session. It does not directly spawn QEMU from a Node/service context and does not inject `ADB_VENDOR_KEYS`. The previous `5040/5592` direct-service identity is retained only in historical evidence as the ADB-authorization regression.

## EmulatorController authority

The native application uses the exact controller protocol shipped with the installed stock emulator.

```text
Installed: /Volumes/MAC MINI M4/TFTMAC/Runtime/SDK/emulator/lib/emulator_controller.proto
Vendored: Vendor/AndroidEmulator/emulator_controller.proto
SHA-256: 1d62c6bcad5f06621f90ec2bf26c661ba769ccd0f1416b5314d25a68e04eee5f
```

The installed and vendored bytes were reverified equal during Clean Ownership Gate 4. Protocol drift fails closed until intentionally refreshed from the installed runtime.

## Product architecture

```text
TFTMAC.app
  -> AppKit window
  -> Metal presentation
  -> authenticated local EmulatorController
  -> stock Google Android Emulator
  -> official Google Play ARM64 guest
  -> official Google Play TFT package
  -> Riot official authentication/content lifecycle
```

Google Play owns package installation and updates. Riot owns its own application authentication and content initialization. TFTMAC does not mirror, bundle, patch, re-sign, or privately update Riot binaries.

## Graphics/control evidence

Protected Control history includes lower-stack Vulkan evidence. **Current DEV engine-log authority selects OpenGL ES through ANGLE**, with ANGLE's Vulkan backend feeding gfxstream/ranchu and host Vulkan/MoltenVK/Metal. A generic classifier that observes Vulkan below ANGLE does not override the selected game RHI. Direct Unreal Vulkan was tested separately and is not promoted.

Build 8 automatic logging is live-verified and captures the TFT process/layer
lifetime without match markers. It can prove exact SurfaceFlinger degradation,
but it cannot yet name an internal graphics owner. Source-level instrumentation
is planned only in isolated `tftmac-runtime` commit `c8aa26e`, never as a
normal-play replacement or stock-performance comparison.

Performance changes remain one-variable, reversible A/B experiments with explicit KEEP/REJECT evidence. Raw capture remains append-only during measurement and is normalized after capture.

## Storage authority

Protected runtime state remains under `/Volumes/MAC MINI M4/TFTMAC/Runtime` and must not be deleted by build/storage cleanup. AVD userdata, Google/Riot credentials, tokens, APK bytes and private runtime disks are not repository assets.

The abandoned source-build laboratory is not runtime authority. Historical source-build findings may remain only as compact evidence; no current command or document may recreate that laboratory as part of normal operation.

## Validation

Repository/source validation, including an unsigned Release compile and all 43
native tests, is:

```sh
/bin/zsh scripts/verify-tftmac.command
```

Current-host installed/runtime/signing validation is deliberately separate:

```sh
/bin/zsh scripts/verify-installed-runtime.command
```

The 2026-08-31 host audit found a temporary local signing-trust failure. A later 2026-09-02 recheck restored the local `TFTMAC Local Code Signing` identity and recorded deep/strict verification PASS for Control and DEV. The older blocked audit remains historical evidence, not current signing status.
