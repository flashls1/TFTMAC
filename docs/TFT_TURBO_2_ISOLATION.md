# TFT TURBO 2 isolation — revised Checkpoint 3

Flash changed CP3 to build without copying/backing up the signed-in environment. Local Codex owns later account provisioning. The previous denied migration is not retried. The native candidate is compiled entirely from managed source and existing non-account resources; no private seed or installed personal app supplies its contents.

## Independent identities

App: ~/Desktop/TFT TURBO 2.app, bundle com.flashls1.tftmac.turbo2. The nested source-compiled host is Contents/Resources/TFTMAC Emulator Host.app, bundle com.flashls1.tftmac.turbo2.emulator-host. Future SDK/AVD/Manifests stay under ~/Library/Application Support/TFTMAC/Turbo2/StockShadow; AVD TFTMAC_Turbo2_StockShadow_R2. State/captures use TFTMAC/Modes/turbo2. Ports are server5053, console5600, guestADB5601, authenticated controller8560; serial emulator-5600. They are project assignments, not continuously held reservations. The existing shared TFTMAC/State/native-runtime.lease remains unchanged.

## Build is not runtime activation

ssot/turbo2-isolation.json now declares native_integration=build_only. ssot/runtime-modes.json includes the exact fourth turbo2 mode, while all three original mode records retain field parity. New mode remains blocked_not_built with no fabricated emulator/gfxstream/AVD/manifest hashes. Runtime selection produces a clear provisioning-pending message before account APIs or emulator spawn. Directly invoking the new core without its correct launcher environment is rejected instead of falling back to Control.

The builder accepts only the exact new Desktop path. It refuses existing output/receipt and aliases before effects, compiles from Xcode/source, packages its own host and existing source-owned helpers, signs with TFTMAC Local Code Signing, verifies in an owner-only exclusive stage, and publishes with no-overwrite atomic rename. It never deletes an installed application or accepts --seed. Both protected originals are checked before/after. The verifier binds its --app or --staged-app to the actual candidate; strict signature, registry/host receipt, native tests and all four HighPerf resources are checked. Static audio configuration is not audible acceptance.

## Completed source integration versus remaining live wiring

The new enum/registry digest/configuration identity, blocked-mode static checks, state namespace, nested-host source/Info/receipt identity, source-only packaging, independent unlock-service name, native branding and pending-state error route are implemented. No new credential is accessed or created merely by defining a service name.

Before enabling the new runtime in CP4, reconcile exact installed engine/AVD hashes and native forwarder authority with observed files. Audit the existing diagnostic-only branches of TFTMACRuntime.swift, RuntimeModeAuthority.swift, FrameContract, presentation buffering, guest HighPerf/startup, ADB ownership and login flow. Do not assume compilation extended those behaviors to turbo2. Preserve 8vCPU/6144MiB/1080p and proven ASG parameters unless a separately accepted change supersedes them. Preserve original guards, authenticated controller and shared exclusive lease. Never restore mid-game ADB root/audio restart.

## Account and acceptance boundary

No account backup/migration, old AVD copy, PIN resource, Riot store read, Keychain item access or authentication acceptance belongs to revised CP3. Provider consent must never be bypassed. Stable signing does not guarantee that a distinct bundle inherits TCC/Keychain authorization. Local Codex provisioning is separate; actual repeated automatic TFT startup and audio/match checks remain required afterwards. A native provisioning-pending smoke test is not a playable release.

Current build/smoke status is recorded in facts.md and the exact CP3_BUILD_ACCEPTANCE.json when produced. CP4 remains unstarted until a new explicit continue. Historical CP2 and original CP3 receipts remain history. No daemon, credential vault, scheduler, Android OS build or source-emulator fork was introduced.
