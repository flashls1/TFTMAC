# Implementation Plan — four-hour evidence-grounded incremental optimization sweep

## Execution contract

1. Converge only the proven current DEVHighPerf resource authority into this change: copy exact current `DeviceProfiles.ini`, `profile-transaction.sh`, and matching README from preserved `bddd2d6c...` resource state. Do not import its stale facts/project docs or unrelated login work. Update source hashes/tests only where the repository's own verifier requires it.
2. Add an incremental-candidate manifest separate from historical/PBE candidate inventories. Initial queue is `pso-precompile-threads-2`, `shader-background-batch-4`, `animation-budget-5ms`; `animation-budget-4ms` is conditional on a confirmed 5ms win.
3. Generalize OvernightLab's proven DeviceProfiles bind-overlay implementation from direct-Vulkan-only to exact one-CVar profile overlays. Candidate generation must diff parsed section/key/value maps and fail unless the only semantic differences are every expected occurrence of the one declared CVar.
4. Preserve existing direct-Vulkan helper behavior as historical code, but the new incremental queue never selects it.
5. Add incremental campaign state containing: base merged authority SHA, installed DEV resource hashes, current campaign working-profile SHA, cumulative accepted deltas, candidate queue index, matched control/candidate/confirmation run IDs, exact native capture IDs, deadline, and rollback state. Atomic checkpoint writes only.
6. Add matched comparison logic using same-stage native performance windows and current v4 doctrine. Material vetoes: correctness/usability failure, >=5% weighted-FPS regression, >=10% 1%-low regression, >=10% p95/p99 regression, client/RHI/config identity mismatch, telemetry invalidity, or unproven rollback. Any valid directional gain without a veto is PROMISING and requires confirmation.
7. Use one current campaign control before each new candidate. Generate candidate from the current campaign working profile. A confirmed positive candidate becomes the campaign working profile for subsequent tests; reject/inconclusive restores the prior working profile.
8. Keep the screen/navigation workload fixed. Use the smallest repeatable Tocker workload that still exercises the heavy path and yields same-stage native windows; prefer the already-comparable 1-5 stage with a small bounded window count. Do not generate unbounded traces/profilers.
9. Efficiency rules: no Xcode/app rebuild during candidate runs; no SDK/emulator/AVD copy; no root-only cache inventory unless explicitly required; no repeated research/discovery during the run; one full DEV launch only when needed for a control, candidate, or confirmation. Reuse existing classifier and installed app.
10. Before the live run, run static/self/fault tests plus repository validation once. The one validation build is a safety gate, not a per-candidate rebuild.
11. Install/update only the small source-controlled OvernightLab controller/manifest into `/Volumes/MAC MINI M4/TFTMAC/OvernightLab` using the existing install seam. Preserve generated database/campaign outputs.
12. Start the local campaign under `caffeinate` with an exact four-hour deadline. Store raw generated campaign data outside Git. Attach a durable Clara operation watcher so browser/context boundaries do not abandon the run.
13. Runtime gates before every candidate: protected Control not running; exact current installed DEV integrity; official TFT version; 1920x1080/320/60; effective 8/6144; `OPENGL_ES_ANGLE`; latest campaign working profile mounted/effective; native telemetry available.
14. After every run, import/seal native SQLite/capture identity, write exact candidate/profile delta, metrics, decision, and rollback evidence. Generate/update the human/CSV report before queue advance.
15. If candidate is PROMISING, run one cold confirmation on the same candidate against the same campaign working baseline. Confirmed -> keep in cumulative working stack. Confirmation loss/inconclusive -> do not keep; restore baseline and continue.
16. Conditional animation-budget 4ms is legal only if 5ms confirmed positive. It is generated from the already-accepted 5ms working profile, preserving one-factor semantics.
17. Stop admitting new candidates when the four-hour deadline is reached. Let the currently active run finish or fail safely, then restore the latest verified campaign working profile / host baseline and close the campaign as `DEADLINE_COMPLETE` or `COMPLETE`.
18. On interruption/restart, reconcile actual DEV/qemu/ADB/profile mount/AVD journal state before resuming. Never replay an UNKNOWN external effect; restore first, then resume from the checkpoint's next unapplied candidate.
19. On any rollback failure, unknown profile mount, source/client/RHI mismatch, protected-Control activity, or unowned runtime process, fail closed and stop the queue.
20. At campaign end, produce the final report with candidate results, matched controls, confirmations, cumulative accepted stack, exact capture IDs/DB hashes, rejected/inconclusive reasons, final working profile hash, remaining gap to continuous 60 FPS, and recommended next evidence-backed candidate family.
21. Reconcile final confirmed combined result into `CHANGELOG.md` / `project.md` and `facts.md` only if it changes current hard authority. Do not invent a WIN identity without confirmation evidence.
22. Validate/review/publish the source/workflow change, require exact-SHA GitHub CI, merge it, and independently verify the local OvernightLab source/install still matches merged authority. Source-only project has no remote deployment target.

## Candidate queue and rationale

A. `pso-precompile-threads-2`
- baseline: `r.pso.PrecompileThreadPoolSize=4`
- candidate: `2`
- expected mechanism: reduce CPU contention from concurrent PSO precompile workers during interactive/heavy gameplay.
- risk: slower background shader precompile / more later misses; native tail/jank and shader/PSO signals decide.

B. `shader-background-batch-4`
- baseline: `r.ShaderPipelineCache.BackgroundBatchSize=20`
- candidate: `4`
- expected mechanism: reduce burst CPU/driver work in interactive background cache compilation.
- risk: slower cache fill; reject if stalls/misses worsen despite reduced CPU contention.

C. `animation-budget-5ms`
- baseline: `a.Budget.BudgetMs=6.0`
- candidate: `5.0`
- expected mechanism: earlier animation-budget throttling under unit-dense combat to protect game-thread frame time.
- risk: visible animation degradation; any correctness/usability regression vetoes promotion.

D. `animation-budget-4ms` conditional
- baseline: campaign-confirmed 5.0ms stack
- candidate: `4.0`
- only runs after C confirms positive.
- same correctness/tail vetoes.

## Explicit non-goals

No PBE evidence. No custom Riot APK/shader modification. No Control/LKG mutation. No app/SDK/emulator/AVD clone. No per-candidate rebuild. No direct Vulkan. No transport experiments. No resolution/quality downgrade as the first route. No broad source-runtime research project. No speculative observability framework. No cleanup of unrelated worktrees.

## Acceptance

- Governance artifacts checkpointed before product/source mutation.
- ZenGate PASS + ZenMC PASS for exact lifecycle design.
- source/profile authority reconciled to proven installed current profile.
- static/self/fault and full repository validation PASS.
- live 4h campaign starts on current installed DEV with no protected-Control mutation.
- every advanced queue transition has proven rollback and durable report/checkpoint.
- campaign ends/restores safely at deadline or completion.
- final source delivery/CI/merge and post-merge local install verification PASS.
