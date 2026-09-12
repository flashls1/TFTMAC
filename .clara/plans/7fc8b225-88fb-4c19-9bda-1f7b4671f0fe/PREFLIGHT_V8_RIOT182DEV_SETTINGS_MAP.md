# Preflight V8 — Riot 18.2 / TFTMAC adjustable-settings map

## Request
Create `riot182dev.md` as the exhaustive discoverable map of settings that can be intentionally changed across the TFTMAC DEV application/project and the current Riot 18.2 / Unreal runtime surface. Group controls by function. Include fields even when no candidate value is currently chosen. Exclude fields that are only inferred, derived telemetry, immutable integrity identities, credentials/secrets, and hard-coded constants with no exposed adjustment surface.

## Authority / scope
- Exact project: `tftmac` / `flashls1/TFTMAC`.
- Exact managed change: `7fc8b225-88fb-4c19-9bda-1f7b4671f0fe`.
- Use current managed-worktree source plus current Riot 18.2 boot evidence from the DEV capture, not stale `settings.md` claims.
- `facts.md` remains first authority and `project.md` second; this new file is a discoverability/catalog document, not a new SSOT.
- No runtime, Control, LKG, Riot package, emulator image, AVD state, or performance setting is to be changed by this task.

## Discovery surfaces inspected
1. Native app/runtime source (`tftmac/App`, `tftmac/Runtime`, `tftmac/Sources`).
2. Current DEV `DeviceProfiles.ini` and current 18.2 `highperf-engine-boot.log`.
3. Advanced-diagnostics AVD `config.ini` and AVD stub `.ini`.
4. Runtime-mode registry / supplemental authority fields.
5. Android guest mutation commands (`settings put`, `setprop`, package/runtime commands).
6. ANGLE driver transaction and ANGLE capture/debug properties.
7. gfxstream / ASG transport controls and emulator feature flags.
8. MoltenVK environment controls surfaced by the project and performance manifests.
9. Runtime/UserDefaults/environment inputs.
10. OvernightLab, update-audit, measurement, benchmark and legacy experiment inputs that remain discoverable in executable project tooling.
11. Google Play / Riot login behavioral preferences that are genuine settings (not credential values).

## Inclusion rule
Include a field if the current project or current Riot 18.2 boot evidence demonstrates an intentional adjustment surface: DeviceProfile/CVar, config/INI field, environment variable, UserDefaults key, Android settings/property, command-line option, manifest field that controls behavior, or runtime registry/profile field.

## Exclusion rule
Do not catalog checksums/hashes, UUID receipts, timestamps, derived metrics, telemetry result columns, credentials/passwords/tokens, package signing identities, or fields that exist only as immutable validation constants and have no behavioral adjustment route.

## Completeness checks required after generation
- Every one of the 388 current Riot 18.2 boot-configurable CVars must appear exactly once in the Riot/Unreal mapping sections.
- Every one of the 78 DEV DeviceProfile overrides must be represented and marked as DEV-overridden.
- Every one of the 145 fields in the current advanced-diagnostics AVD `config.ini` must appear in the emulator mapping.
- Every discovered project guest property/settings mutation and every active/executable configuration input must either appear in the document or be explicitly classified as excluded/non-setting.
- Run a source-to-document token audit after writing and repair all omissions before stopping.
