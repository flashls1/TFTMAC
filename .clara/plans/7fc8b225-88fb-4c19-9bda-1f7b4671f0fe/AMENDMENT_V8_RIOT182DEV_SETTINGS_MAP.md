# Amendment V8 — Build exhaustive `riot182dev.md` adjustable-settings inventory

## Goal
Produce one discoverability document, `riot182dev.md`, that answers: **what can we intentionally change anywhere in the TFTMAC DEV / Android emulator / graphics translation / Riot 18.2 Unreal stack / project experiment tooling?**

This is a field map, not a recommendation list. A mapped control does not imply that changing it is safe, useful, supported by Riot, or likely to improve performance.

## Structure
1. Catalog contract / legend / exclusion policy.
2. Native TFTMAC runtime profile and UI/UserDefaults controls.
3. Runtime mode, routing, ports and host-launch controls.
4. Emulator launch arguments and feature flags.
5. Complete current AVD `config.ini` field map, grouped by hardware/function.
6. Android guest OS settings/properties and package/power/scheduling controls.
7. ANGLE / EGL controls and capture/debug controls.
8. gfxstream / virtio-gpu / ASG controls.
9. MoltenVK controls exposed by current or executable project tooling.
10. Complete Riot 18.2 / Unreal CVar map, all current boot-discovered configurable CVars, grouped by function; mark the current DEV override subset.
11. Riot/TFT-specific frame-rate, audio and game-facing controls.
12. macOS host presentation/window/runtime controls.
13. Google Play/update and login behavior controls.
14. Telemetry, benchmark, Perfetto, experiment and OvernightLab controls.
15. Build/tooling/environment controls.
16. Legacy/experimental executable project controls, clearly labeled so they are discoverable without being mistaken for the current DEV baseline.
17. Excluded non-settings / intentionally unmapped identities.

## Generation method
Use current source and current runtime evidence as machine-readable inputs. Generate the repetitive AVD/CVar tables programmatically to prevent transcription omissions. Preserve exact setting names/case. Add current observed/default/DEV values when directly available, but permit blank candidate values.

## Validation
After `riot182dev.md` is created, independently extract the source/evidence sets again and compare them with the Markdown text. The acceptance test is set inclusion, not prose review: 388/388 Riot 18.2 CVars, 78/78 DEV overrides, 145/145 AVD fields, plus all separately discovered project properties/settings/environment inputs. Any missing token is repaired and the audit rerun.

## Boundaries
No settings are changed. No runtime experiment is started. No Riot binaries/content are modified. Control and frozen LKG remain untouched. `riot182dev.md` is informational/catalog authority only and cannot supersede `facts.md` or `project.md`.
