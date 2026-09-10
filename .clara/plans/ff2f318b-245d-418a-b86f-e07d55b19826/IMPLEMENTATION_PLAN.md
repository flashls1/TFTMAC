# Implementation Plan — reusable LKG overnight optimization lab

Supersedes any stale project campaign plan for this change.

## Execution contract
1. Add source-controlled `OvernightLab/` control-plane scripts/config/schema/reporting; do not place SDK/AVD/app/runtime binaries there.
2. Generate official-client authority from frozen Sept-10 receipts and verify `/Applications/TFTMAC DEV.app` hash identity before every campaign.
3. Build a PBE evidence/admission gate that rejects PBE package/profile/candidate inputs but does not delete archives.
4. Build a fresh official-client candidate manifest containing only control, buffer-observability, cache validation, and bounded Vulkan families.
5. Create an official Tocker runner by adapting proven state-machine behavior, using live-package authority and existing installed DEV/StockShadow; never invoke the old PBE runner.
6. Explicitly launch advanced diagnostics with `TFTMAC_DEV_VCPU=8`; verify actual emulator command/config exposes 8 vCPU, 6144 MiB, 1920x1080/320/60 before scoring.
7. Implement `TFTMAC_OVERNIGHT.sqlite`: campaigns, candidates, builds, runs, experiment_variables, evidence_provenance, telemetry_coverage, state_transitions, mechanism_events, performance_windows, failures, rollbacks, artifacts, comparisons, decisions.
8. Use one `campaign_id/candidate_id/build_id/run_id/session_id` chain across every artifact. Import/link native per-session SQLite instead of replacing it.
9. Add external RHI selection analyzer with explicit Unreal selection/init precedence; preserve raw native classifier value separately.
10. Add build-scope classifier: NO_BUILD, ANGLE_DRIVER_BUILD, APP_BUILD_REQUIRED. Normal initial queue uses only first two. Deterministic ANGLE build key reuses verified binaries.
11. Add atomic checkpoint, campaign lock, heartbeat, watchdogs, failure fingerprints, second-identical-failure quarantine, process/AVD/overlay reconciliation on resume, and verified rollback gate before next candidate.
12. Add fault-injection/self-test covering PBE input, malformed candidate, wrong identity, missing telemetry, child timeout, stale checkpoint, duplicate failure and rollback denial without touching LKG/Control.
13. Run official-client CONTROL smoke: installed DEV unchanged -> StockShadow -> package/version -> login -> Tocker early combat -> capture -> result -> cleanup/rollback. External auth may classify AUTH_BLOCKED while infrastructure acceptance continues.
14. P1 buffer observability: change ANGLE diagnostics only, split grouped reuse rejection into explicit reasons, build only three ANGLE libraries, validate manifest/hashes offline, deploy via existing `TFTMAC_ANGLE_DRIVER_MANIFEST`, prove official process loaded them, run smallest decisive Tocker sample, verify telemetry completeness. No behavior optimization until reasons are known.
15. If P1 identifies dominant repairable cause, generate minimal ANGLE repair(s), offline replay/validation, short official-client test, promote to longer comparison only if legitimate retention increases, creation decreases, correctness holds and timing is non-regressive.
16. P2 cache: no app build; verify properties set/read back before TFT PID, snapshot cache before/after, record retained/new/removed/malformed/eviction data, run matched CONTROL/CACHE/CONTROL timing and classify mechanism-only/provisional/promotable/neutral/reject.
17. P3 bounded Vulkan: external full LKG profile plus one RHI-selection delta only; exact-delta gate, engine boot error screen first, then visual smoke and Tocker 1-1 only if clean; reproduce old ATTRIBUTE/MoltenVK failure => clean rejection, no overnight Vulkan repair loop.
18. Generate morning report and CSV exports. Start unattended local campaign under `caffeinate`; it must not require an active Zoe/Clara chat to continue deterministic execution.
19. Validate source; review diff; preserve implementation through change checkpoint/publication. Because deployment profile is SOURCE_ONLY, local OvernightLab install/start is the requested live layer for this change; do not invent a remote deploy.

## Explicit exclusions
No storage cleanup. No app/SDK/emulator/AVD clone. No 5GB, 6-vCPU, compiler-count, PSO-worker, animation-budget, streaming-memory, resolution, MSAA2, presenter, random CVar, old PBE candidate, 64-entry legacy matrix, or giant Metal trace work.

## Acceptance loop
Preflight -> plan -> ZenGate -> ZenMC -> implementation -> static/fault validation -> attended-equivalent autonomous control smoke -> P1 component-only path -> cache path -> bounded Vulkan if eligible/time -> final local supervisor start -> source validation/review/checkpoint/delivery evidence.