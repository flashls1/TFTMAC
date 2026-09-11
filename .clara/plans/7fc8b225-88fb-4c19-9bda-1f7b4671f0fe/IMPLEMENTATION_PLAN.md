# Implementation Plan — resolve CVar overlay and measure impact

1. Implement a single `wait_adb_uid(expected_uid, timeout)` primitive in `OvernightLab/overnight_lab.py` using the existing exact ADB binary/server/serial. During the bounded transition, require the owned emulator to remain alive, use `wait-for-device` as the reconnect primitive, then prove `adb shell id -u == expected_uid`.
2. Route `adb_root()` and `adb_unroot()` through that primitive. Preserve existing error classes and fail-closed behavior. Do not change Control/LKG or AVD ownership.
3. Extend IncrementalLab with an explicit impact-only execution option. In impact-only mode, execute the same queue/control/candidate/confirmation logic but skip the post-queue stability-tail loop and terminalize when the queue is resolved. Time remains only a maximum safety bound.
4. Add self-test coverage for impact-only queue-exhaustion semantics and the privilege-transition decision helper where deterministic testing is possible.
5. Run ZenMC against the accepted state machine; require zero violations before product execution.
6. Checkpoint plan + ZenMC receipt before source effects.
7. Validate source with `scripts/verify-tftmac.command`.
8. Install exact source into the live OvernightLab and prove source/live parity plus static integrity.
9. Run a bounded DEV-only privilege canary: launch the isolated DEV runtime, prove shell UID 2000, root -> UID 0, unroot -> UID 2000, repeat once, then normal quit/rollback and verify installed DEV + frozen LKG integrity. No performance conclusion is taken from this canary.
10. Start a fresh impact-only campaign from `DEV-B8-WIN-01`. Test in order: PSO threads 2; shader background batch 4; animation budget 5ms; 4ms only if 5ms confirms positive. Each candidate uses fresh matched control, exact CVar readback/engine-log proof, native combat telemetry, and verified rollback.
11. For PROMISING/HOME_RUN, require the existing confirmation pair before integrating. For neutral/regression/inconclusive, do not integrate. If a candidate becomes a winner, the next candidate must use the newly confirmed cumulative working profile.
12. Reconcile results into `CHANGELOG.md` and `project.md`; update `facts.md` only if current hard authority changes. Create a new `DEV-B8-WIN-##` only with confirmation evidence.
13. Run final production validation and review; publish, PR, exact-SHA CI, merge, and prove merged/live parity and runtime quiescence.

## ZenGate
PASS subject to ZenMC PASS. This is the minimum causal repair: one reconnect-aware transition primitive plus one execution-mode flag; no new service, store, runtime, AVD, app, or candidate family. Acceptance is valid impact evidence, not elapsed wall-clock duration.