# Preflight — four-hour evidence-grounded incremental TFT optimization sweep

Date: 2026-09-11 America/Chicago
Change: `25f21f7e-ba86-4e3d-832d-9984522811c0`
Completion class: IMPLEMENT_SHIP
Base: merged `master` SHA `73761eaa7b7d7c965eb443bb7af5f96060ebffec`

## Requested outcome

Run a bounded four-hour local TFTMAC DEV optimization sweep that consumes the current authoritative specs and the surviving native telemetry, tests only research-backed adjustable settings with plausible performance upside, keeps repeatable net gains even when small, logs/reverts losers, and advances to the next candidate. Minimize time spent rebuilding or relaunching. Protected Control/LKG must remain untouched.

## Current governing authority

Read/reconciled current `facts.md`, `project.md`, `CHANGELOG.md`, `benchmark.md`, `dev.md`, `settings.md`, current OvernightLab authority/manifest/controller, current DEVHighPerf profile assets, current 60-FPS/fast-wins plans, research docs, Sept. 10 result logs, and surviving native SQLite captures.

Current working authority remains:
- DEV winner `DEV-B8-WIN-01`.
- `/Applications/TFTMAC DEV.app`, advanced_diagnostics / StockShadow.
- 1920x1080 / 320 DPI / 60 Hz.
- effective 8 vCPU / 6144 MiB.
- official TFT `18.1-5423749` / `8423749`.
- selected game RHI `OPENGL_ES_ANGLE`.
- multifile cache ON, `preferSubmitAtFBOBoundary` disabled, `syncMonolithicPipelinesToBlobCache` removed.
- continuous useful 60 FPS is the cumulative target; there is no fixed positive-gain floor for a verified repeatable net improvement.

## Logging audit

The ignored derived OvernightLab database/screenshots from the closed prior worktree are unavailable and will not be reconstructed. Primary raw evidence survives in `~/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures/*/TFTMAC_NATIVE_RUNTIME.sqlite`.

Read-only Sept. 10 SQL audit confirmed a wide performance envelope on the current line, including:
- a long near-60 run with 823,403 exact intervals and 8,974 available one-second windows; mean effective FPS about 59.834, median about 59.980, while 1% low/tails still expose nonzero pressure;
- heavier captures around 51.8–53.9 mean FPS with materially worse 1% lows and p95/p99;
- a later 49.7 mean-FPS run with poor tail behavior;
- queue-submit-inline produced no usable frame evidence and remains rejected.

Conclusion: the current line is often close to 60 in light/planning states but still loses useful cadence under heavier CPU/RHI pressure. Candidate selection should target contention/tail work, not pixel-count shortcuts or already-rejected transport paths.

## Host readiness

- No current TFTMAC DEV core, owned StockShadow qemu/5586 process, or OvernightLab campaign was running at preflight.
- Internal free space approximately 21 GiB; external free space approximately 140 GiB. Both exceed the prior 8 GiB / 20 GiB campaign safety floors.
- Current installed DEV profile is signed/installed and available; no rebuild is required to begin profile-overlay experiments.

## Material authority reconciliation discovered

Merged master source is stale for exactly the DEVHighPerf profile currently installed and used by the valid native logs:
- installed/current DeviceProfiles SHA-256: `45d6465040ef8b7298cd8da000208e4ee0be924c65a20326900267f25adf5c9c`;
- merged-source DeviceProfiles SHA-256: `aa9672cd730e5e3c32e6c9a793a4ef98bef90d80124c7e22b196d2e174af07e1`;
- only effective profile delta: `r.MobileContentScaleFactor=0.0` installed/current versus `1.0` merged source, in both base sections;
- installed/current profile transaction SHA-256: `7d7d89df8db6927b09d4e2866aac932f9924b729584797e8364077102eeb5835` versus stale merged `5718319c...`; its only semantic delta is the expected current profile hash.

The exact current profile/transaction/README already exist in preserved change `bddd2d6c-a2ed-46fb-9e9e-6674bfdf3541`. That change's old facts/project docs are stale and are NOT authority. Only the exact proven installed-resource bytes are admitted. This new change will converge only those three profile resource files before the new workflow runs. No unrelated bddd login work is imported.

## Historical/research exclusions

Do not automatically rerun: buffer retention, direct Vulkan, queue-submit-inline, virtual-queue-off, fence-contexts-off, historical ASG 400us/alternate rings/write steps/buffers, pipe transport, MoltenVK command-buffer/synchronous-submit variants, VirtioGpuNativeSync/Next, descriptor batching off, more RAM/vCPU as an assumed optimization, Home Run A / Riot Performance Mode, MSAA2, material-quality-1, OneFrameThreadLag=0, forced half-rate animation, blind 50% scale, broad shader prewarm, or prior rejected PBE candidates.

Do not admit `r.MobileContentScaleFactor=1.0` in this first sweep: current accepted profile uses `0.0` native resolution; 1.0 intentionally lowers internal render scale and would trade image quality for FPS rather than test an efficiency unlock.

Do not re-enable `preferSubmitAtFBOBoundary`: current ANGLE source history explicitly disables this for real vsynced applications because early submit did not benefit that workload class and could increase power; current WIN-01 remains aligned with that direction.

## Evidence-grounded first queue

1. `pso-precompile-threads-2`: `r.pso.PrecompileThreadPoolSize` 4 -> 2. Epic PSO precache guidance identifies this as the exact precompile-thread count and warns that many concurrent compile threads can be heavy during gameplay. Current guest has 8 vCPUs and heavy captures show CPU/RHI pressure.
2. `shader-background-batch-4`: `r.ShaderPipelineCache.BackgroundBatchSize` 20 -> 4. Epic FShaderPipelineCache documents this as background-mode PSO batch size and distinguishes background interactive use from fast/load-screen batches. This is a direct contention/burst-control hypothesis.
3. `animation-budget-5ms`: `a.Budget.BudgetMs` 6.0 -> 5.0. Epic Animation Budget Allocator documents this as the game-thread skeletal-animation budget; current heavy TFT battles are unit/animation dense, so a modest reduction may protect frame cadence while retaining visual correctness.
4. `animation-budget-4ms`: 5.0 -> 4.0 ONLY if the 5ms parent is positive and confirms. This is an adaptive refinement, not an unconditional queue item.

Potential later candidates such as shader foreground BatchSize/BatchTime remain lower-confidence and are not added merely to fill time.

## Simplest viable workflow

Reuse OvernightLab's existing proven primitives: official GUI/session launch, current guest-property application before TFT, exact runtime/client/RHI verification, Tocker navigation, native SQLite frame measurement, bind-mounted private DeviceProfiles overlay, exact hash/readback, normal AppKit quit, AVD restoration, native capture import, rollback proof, checkpoint/resume, failure quarantine, and report generation.

Do NOT create another app, SDK, emulator, AVD, VM, database service, profiler, or build farm. Do NOT rebuild TFTMAC per candidate. The campaign uses the already-installed DEV app and external exact-one-CVar profile overlays.

Although a persistent one-emulator hot loop could save launch time, it adds new mount/session/configuration-identity/recovery states. The current robust full candidate lifecycle is already proven. For this four-hour pass the efficient safe baseline is ZERO app rebuilds and one necessary cold DEV lifecycle per control/candidate/confirmation, with short same-stage native measurements. Add a hot-loop state machine only if measured campaign timing later proves launch overhead is the limiting factor.

## Measurement / promotion discipline

- Each candidate is generated on the latest campaign working profile, not the frozen LKG.
- Each candidate differs from its campaign working profile by exactly one declared CVar; all repeated occurrences of that CVar are changed consistently and no other profile key may drift.
- Use current official client/RHI and native SurfaceFlinger-derived frame windows only.
- Compare the candidate to a current matched campaign control at the same Tocker stage using the v4 cumulative doctrine.
- Any directional gain may be `PROMISING` when no material regression/correctness/usability veto fires.
- PROMISING requires one cold confirmation before entering the campaign working stack.
- A confirmed campaign win advances the local working-profile stack. Formal `DEV-B8-WIN-##` project authority promotion is reconciled from the final combined confirmed stack, so the 4h automation does not churn source authority between every screening pair.
- Reject/inconclusive -> preserve result, restore current campaign working profile, move on.
- Unproven rollback -> stop immediately; never advance the queue.

## ZenGate

PASS.
- Every admitted candidate maps to a current exposed CVar, current runtime evidence, and an engine/runtime source describing the relevant performance mechanism.
- Already-resolved/stale/PBE/quality-sacrifice candidates are excluded.
- Existing OvernightLab lifecycle/rollback/native telemetry is reused.
- No per-candidate rebuild is required.
- New code is limited to generalizing the already-proven profile-overlay primitive, matched comparison/promotion logic, a bounded incremental manifest, and durable 4h orchestration.
- The protected Control/LKG and Riot-signed package remain outside mutation scope.
- Complexity removal test passes: no proposed new service/store/runtime/identifier is necessary beyond the campaign-local profile/result identities already required for exact comparison and rollback.

ZenMC qualification: `ZENMC_REQUIRED` because the four-hour workflow includes durable asynchronous execution, restart/recovery, checkpoint/resume, candidate promotion, conditional follow-up, rollback, deadline, and failure combinations.
