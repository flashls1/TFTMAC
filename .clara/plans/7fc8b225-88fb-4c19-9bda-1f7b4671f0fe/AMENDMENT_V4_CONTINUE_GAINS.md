# Amendment V4 — continue bounded gain search after valid impact pass

## Trigger

Flash explicitly extended the objective beyond the original unresolved four-candidate queue: continue finding measurable gains, retain even small repeatable net improvements, do not break the playable system, and exhaust practical current one-factor routes before stopping.

## Current evidence entering this amendment

- Current verified winner remains `DEV-B8-WIN-01`.
- Campaign `incremental-20260911T203403Z-cc03b671` produced valid candidate impact evidence.
- `r.pso.PrecompileThreadPoolSize 4 -> 2` is a measured regression and must not be recycled.
- `a.Budget.BudgetMs 6.0 -> 5.0` is a measured net regression and must not be recycled.
- `r.ShaderPipelineCache.BackgroundBatchSize 20 -> 4` remains unresolved only because its candidate run was `AUTH_BLOCKED` before measurement; it was not performance-rejected.
- Every completed run restored `DEV-B8-WIN-01`; protected Control and frozen LKG remain intact.

## Scope extension

Continue with a bounded, one-factor refinement queue using the already-proven DeviceProfiles overlay/rollback mechanism. No new runtime, AVD, app family, graphics API, source-built emulator, profiler, signed-package modification, or protected-Control mutation is authorized.

The next queue is:

1. `shader-background-batch-4-retest`: `r.ShaderPipelineCache.BackgroundBatchSize 20 -> 4`. One clean retest because the prior candidate never reached performance measurement.
2. `pso-precompile-threads-3`: `r.pso.PrecompileThreadPoolSize 4 -> 3`. This is a midpoint refinement after 2 threads proved too restrictive; it tests whether a mild contention reduction can avoid the severe throughput loss of 2.
3. `animation-budget-5_5ms`: `a.Budget.BudgetMs 6.0 -> 5.5`. The 5 ms test improved 1% low and p95/p99 materially but lost too much mean FPS; 5.5 ms is the smallest midpoint test intended to preserve some tail benefit without the 8.67% mean-FPS loss.
4. `shader-batch-time-2ms`: `r.ShaderPipelineCache.BatchTime 4 -> 2`. Current source explicitly applies 4 ms. Epic's current FShaderPipelineCache documentation describes fine-grained per-frame precompile budgeting and distinguishes interactive/background compilation from fast loading-screen compilation; halving this per-frame budget is a bounded stutter/contention hypothesis, not an assumed win.
5. `opengl-remote-compile-services-2`: `Android.OpenGL.NumRemoteProgramCompileServices 4 -> 2`. Current official DEV profile explicitly applies 4; this one-factor test checks whether reducing concurrent remote compile-service pressure on an 8-vCPU guest improves interactive frame stability without increasing shader stalls.

## Queue/campaign rules

- Preserve prior resolved entries in `resolved_candidates` in the same manifest with exact status/reason; do not silently rerun them.
- `candidates` contains only currently admitted tests. The existing runner already executes only this array, so no new scheduler/filter implementation is required.
- All active candidates start from the latest verified working profile. If a candidate confirms `PROMISING`/`HOME_RUN`, keep it in the cumulative working profile and use that as the next baseline.
- Any `REJECT`, `INCONCLUSIVE`, auth-blocked, setup-invalid, or regression result restores the latest verified winner immediately and advances.
- No candidate has a +5% floor. Any repeatable directional net improvement may promote when confirmation passes and no correctness/stability/compatibility/severe-tail veto outweighs it.
- If an exact candidate fails for a transient auth/UI condition before measurement, it may receive one later clean retest; repeated identical auth/UI failure is logged as unresolved infrastructure evidence, not a performance verdict.
- Stop this amendment's queue after these five candidates are resolved. Reconcile results before deciding whether another evidence-backed family exists; do not invent a candidate merely to keep testing.

## Protected boundaries

Unchanged: `/Applications/TFTMAC.app`, frozen LKG, Riot APK/assets/shaders, credentials, current OpenGL/ANGLE core route, StockShadow authority, and exact rollback/integrity gates.

## Acceptance

This amendment is complete when all admitted candidates are terminally resolved or truthfully classified, every run has verified rollback/integrity, every verified gain is confirmed and promoted cumulatively, record books match evidence, and the app remains playable on the resulting latest verified winner.
