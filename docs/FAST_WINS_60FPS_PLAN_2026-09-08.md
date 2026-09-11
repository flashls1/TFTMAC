# TFTMAC fast-wins plan for actual 60 FPS

Status: **plan ready; first decision-critical experiment is the existing
prebuilt ANGLE candidate.** This document does not claim a performance gain and
does not change the Control runtime.

## Decision from the current evidence

The two newest long TFT captures show that SurfaceFlinger and host Metal work
can run at 60 Hz while TFT frame windows still fall below target. Host
completion/GPU timings are low, while the guest SurfaceView has 46.6 ms
per-window p95 tails and hundreds of severe windows. Both captures have zero
`pipeline_events`, so they cannot identify a specific ANGLE, gfxstream, Unreal,
or MoltenVK owner. The fastest credible route is to exercise the already-built
guarded ANGLE reuse candidate, then measure the guest RHI/ASG boundary only if
that candidate does not move the result.

Current control facts are frozen: the official TFT package, existing DEV
launcher, current quality, 1920×1080/60 Hz output, and the current ASG transport.
Control remains untouched.

## ZoeMC and ZenGate preflight

- **ZoeMC MODE B — COMPLEX_SYSTEMS:** PASS. Feasible routes are (1) exercise
  the existing driver candidate, (2) isolate guest Unreal/RHI-to-ASG cost, and
  (3) repair presenter backpressure only when source lineage proves it. A host
  GLES router is deferred because current evidence does not prove guest
  translation is the limiting boundary.
- **ZoeMC MODE A — PLAN_PREFLIGHT:** `PLAN_MODEL_PASS`. Behavior units,
  candidate-loaded identity, workload exercise, frame-delivery oracle,
  correctness/rollback, and holdout failure states are separated. Unknown
  combat semantics and missing cross-stack IDs remain explicit unknowns.
- **ZenGate V4.1:** `PASS`; H1–H6 pass. The plan is bounded to one existing
  candidate, one immediate test, and only the minimum follow-up measurement
  needed to select the next repair. No score is treated as FPS evidence.

## First experiment: existing guarded view-reuse candidate

This is the fastest path because the build already exists. Do not rebuild ANGLE,
change quality, or add a new recorder before this test.

Candidate:

```text
/Volumes/MAC MINI M4/TFTMAC/DriverBuildExchange/dev-observed-reuse-cache-r14
ANGLE revision: 1166eec4c0b125e9e945196acfc549983ef72b18
driver-manifest SHA-256: 054b8fa9354bb5beb6e501728bbd6f9539f76aceba1e3060fdd9050d4f69cf81
feature: tftmacRetainTextureBufferViews
```

The candidate has conformance evidence (64 passed, 2 skipped) but no actual
TFT gameplay exercise. That is the gap this experiment closes.

### Immediate test and oracle

1. Close only the DEV instance if it is running; leave Control untouched.
2. Launch DEV with the candidate manifest and automatic capture enabled using
   the existing packaged-host route.
3. Before judging FPS, verify the actual TFT process maps the candidate ANGLE
   library and record its hash. A manifest or launcher environment alone does
   not prove mechanism exercise.
4. Run the smallest available active-TFT workload. Prefer an existing saved
   replay; otherwise capture one short user-played heavy scene. Keep recording
   through quit and finalization.
5. Reject immediately for launch failure, visual corruption, input/audio
   failure, crash, rollback failure, or absent candidate-library proof.
6. If the candidate runs, compare TFT actual-present windows, unique source
   delivery, severe intervals, and host completion against the frozen control.
   This is a screening result, not a 60 FPS acceptance run.

Keep the candidate provisionally only if its mechanism is proven exercised, the
workload is valid, correctness and rollback pass, and p95 critical-path time
improves by at least 1 ms without a p99 regression above 5%. Five alternating
repetitions and two complete real matches remain necessary for promotion.

## Follow-up selection, only after the first test

**If view creation/reuse is exercised and materially expensive:** retain or
repair the invalidation rules and descriptor-cache lifetime. Do not implement
shader translation until the measured view path remains material after reuse.

**If the candidate is neutral and RHI/ASG waits dominate:** add only the
minimum existing-runtime spans for guest RHI submission, ASG write/flush,
queue depth, and blocking reply. Immediately rerun the short active-TFT test;
this is a bounded causal addition, not a new general-purpose logger.

**If source lineage shows mailbox/backpressure loss after a completed guest
frame:** repair the bounded presenter handoff and retest unique-source
delivery, frame age, and input latency. Do not count removal of repeats as
created game frames.

**If fence polling is a measured late-frame dependency:** prototype the
negotiated shared completion state with device/queue/fence/reset-generation
identity and RPC fallback. Run its focused fence lifetime test immediately.

**If all guest-side evidence remains within budget but translation is not:**
compare the same validated workload on host ANGLE/Vulkan/MoltenVK. A custom
host-forwarding/router path is allowed only if that comparison demonstrates
enough savings to cover transport cost and passes a targeted architecture gate.

## Spend and stop rules

- One active experiment at a time; no rebuild or flag changes during capture.
- Stop after 60 minutes without a runnable decision test. Capture drain and
  finalization are exempt.
- Do not claim a gain from lobby, a 60 Hz counter, average FPS, or a run with
  no proof that the candidate was loaded.
- Preserve every failed capture and rollback receipt. Keep credentials and raw
  captures outside Git.
- At completion, audit the diff and remove any hunk not required by this plan
  or its validation.

## ZEN GATE DISCOVERY REPORT

- Existing ANGLE conformance and replay receipts do not prove TFT gameplay
  performance; this is retained as an explicit evidence boundary.
- The two recent real sessions lack combat-stage semantics and cross-stack
  frame IDs; they remain diagnostic evidence, not final acceptance.
- A host-router implementation is a deferred escalation, not an active task.

ZEN GATE V4 EXECUTION LOCK — Execute only this approved plan and the minimum changes required to satisfy its stated win condition and acceptance criteria. Do not add, refactor, rename, clean up, generalize, optimize, upgrade, reformat, or alter unrelated behavior unless this plan explicitly requires it. Every changed file and material diff hunk must trace to an approved requirement/plan step, required validation, or a proven blocking dependency without which acceptance cannot pass. When an unplanned issue is discovered, perform only the minimum investigation needed to classify it: if it blocks current acceptance, prove the dependency and return the smallest scope expansion through targeted Zen Gate before changing it; if it is a real but non-blocking defect, do not repair it now—save it to the persistent project scratchpad or Zen Gate Discovery Ledger and include it in the final ZEN GATE DISCOVERY REPORT for separate review and Zen Gate repair planning. Once a discovery is shown not to block the current win condition, stop investigating it and return to the approved task. Before completion, audit the final diff and revert every change that cannot be justified by this rule.
