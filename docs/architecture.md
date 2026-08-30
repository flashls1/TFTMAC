# TFTMAC Architecture

TFTMAC is a native macOS application controlling a known-good stock Google Android Emulator runtime.

## Product boundary

```text
TFTMAC.app
  -> AppKit application/window
  -> Metal presentation
  -> authenticated local EmulatorController client
  -> stock Google Android Emulator
  -> official Google Play ARM64 guest
  -> official TFT package
```

The runtime root is external to the repository so application source changes do not replace AVD userdata, Google Play state, Riot sign-in, or installed game data.

## Native application

`TFTMAC/App/` owns application lifecycle and the main window. `TFTMAC/Presentation/` owns the Metal presentation shell and viewport mapping. The source target is Apple Silicon and the application bundle identifier is `com.flashls1.tftmac`.

The presentation layer maintains the game aspect ratio and maps native viewport coordinates into the 1920x1080 Android source coordinate space while rejecting input in letterbox regions.

## Emulator control

TFTMAC uses the exact EmulatorController protocol shipped by the installed stock emulator. The protocol snapshot and provenance live under `Vendor/AndroidEmulator/`. Production control must be authenticated and local; an unauthenticated fixed gRPC control endpoint is not an accepted architecture.

## Android/package authority

The normal guest is an official Google Play ARM64 image. TFT application installation and updates are owned by Google Play. Riot's application owns Riot authentication and content initialization.

TFTMAC does not mirror, bundle, patch, re-sign, or privately update Riot binaries.

## Runtime storage

Bulk runtime state is outside Git under `/Volumes/MAC MINI M4/TFTMAC/Runtime`. Repository source contains only code, tests, protocol snapshots, compact evidence, and configuration that is safe to version.

The abandoned source-built emulator development tree is not part of the normal product architecture and is eligible for controlled reclamation after independence checks pass.

## Diagnostics

Raw runtime telemetry is captured append-only, then normalized for analysis. Measurements identify the first boundary where behavior changes from PASS to FAIL. Performance changes are one-variable, reversible A/B experiments with explicit KEEP/REJECT decisions.

## Failure boundaries

TFTMAC fails closed when the expected runtime, protocol authority, package identity, installer authority, or protected external storage is missing or inconsistent. Unknown effects are not replayed blindly. User-required Google/Riot authentication is surfaced through official UI rather than automated around.
