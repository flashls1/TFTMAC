# Changelog

## Unreleased

### Changed

- Established TFTMAC as the sole product and repository identity.
- Replaced legacy validation with the native TFTMAC build/test verifier.
- Preserved the proven native AppKit/Metal Gate 1 implementation and frozen installed EmulatorController protocol.
- Removed obsolete launcher, hosted update/feed, helper-host, and branding layers.
- Moved runtime authority to the stock Google Android Emulator and official Google Play TFT lifecycle.
- Began relational migration of retained performance evidence to TFTMAC-owned identifiers.
- Retired source-built emulator work from the normal product path.

### Current target

- Native macOS application bundle: `com.flashls1.tftmac`.
- Stock Android Emulator 37.1.11.
- Official Google Play package `com.riotgames.league.teamfighttactics`.
- 1920x1080 / 60 Hz target on Apple Silicon.
