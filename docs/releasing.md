# Releasing TFTMAC

TFTMAC releases are native macOS application builds. The release process does not publish or redistribute Riot application packages.

## Release identity

```text
Application: TFTMAC
Bundle ID: com.flashls1.tftmac
Architecture: arm64
Minimum macOS: 15.0
```

The working Android SDK/AVD is runtime state outside the application bundle and repository.

## Pre-release validation

Run on the exact release commit:

```sh
/bin/zsh scripts/verify-tftmac.command
```

Also verify that the frozen EmulatorController protocol still matches the intended stock emulator authority and that no private runtime artifacts are tracked.

## Package authority

The application does not package or publish TFT APKs. The supported Android package is `com.riotgames.league.teamfighttactics`, installed and updated through `com.android.vending`. Riot owns its own content initialization after launch.

## Signing

Local development builds are ad-hoc signed. A public distribution may later use the project's Apple Developer identity, hardened runtime, notarization, and stapling through a separately approved release configuration. Credentials and signing secrets never belong in Git.

## Release evidence

Retain compact evidence for:

- exact source commit;
- native build/test result;
- bundle identity;
- stock emulator/protocol authority;
- package/installer identity when runtime acceptance is part of the release;
- acceptance result and rollback state.

Do not retain giant generated build trees as release authority.
