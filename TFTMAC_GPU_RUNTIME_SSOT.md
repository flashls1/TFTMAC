# TFTMAC Runtime — Single Source of Truth

**Status:** CURRENT RUNTIME AUTHORITY  
**Updated:** 2026-08-30
**Project:** TFTMAC

## Current production/control runtime

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

The current native playable profile is `tftmac_5gb_native_v1` at 6 vCPU / 5120 MB, High graphics, 60 FPS, Performance OFF. Ultra High and Riot Performance Mode Beta are rejected configurations on the target M4 host because of severe lag and unacceptable combat tails. Build 7's `combat_latency_a` is a one-factor host-scheduling candidate layered over this exact control; it is launch-verified but not performance-promoted.

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

The known-good stock control currently uses host GPU acceleration through gfxstream, ANGLE/Vulkan and MoltenVK/Metal. The control profile exists to preserve the measured playable runtime while the native presentation/control path is completed. It is not a claim that every exposed graphics capability is independently conformant.

Performance changes remain one-variable, reversible A/B experiments with explicit KEEP/REJECT evidence. Raw capture remains append-only during measurement and is normalized after capture.

## Storage authority

Protected runtime state remains under `/Volumes/MAC MINI M4/TFTMAC/Runtime` and must not be deleted by build/storage cleanup. AVD userdata, Google/Riot credentials, tokens, APK bytes and private runtime disks are not repository assets.

The abandoned source-build laboratory is not runtime authority. Historical source-build findings may remain only as compact evidence; no current command or document may recreate that laboratory as part of normal operation.

## Validation

Current source validation is:

```sh
/bin/zsh scripts/verify-tftmac.command
```

Runtime acceptance additionally verifies the stock SDK/AVD, controller-protocol equality, official TFT package/installer authority, clean start/stop, and absence of dependency on the retired source-build tree.
