# Building TFTMAC

## Requirements

- Apple Silicon Mac
- macOS 15 or later
- Xcode 26.6
- zsh
- Node.js 24
- `jq` and `ripgrep`

The working stock Android runtime is external to the repository and is not rebuilt during normal native application compilation.

## Build

```sh
/bin/zsh scripts/build-native-app.command
```

The Release application is produced under the ignored native build directory and copied to `dist/TFTMAC.app` for local use. Local validation uses ad-hoc signing.

## Test

```sh
/bin/zsh scripts/test-native-app.command
```

The current native tests cover the Gate 1 viewport/input mapping contract and run on Apple Silicon macOS.

## Full validation

```sh
/bin/zsh scripts/verify-tftmac.command
```

Validation checks:

- TFTMAC bundle identity;
- frozen EmulatorController protocol provenance/hash;
- pinned Swift package graph;
- retained script and JavaScript syntax;
- performance-lab and engineering-map self-tests;
- native Release build;
- native tests;
- Git whitespace integrity;
- no tracked private runtime artifacts.

A transient `TFTMAC_FORBIDDEN_TOKEN` may be supplied for the final ownership-completeness scan. The token itself must not be committed merely to test for its absence.

## Runtime data

Do not commit SDK packages, AVD userdata, Google/Riot credentials, tokens, APKs, runtime disks, logs containing sensitive data, or generated native build products.

The normal runtime root is `/Volumes/MAC MINI M4/TFTMAC/Runtime`. The application must not silently create bulk runtime/build state on the internal disk when the required external runtime authority is unavailable.
