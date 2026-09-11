# TFTMAC four-hour incremental sweep — final results

Campaign: `incremental-20260911T082151Z-1f32770a`  
Governed change: `25f21f7e-ba86-4e3d-832d-9984522811c0`  
Start: `2026-09-11T08:21:51Z`  
Immutable deadline: `2026-09-11T12:21:51Z`  
Terminal state: `DEADLINE_COMPLETE`  
Base/final winner: `DEV-B8-WIN-01`  
Final working DeviceProfiles SHA-256: `45d6465040ef8b7298cd8da000208e4ee0be924c65a20326900267f25adf5c9c`  
Accepted cumulative candidates: none  
Rollback/integrity: PASS for every recorded run; protected Control/LKG remained unchanged.

## Candidate decisions

| Candidate | Exact intended delta | Result | Integration |
| --- | --- | --- | --- |
| `pso-precompile-threads-2` | `r.pso.PrecompileThreadPoolSize` `4 -> 2` | `INCONCLUSIVE` — matched control became valid, but candidate apply failed because ADB shell privilege was not restored after root use; no admissible candidate performance windows | NO |
| `shader-background-batch-4` | `r.ShaderPipelineCache.BackgroundBatchSize` `20 -> 4` | `INCONCLUSIVE` — matched control became valid, but candidate apply failed because ADB shell privilege was not restored; no admissible candidate performance windows | NO |
| `animation-budget-5ms` | `a.Budget.BudgetMs` `6.0 -> 5.0` | `INCONCLUSIVE` — matched control became valid, but candidate apply failed because ADB root did not become effective; no admissible candidate performance windows | NO |
| `animation-budget-4ms` | `a.Budget.BudgetMs` `5.0 -> 4.0` | `SKIPPED_PARENT_NOT_ACCEPTED` as required because the 5 ms parent did not confirm | NO |

No directional candidate gain can be claimed because none of the candidate profiles produced valid measured candidate windows. These settings are therefore unresolved, not rejected, and must not be entered on the no-recycle list solely from this campaign.

## Matched current-winner controls

The final valid 1-5 control runs on `DEV-B8-WIN-01` produced:

- PSO matched control `run-382fa917a73e49d2b60732d120c93199`: mean 53.954 FPS, mean 1% low 23.251 FPS, mean p95 25.210 ms, mean p99 36.506 ms across 3 native windows.
- Shader-background matched control `run-6f0521267dad47e5af07e0b07d59dccf`: mean 58.144 FPS, mean 1% low 41.095 FPS, mean p95 20.766 ms, mean p99 24.578 ms across 3 native windows.
- Animation-budget matched control `run-02cb6209b65345fa8f45073bf9d72262`: mean 59.718 FPS, mean 1% low 35.424 FPS, mean p95 20.110 ms, mean p99 27.801 ms across 3 native windows.

These are baseline observations only; they do not establish a candidate improvement.

## Stability evidence after queue exhaustion

The working stack never changed from `DEV-B8-WIN-01`. Three stability-control runs completed with valid native 1-5 windows:

- `run-1aacb80614c841cdb92f6afacb924b76`: 57.687 FPS, 1% low 28.563 FPS, p95 20.677 ms, p99 34.411 ms, jank rate 0.0240, severe rate 0.
- `run-5156270168b54271981aef45d388704a`: 58.657 FPS, 1% low 29.441 FPS, p95 19.716 ms, p99 29.954 ms, jank rate 0.0176, severe rate 0.00293.
- `run-6ecaaf8ba33144699a89fc662cbda88b`: 59.789 FPS, 1% low 40.990 FPS, p95 19.092 ms, p99 23.170 ms, jank rate 0.00867, severe rate 0.

A fourth stability run, `run-b218cc8ef58e4aafa56ac1686ade965c`, was `INCONCLUSIVE` because the expected ADB device disappeared before measurement. Its rollback still passed. This lowers additional soak confidence but does not invalidate the three green stability runs or change the working profile.

## Native capture authority

Key current-client native SQLite evidence proving the final decisions:

- PSO control: `2026-09-11T09-02-10.398Z-bcb9464d-f37d-478a-9ee0-4406c3ce2597`, SHA-256 `def22f2c57cb14addbec982c6c7bc1f2096221e5ffd1952ef8cf0722e1174fbd`.
- PSO candidate attempt: `2026-09-11T09-05-57.862Z-f4f37053-86f8-40c8-8542-cce32461e597`, SHA-256 `9a38380dbb836ec82de4d2526d73e3cb5e4b701ef101558d8dbd0bcd24eba2b1`.
- Shader control: `2026-09-11T09-06-45.013Z-c86c72af-4603-499e-8c92-58f6054edbb5`, SHA-256 `9353535b58bbb370618611d8bc7db91f7bbf0e16a07f7a373277e74c66971f84`.
- Shader candidate attempt: `2026-09-11T09-07-59.360Z-cf54aecb-82ec-41c5-b577-8abce7f28a57`, SHA-256 `7d66f8266183254c62f5fa480f0e84c4f08d1515e4605c8bd6d04e2a0c29c765`.
- Animation control: `2026-09-11T09-08-45.780Z-042b0701-5250-445f-93d1-cad0d023b870`, SHA-256 `767969a81806f2ab74a026e28d85b631a26005929a56a5a49b4518f3967ce615`.
- Animation candidate attempt: `2026-09-11T09-10-00.670Z-90d45bde-3fa0-4f6d-83b2-22c936658fa3`, SHA-256 `a209ba85773882b79b8147779c406fbb67a12dcb723ba7c4ea7ca3168e651cc8`.
- Green stability captures: `2026-09-11T09-10-46.345Z-3a64aae6-53c5-43e0-8ad1-64ebd974c7ce` (`0d69c3c09b78ab2c0e4e6f7a22a9d3050f73c23a47f48e2de0abc69d3985692f`), `2026-09-11T09-12-04.231Z-b0c427f0-620a-442b-91d7-e9da3089e8d9` (`5bec5fd6302246a243ab8999a3dfdbe2a4d14299b0c4a2f3138faf8333456f7d`), and `2026-09-11T09-13-19.773Z-1d0c6b04-fa79-4251-8f0e-5493a219646e` (`fa5a0fac8cd0ca422d31041d99dda366907224895fb8ba9a415e9b7c589d1096`).
- Inconclusive stability capture: `2026-09-11T09-14-35.174Z-a3310613-2619-4e5d-b0df-2523903d6306`, SHA-256 `c77d0ae1d850413964715c216a098be65ea9e87a521c107e08c22adbc90b877e`.

All evidence used the official live package `com.riotgames.league.teamfighttactics` `18.1-5423749` / `8423749` and current DEV route. Raw capture remains authoritative.

## Correctness, rollback, and infrastructure findings

- Every campaign run has verified DEV stop, emulator stop, profile restore, installed DEV integrity, and frozen LKG integrity.
- No candidate setting was retained; final working profile bytes are identical to the campaign start profile.
- Campaign execution exposed and repaired three controller/classifier blockers without changing protected Control/LKG: false cross-line `ERROR` OCR matching; missing Tocker 1-5 score-only combat-phase classification; and non-durable process-local deadline persistence. The stability tail was also corrected so an inconclusive evidence-only soak is logged rather than aborting when rollback is verified.
- Candidate application remains unable to provide a reliable root/unroot bind-overlay transaction on this runtime. That is the prerequisite for a future valid CVar campaign, not evidence that any of the three candidate CVars are bad.

## Distance to continuous useful 60 FPS

The sweep produced **zero verified configuration gain** because the accepted stack did not change. It therefore does not move the formal winner beyond `DEV-B8-WIN-01`. It did add current 1-5 stability evidence showing the existing winner can run near the 60 FPS target for bounded windows, including a 59.789 FPS three-window mean on the strongest soak, while lower 1% lows and run-to-run variance confirm continuous useful 60 FPS is not yet proven.

## Strongest evidence-backed next test

No new setting family earned comparative evidence in this campaign. After the DeviceProfiles bind-overlay root/unroot transaction is made reliable in a separately governed future run, the first unresolved evidence-backed setting to retest remains `r.pso.PrecompileThreadPoolSize=2` because it was first in the approved queue and never received a valid candidate measurement. The shader-background and 5 ms animation-budget candidates likewise remain unresolved. Do not run the conditional 4 ms animation budget unless 5 ms first confirms positive.

## Do-not-repeat boundary

This campaign adds **no new candidate** to the historical do-not-recycle list. Continue to honor the existing rejected/no-recycle families in project authority, including direct Vulkan, queue-submit-inline, virtual-queue-off, fence-contexts-off, prior ASG variants, blind quality cuts, and PBE-derived candidates. Do not mistake the three ADB-invalid candidate attempts in this campaign for performance rejections.
