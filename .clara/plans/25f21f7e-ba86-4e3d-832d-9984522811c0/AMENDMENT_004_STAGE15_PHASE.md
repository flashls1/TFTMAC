# Amendment 004 — Tocker 1-5 phase classification blocker

## Classification

BLOCKING DEPENDENCY discovered by the live governed campaign. This amendment does not admit a new optimization candidate or widen the performance experiment. It repairs the existing screen-classifier semantics required to reach the already-approved 1-5 measurement gate.

## Current evidence

Campaign `incremental-20260911T082151Z-1f32770a` remains at queue index 0 with no accepted performance candidate and verified rollback.

Latest control `run-747b11debe5a47a09dc96a24abdc8213` reached Tocker stage 1-5 and remained there until the navigation watchdog expired. The final screenshot is a normal battle HUD with OCR including stage `1-5`, `Score`, score value `36,550`, traits, gold, and board occupancy. It contains no reject/error/login marker. The classifier returns `state=battle`, `stage=1-5`, but `phase=null` because the stage-1-5 combat presentation does not expose the cyan combat timer or a literal `COMBAT` marker.

A read-only audit of all 371 current-campaign battle classifications found:
- 315 phase-null rows: `SCORE`, no shop, no FIGHT.
- 46 known combat rows: `SCORE`, no shop; 12 also expose FIGHT late in combat.
- 2 known planning rows with SCORE both expose FIGHT.
- 6 known planning rows without SCORE expose shop/planning controls.
- 1 observed post-combat SCORE row exposes shop/reward state and is already recognized through the `TIME BONUS` path.

Therefore `SCORE` alone is not a legal new phase signal. The admissible missing semantic is: a battle frame with SCORE after existing explicit combat/planning/post-combat checks, where no shop is open and no FIGHT control is visible.

## Purified repair

1. Compute `shopOpen` and `fightButtonVisible` before `battlePhase` is called.
2. Pass those two already-existing observed UI facts into `battlePhase`.
3. Preserve precedence exactly:
   - explicit `COMBAT` / cyan timer -> combat;
   - explicit PLANNING/PREPARE/FIGHT/REROLL -> planning;
   - TIME BONUS -> post_combat;
   - only then, if battle HUD contains line-local SCORE and both `shopOpen == false` and `fightButtonVisible == false`, classify combat.
4. Keep all reject/login/disconnect/trial-choice classification behavior unchanged.
5. Add self-test fixtures proving:
   - SCORE + no shop + no FIGHT -> combat;
   - SCORE + FIGHT -> planning;
   - TIME BONUS remains post_combat.
6. Replay the exact failed 1-5 screenshot and require `state=battle`, `stage=1-5`, `phase=combat`.
7. Production validate, checkpoint/publish, install the classifier through the existing OvernightLab install seam, prove source/live parity, then resume the same campaign at queue index 0 and immutable deadline `2026-09-11T12:21:51Z`.

## Non-goals

- No candidate/CVar change.
- No new workload.
- No timeout increase.
- No blind click.
- No Control/LKG mutation.
- No app/emulator/AVD rebuild.
- No change to promotion thresholds.

## ZenGate

PASS. ZenMC V5 (`TFTMAC_INCREMENTAL_4H_LIFECYCLE_V5_STAGE15_PHASE`) completed 100,000 trajectories with zero invariant violations. Receipt SHA-256: `d5731f249d5921d102216af7324e8ee72b02b4491e3e0db0ba21a647a1588d5a`.

The simplest safe mechanism is extending the existing classifier with two already-computed UI facts; no new state machine, service, store, or instrumentation is required.
