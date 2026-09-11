# TFTMAC

TFTMAC is a native macOS application for running the official Android Teamfight Tactics client on Apple Silicon through Google's stock Android Emulator.

## Current architecture

```text
TFTMAC.app
  -> AppKit window
  -> Metal presentation layer
  -> authenticated local EmulatorController
  -> stock Google Android Emulator
  -> official Google Play ARM64 guest
  -> official Google Play TFT package
  -> Riot authentication and content lifecycle
```

The product does not bundle, mirror, patch, re-sign, or privately update Riot binaries. Google Play is the installation/update authority for the Android application, and Riot's application owns its own content initialization.

## Runtime authority

Current DEV optimization authority and protected Control are intentionally separate:

```text
DEV:     /Applications/TFTMAC DEV.app
         /Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow
         1920x1080 / 60 Hz / 8 vCPU / 6144 MiB
         ADB 5041 / console 5586 / controller 8556
         current winner DEV-B8-WIN-01

Control: /Applications/TFTMAC.app
         /Volumes/MAC MINI M4/TFTMAC/Runtime
         protected historical/playable rollback authority
```

The stock emulator authority is Android Emulator 37.1.11. Current DEV test receipts select OpenGL ES through ANGLE and use TFT `18.1-5423749` / `8423749`. The exact installed EmulatorController protocol is vendored at `Vendor/AndroidEmulator/emulator_controller.proto` with provenance in `Vendor/AndroidEmulator/SOURCE.json`.

The source-built emulator laboratory is not part of the normal product path.
`flashls1/tftmac-runtime@c8aa26e` is eligible only as an isolated,
non-comparable diagnostic source runtime for the planned causal logger.

## Current authority and handoff

Read in this order before planning or finalizing a change:

1. [`facts.md`](facts.md) — first project-specific factual/policy authority.
2. [`project.md`](project.md) — living current-state wiki; must agree with `facts.md`.
3. [`CHANGELOG.md`](CHANGELOG.md) — detailed DEV test/version ledger and integration decisions.
4. [`benchmark.md`](benchmark.md) and [`dev.md`](dev.md) — analysis/engineering contracts after reconciliation with the files above.

Dated handoffs such as `AGENT_HANDOFF_2026-09-06.md`, historical plans, benchmark records and machine-readable/reference SSOT files remain evidence but never silently override `facts.md`/`project.md`. If credible newer evidence conflicts, validate it, update the authority records first, then finalize the plan or change.

## Native build

Requirements:

- Apple Silicon Mac
- macOS 15 or later
- Xcode 26.6
- Node.js 24 for repository tooling
- `jq`, `ripgrep`, and zsh

Build:

```sh
/bin/zsh scripts/build-native-app.command
```

Test:

```sh
/bin/zsh scripts/test-native-app.command
```

Repository/CI validation (no installed app, private runtime, credentials, or
signing identity required):

```sh
/bin/zsh scripts/verify-tftmac.command
```

Local installed-app/runtime/signing validation:

```sh
/bin/zsh scripts/verify-installed-runtime.command
```

The latter currently reports the known missing local signing identity and
`CSSMERR_TP_NOT_TRUSTED`; it is intentionally not a CI dependency.

The native application bundle identifier is `com.flashls1.tftmac`.

## Runtime and package rules

TFTMAC preserves the known-good stock SDK and AVD. Runtime state, Google credentials, Riot credentials, Android userdata, APK bytes, tokens, and private session data are never committed to Git.

The supported package is:

```text
com.riotgames.league.teamfighttactics
```

Expected installer authority:

```text
com.android.vending
```

If Google Play or Riot requires authentication, MFA, consent, or CAPTCHA, TFTMAC surfaces the official UI for the user to complete that step.

## Performance and diagnostics

Performance work is evidence-driven. Build 8 automatically logs the TFT process/layer lifetime and has been live-verified. It proves exact gameplay cadence and degradation, but it does not yet name an internal graphics root. Source-level causal instrumentation is planned in an isolated diagnostic runtime, never by silently replacing the stock playable runtime.

The current target is 1920x1080 at 60 Hz. High graphics at a 60 FPS cap with Riot Performance Mode OFF is the accepted playable baseline. Ultra High and Riot Performance Mode Beta were rejected on the target M4 host because of severe lag and unacceptable combat tails.

## Project boundaries

- One active product: TFTMAC.
- One authoritative repository: `flashls1/TFTMAC`.
- No legacy launcher, hosted game feed, private update service, or donor branding belongs in the shipping tree.
- No source-built emulator checkout is required for normal build, launch, test, repair, or release.

## License and attribution

Repository source is provided under [LICENSE](LICENSE). Third-party software and platform components retain their own licenses and terms; see [NOTICE.md](NOTICE.md).

Teamfight Tactics, TFT, Riot Games, Google, Android, Apple, macOS, Metal, and related names belong to their respective owners. TFTMAC is an independent project and is not endorsed by Riot Games, Google, or Apple.
