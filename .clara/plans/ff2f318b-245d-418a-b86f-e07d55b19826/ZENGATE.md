# ZenGate — overnight official-client optimization lab

Result: PASS, ZENMC_REQUIRED.

## Scope gates
PASS: LKG immutable.
PASS: Control immutable.
PASS: installed DEV app must remain unchanged for ordinary tests.
PASS: official live client only for decision-admissible evidence.
PASS: PBE archives may exist but cannot enter active candidate/evidence paths.
PASS: no new SDK/emulator/AVD/app clone.
PASS: no storage deletion.
PASS: configuration candidates are external/runtime-only; ANGLE candidates are component-only.
PASS: one-factor/delta gate before scoring candidates.
PASS: requested and effective values independently recorded.
PASS: incomplete decision-critical telemetry => INCONCLUSIVE.
PASS: selected RHI derived from explicit Unreal selection/init before capability evidence.
PASS: no credential logging or CAPTCHA/MFA bypass.
PASS: no blind unknown-screen interaction.
PASS: all waits/retries/watchdogs bounded.
PASS: identical deterministic failure quarantined on recurrence.
PASS: rollback must be proven before next candidate.
PASS: no benchmarking while campaign-owned compile/analyzer work contaminates timed interval.
PASS: no performance claim from presenter Hz or cache existence alone.
PASS: no grouped buffer rejection reason retained where individual cause can be emitted.
PASS: no automatic source merge into protected baseline or runtime promotion of an unproven candidate.

## Complexity economics
The simplest viable baseline is the existing installed LKG-identical DEV app + StockShadow. New plumbing is limited to external orchestration, a small campaign DB, field-level telemetry normalization, admission/rollback/failure controls, and candidate component artifacts because each maps directly to unattended acceptance/evidence integrity. No new service, daemon protocol, runtime clone, cache backend, or app version is justified.

## ZenMC qualification
Required because unattended execution includes restart/recovery, partial progress, idempotent replay, external auth/network uncertainty, candidate failure interaction, rollback safety and durable resume.