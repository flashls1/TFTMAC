# Amendment 002 — Blocking Classifier False Positive + Truthful Control Terminal State

## Discovery classification
`BLOCKING DEPENDENCY` discovered by the first live control of campaign `incremental-20260911T082151Z-1f32770a`.

The control reached real Tocker battle stages 1-1 and 1-2, then the screen classifier labeled the normal stage-1-3 shop frame as `error_reject_marker`. Independent Vision OCR of the saved frame contained no `ERROR`, `FAILED`, `UNAVAILABLE`, `DECLINED READY CHECK`, or `RETURNED TO THE LOBBY` text.

Debugging the existing classifier proved the exact root cause. `EvidenceMatcher.has()` concatenates every OCR line into `compactCorpus` to permit phrases split across OCR lines. On the saved normal frame, three independent OCR lines `Brawler`, `r`, and `Ornn` concatenate to `BRAWLERRORNN`, which contains the synthetic substring `ERROR`. The current generic `matcher.has("ERROR")` therefore creates a false fail-closed state from cross-line text that never existed on screen.

A second in-scope bookkeeping defect was exposed at the same time: the run's rollback receipt proves DEV stopped, emulator stopped, profile restored, installed DEV integrity true, frozen LKG integrity true, and `verified=true`, but `incremental_lab.py` sets campaign-level `rollback_verified=false` merely because the control classification is `INCONCLUSIVE`. It then labels the early pre-deadline stop `DEADLINE_COMPLETE`. Both statements are factually false.

## Smallest authorized repair
1. Keep cross-line `EvidenceMatcher.has()` unchanged for existing phrase matching.
2. Add a line-local matcher and use it only for the strong error markers plus `ERROR`. Error rejection may match inside one OCR line, but never by concatenating unrelated OCR lines.
3. Add a regression self-test reproducing the exact `Brawler` + `r` + `Ornn` boundary so it cannot synthesize `ERROR` again.
4. In `incremental_lab.py`, derive campaign rollback truth from the actual run rollback receipt, never from `INCONCLUSIVE` classification alone.
5. If a control is not green before the deadline but rollback is proven, stop that attempt as `BLOCKED_INCONCLUSIVE` with the exact blocker instead of falsely claiming deadline completion. Keep queue index unchanged.
6. On a governed resume after the blocking dependency is repaired, clear only the transient blocker marker, reconcile actual runtime/rollback through the existing resume path, and reattempt the same current control before the original deadline. Do not erase the prior run or its evidence.
7. Preserve the original campaign deadline. Recovery downtime is an interruption/recovery interval; do not create a second overlapping campaign.

## Complexity Economics Gate
PASS. This is one matcher method, one targeted call-site change, one regression test, and truthful state bookkeeping in the existing runner. No new classifier, OCR framework, retry service, scheduler, runtime, or recovery subsystem is added.

## ZenGate
PASS. ZenMC V3 completed with 100,000 trajectories, zero invariant violations, result `PASS`, receipt `052d36aeda6fc63d8a67b07e312166c1e4106e246be5485fa856c76d9573ea30`. The repair is limited to the proven blocker and the false completion/rollback statements it exposed. No tuning candidate, game setting, runtime identity, protected Control/LKG boundary, or comparison doctrine changes.

## ZenMC V3 qualification
ZENMC_REQUIRED because the repair changes blocked/resume/completion semantics in the four-hour lifecycle.

Required invariants:
- unrelated OCR lines can never synthesize a strong error marker;
- a non-green control never advances the candidate queue;
- `INCONCLUSIVE` does not imply rollback failure;
- actual rollback failure still blocks all future run admission;
- a verified-rollback blocked control may resume the same queue index before the original deadline after the blocker is repaired;
- deadline still prevents admission of the next run;
- frozen LKG remains immutable;
- candidate promotion still requires positive confirmation;
- post-queue stability controls remain no-mutation working-profile runs only.

## Resume target after repair
Resume `incremental-20260911T082151Z-1f32770a` from queue index 0 under its original deadline after source validation, live classifier/runner install, classifier regression proof against `state-0051-error.png`, and protected-state verification.
