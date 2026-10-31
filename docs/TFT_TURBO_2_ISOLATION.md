# TFT TURBO 2 isolation contract — Checkpoint 2

The canonical future identity descriptor is `ssot/turbo2-isolation.json`. It is deliberately `blocked_not_built` and is **not** a replacement for the accepted `ssot/runtime-modes.json`. The native app cannot select `turbo2` yet. CP2 installs no application, SDK or AVD. The shared preflight is real production entrypoint protection; its PASS means identity/path consistency, never launch, login or audio success.

## Independent identities

- App: `~/Desktop/TFT TURBO 2.app`; bundle `com.flashls1.tftmac.turbo2`.
- Packaged forwarder: `Contents/Resources/TFTMAC Emulator Host.app`; its future bundle is `com.flashls1.tftmac.turbo2.emulator-host`.
- Runtime: `~/Library/Application Support/TFTMAC/Turbo2/StockShadow`; separate SDK, AVD and Manifests below it.
- AVD: `TFTMAC_Turbo2_StockShadow_R2`.
- State and captures: reuse the existing per-mode derivation under `~/Library/Application Support/TFTMAC/Modes/turbo2`, not the incumbent `advanced_diagnostics` namespace.
- Endpoints: ADB server5053; emulator console5600; adjacent emulator ADB transport5601; authenticated controller8560. Serial `emulator-5600`.
- Existing shared exclusive lease remains `~/Library/Application Support/TFTMAC/State/native-runtime.lease`. Separate ports do not authorize concurrent games or a new lease owner.

These ports are assigned in the project contract and were free at the CP2 observation. No socket is held open; the launcher must recheck availability and never terminate a foreign owner to obtain a port.

## Guarded route

`python3 scripts/build-turbo-app.py --preflight` and `zsh scripts/verify-turbo-build.command --preflight` perform read-only identity checks. The builder must reject all outputs except the exact Turbo2 path, including symlink parents and nested originals. Normal build remains blocked **before reading a private seed, deleting output, compiling, signing, registering or touching Finder** until a later checkpoint implements the native route. A configuration toggle or environment flag cannot override this boundary.

Verifier requires an explicit candidate `--app`, validates the new bundle identity, and cannot fall back to validating TURBO1. Its eventual invocation is tied to the builder's exact output. Missing local signing identity must fail closed, never choose ad-hoc signing. A full native build is not needed to prove these entrypoint boundaries; focused tooling tests exercise them with forbidden-effect mocks and actual rejected CLI invocations.

## Native wiring required before clone-launch acceptance

1. `RuntimeMode.swift`: enum, exact registry digest, registered-mode cardinality, definition/configuration digests and new exact identity checks. Keep existing three modes and their safety checks; never rename advanced_diagnostics to evade validation.
2. `RuntimeModeAuthority.swift`: supplemental mode record, independent state namespace, exact forwarder identity, coherent immutable runtime evidence and profile ownership. Preserve existing global lease derivation.
3. `TFTMACRuntime.swift`: audit all mode-specific guest provisioning, startup, login, capture, ADB transition and recovery sites. New runtime must not use old hard-coded serial/ports or fall back to protected Control. The CP2 audit found 102 ownership-related matches, not 102 required edits.
4. `AppCoordinator.swift` and presentation bundle checks: new mode must retain native startup, window and frame behavior, not silently become Control.
5. `GuestUnlockSecret.swift`: current mode switch, original DEV service and dedicated keychain path must not be reused for deletion/recreation. New bundle access requires proof. Do not copy secrets into manifests or logs.
6. `RiotLogin.swift`: existing remembered credentials are a read-only dependency through the authorized interface. Preserve the store and remember preference; do not generate a new login workflow or edit the source store.
7. Builder, verifier and launcher: rebind names/Info.plist/native runtime registry/forwarder/receipt to Turbo2 together, then remove the explicit no-build boundary only with accepted isolation and migration authority. Preserve 8vCPU/6144MiB/1080p baseline.

## Authentication boundary

The old TURBO designated requirement includes identifier com.flashls1.tftmac.dev and its certificate. A different bundle ID is not proof of access to that app's Keychain items or TCC consent. `com.flashls1.tftmac.turbo2` is the selected independent identity, but authentication/permission acceptance remains OPEN for the signed candidate. The first choice is preserving the complete offline guest state and using already-authorized host interfaces without changing the originals. Genuine provider consent must be surfaced, never bypassed or silently retried indefinitely.

## Explicitly deferred

CP3: offline backup/clone, qcow2 backing-chain independence, native candidate route and retained-session verification. CP4: official emulator package verification/upgrade. CP5: repeated one-click startup acceptance. CP6: actual audio acceptance. CP10: complete reproducible packaging. No custom daemon, scheduler, credential vault, dynamic identity framework or source emulator rebuild is introduced by CP2.
