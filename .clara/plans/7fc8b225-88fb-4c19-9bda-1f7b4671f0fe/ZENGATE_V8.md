# ZenGate V8 — `riot182dev.md`

## Decision
PASS.

## Why this route is simplest-correct
The requested deliverable is a static settings inventory. The least risky implementation is to generate its repetitive tables directly from the current AVD, current Riot 18.2 boot log, and current source configuration surfaces, then verify set inclusion. No runtime setting needs to be changed and no new configuration framework is required.

## ZenMC qualification
ZenMC is **not required** for V8. This change adds documentation only; it does not introduce or alter lifecycle states, rollback behavior, concurrency, recovery, runtime selection, graphics routing, credentials, or executable configuration.

## Acceptance gate
- `riot182dev.md` exists at project root.
- 388/388 current Riot 18.2 boot CVars mapped.
- 78/78 current DEV DeviceProfile overrides mapped.
- 145/145 current advanced-diagnostics AVD config fields mapped.
- Project-level mutable settings/properties/env/UserDefaults/CLI/experiment surfaces are mapped or explicitly excluded with a reason.
- No Control/LKG/runtime/Riot content mutation.
