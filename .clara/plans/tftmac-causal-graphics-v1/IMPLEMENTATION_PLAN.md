---
title: TFTMAC Causal Graphics Optimization and Ultra-High Promotion — Implementation Plan
plan_version: 1.1
date_local: 2026-08-31
project: TFTMAC
request_class: PLAN
implementation_status: READY_FROM_CLEAN_CANONICAL_MASTER_AFTER_GATE_0A
canonical_authority_sha_at_amendment: c8b79ea009197c25bc7e64bebd5e8948eea918b1
authority_inputs_sha256: 1d85f4f2f64f3b6089c79385b329dfe42bb479b8c65877c39bf01bdef13703ac
amendment_zenmc_model_sha256: e67e5473b309a210816b87dc55c0765567e4d996b48c9ca982eeb66863d7ad85
scope_lock_sha256: dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e
zenmc_receipt_sha256: 4f0d706f7c5bf5d7f88a1fb4363ef6efeb9f57f678f78a39cf30fec3c5bf1c80
---

# TFTMAC Causal Graphics Optimization and Ultra-High Promotion

## 0. How Local Codex must use this file

This is the implementation authority for building the causal graphics logger, deriving a narrowly supported runtime setting or source patch, and promoting the highest accepted TFT quality tier.

Local Codex must read the entire file before changing source. It must execute the phases in order, preserve existing local work, and stop each wave at its acceptance gate. A later phase does not authorize skipping an earlier gate.

This plan is intentionally robust to a local checkout that is newer than GitHub or newer than Clara's registered worktrees. Gate 0 establishes the actual local authority before any implementation edit.

## 1. Current observed project state and evidence limitation

Clara's most recent registered local observation, at approximately 2026-08-31 19:20 America/Chicago, showed:

- Canonical project: `flashls1/TFTMAC`
- Canonical branch: `master`
- Canonical HEAD: `365e891ea2950e2cc68a9e4fec683c8538a831e6`
- Canonical checkout: clean and aligned with `origin/master`
- Most advanced managed convergence change:
  - change: `43c40d13-47c8-4396-8ee5-62a17184e847`
  - branch: `clara/finish-tftmac-clean-convergence-and-nati-43c40d13`
  - committed HEAD: `f439b241c1fa0a215ac0270bb49380eff8f6d084`
  - uncommitted protected work:
    - deleted `Probes/EmbeddedControlProbe/main.swift`
    - modified `TFTMAC.xcodeproj/project.pbxproj`
    - modified `scripts/verify-tftmac.command`
    - modified `tools/tftmac-direct-control.mjs`
    - untracked `Probes/EmbeddedControlProbe/EmbeddedControlProbe.swift`

Those local changes are native EmulatorController probe work, not the causal logger.

Clara cannot truthfully assert the state of an unregistered Codex clone such as the path referenced by the attached design document. Therefore:

> The current local checkout used by Codex may be newer. It becomes authority only after Gate 0 records its repository identity, HEAD, status, worktrees, and hashes without deleting or resetting anything.

## 2. Source design incorporated by this plan

The attached design requires replacement of the current symptom logger with an automatic source-instrumented causal logger. Each degradation episode must terminate in an honest `ROOT_CANDIDATE`, `ROOT_NAMED`, or `UNKNOWN`, with the proven playable runtime left untouched and a separately selectable diagnostic runtime used for source instrumentation.

This plan preserves that design and adds the following mandatory corrections:

1. Formal authority amendment before reviving any source-built diagnostic runtime.
2. A renderer-path receipt before excluding ANGLE.
3. An uninstrumented stock-to-diagnostic symptom-parity gate.
4. Hard lineage from transport work to actual presentation.
5. A fixed ring/clock/seal ABI.
6. Deterministic incident and statistical rules.
7. Separate logger acceptance, diagnostic representativeness, root discovery, patch acceptance, and quality promotion.
8. A production candidate mode distinct from both control and diagnostics.
9. A final quality ladder targeting `Ultra High / 60 FPS / Performance Mode OFF / 1920x1080`.

## 3. Product outcome and hard win condition

The program is complete only when all of the following are proven:

1. The current playable stock runtime remains available as `control` and is never silently modified.
2. The causal logger can identify the earliest supported divergent owned boundary and fails closed when identity, timing, parity, or ownership is missing.
3. Controlled injected faults at every instrumented boundary are localized correctly.
4. A real TFT degradation produces either:
   - a replicated `ROOT_NAMED` in owned code; or
   - an exact honest unowned/invalid boundary such as `UNREAL_OR_PRE_ENCODER_UNKNOWN`.
5. A setting adjustment or open-source code patch is created only from a valid owned `ROOT_NAMED`.
6. The patch passes randomized matched A/B validation with instrumentation disabled.
7. A stock-compatible `candidate` runtime passes official Google Play/TFT/Riot lifecycle and rollback gates.
8. TFT passes the live 600-second acceptance window at:
   - graphics: `Ultra High`
   - frame cap: `60`
   - Performance Mode: `OFF`
   - render/display target: `1920x1080 @ 60 Hz`
9. Final performance acceptance:
   - average presented FPS `>= 58.0`
   - p95 presented interval `<= 20.0 ms`
   - p99 presented interval `<= 33.334 ms`
   - intervals above `33.334 ms` `<= 1.0%`
   - intervals above `100 ms` `<= 3` per 600 seconds
   - no renderer crash
   - no Vulkan device loss
   - no repeated validation/error storm
   - no login, input, audio, visual-correctness, package-authority, or reconnect regression
10. The accepted candidate has a one-action rollback to the untouched control runtime.

`Ultra High / 60 / OFF` is the quality goal because the product refresh target is 60 Hz. An uncapped mode is not a higher visual-quality tier and is outside this plan unless separately authorized after Ultra High/60 succeeds.

## 4. Non-negotiable boundaries

- Official package: `com.riotgames.league.teamfighttactics`
- Installer/update authority: `com.android.vending`
- No Riot binary or APK modification.
- No repacking, re-signing, process injection, or anti-cheat bypass.
- No credential, token, screenshot, or shader-content capture.
- No fabricated line-level attribution inside signed Riot/Unreal code.
- No broad optimization campaign before a root receipt.
- No quality reduction, dynamic resolution reduction, resolution lowering, or Performance Mode enablement to claim the quality target.
- No hidden dependence on a retired application, retired project, or abandoned source-build tree.
- Raw evidence is authoritative; SQLite and AI-readable reports are derived and rebuildable.
- AI explains an immutable deterministic finding. AI never decides `ROOT_NAMED`.

# PART I — AUTHORITY, PRESERVATION, AND CONTROL

## Phase 0 — Reconcile actual local truth and protect concurrent work

### Objective

Establish the exact local checkout Codex will edit, preserve all uncommitted work, and create a new implementation branch from the newest compatible local authority.

### Required actions

From the checkout Codex intends to use, record:

```bash
pwd
git rev-parse --show-toplevel
git rev-parse HEAD
git branch --show-current
git status --porcelain=v2 -b
git remote -v
git worktree list --porcelain
git submodule status --recursive || true
```

Create:

```text
.clara/plans/tftmac-causal-graphics-v1/
├── LOCAL_AUTHORITY.json
├── PREFLIGHT.md
├── IMPLEMENTATION_PLAN.md
├── ZENMC_RECEIPT.json
├── SCOPE_LOCK.txt
└── protected-local-work/
```

`LOCAL_AUTHORITY.json` must include:

```json
{
  "repository_root": "...",
  "repository_remote": "...",
  "branch": "...",
  "head_sha": "...",
  "status_porcelain_v2_sha256": "...",
  "worktree_inventory_sha256": "...",
  "observed_at": "...",
  "known_clara_master": "365e891ea2950e2cc68a9e4fec683c8538a831e6",
  "known_clara_advanced_change": "43c40d13-47c8-4396-8ee5-62a17184e847",
  "known_clara_advanced_head": "f439b241c1fa0a215ac0270bb49380eff8f6d084"
}
```

If the checkout is dirty:

1. Do not run `git reset`, `git clean`, checkout-overwrite, or destructive rebase.
2. Save:
   - `git diff --binary`
   - `git diff --cached --binary`
   - untracked-file manifest with SHA-256
3. Create a checkpoint commit or a separate preserved worktree/branch.
4. Confirm the five currently known native-controller files remain preserved if they exist.
5. Create the new implementation branch from the newest compatible preserved HEAD:

```text
codex/tftmac-causal-graphics-v1
```

### Drift resolution

- If local Codex files are newer than Clara/GitHub, retain them and record their hashes.
- If local files conflict with the attached logger design, classify each conflict:
  - `NEWER_COMPATIBLE`
  - `NEWER_REQUIRES_PLAN_AMENDMENT`
  - `UNRELATED_PROTECTED_WORK`
  - `STALE_SUPERSEDED`
- Only `NEWER_REQUIRES_PLAN_AMENDMENT` may alter later scope, and only through an append-only amendment plus a targeted ZenMC rerun.

### Gate 0 acceptance

PASS only when:

- all local modifications are recoverable;
- the exact implementation checkout is identified;
- no existing worktree has been overwritten;
- the plan files and scope lock are persisted;
- the implementation branch base is recorded;
- `git diff --check` passes for the preserved state.

Failure result:

```text
BLOCKED_LOCAL_WORK_UNPRESERVED
```

## Phase 1 — Formal authority amendment and canonical documentation

### Objective

Make the diagnostic source-build exception explicit without undoing clean-ownership decisions.

### Required documents

Use the canonical project documentation locations discovered in Gate 0. If root `facts.md`, `benchmark.md`, or `dev.md` do not exist, create them or place their exact required content in the existing canonical `docs/`/`ssot/` authority and record the mapping.

Required authority statements:

1. `control` is the protected playable runtime.
2. Source-built AEMU/gfxstream/MoltenVK is authorized only as an isolated diagnostic instrument.
3. The diagnostic source root must be new and must not silently resurrect the abandoned `/Volumes/MAC MINI M4/TFTMAC/Build`.
4. Diagnostic performance is not directly promotable to stock.
5. `MATCH_ENTRY` and `MATCH_RESULT` are optional annotations only.
6. Graphics lifecycle begins from TFT process plus exact SurfaceView/layer appearance and ends when that generation disappears.
7. The native presenter remains hidden context-only evidence.
8. Riot/Unreal internals are opaque.
9. The final visual target is Ultra High/60/Performance Off at 1920x1080.
10. A production patch is restricted to owned open-source runtime components.

Create:

```text
ssot/TFTMAC_CAUSAL_GRAPHICS_AUTHORITY.md
ssot/TFTMAC_CAUSAL_GRAPHICS_SCHEMA.md
docs/causal-graphics-logger.md
docs/graphics-optimization-promotion.md
```

The authority file must explicitly supersede only the source-build prohibition for this isolated diagnostic purpose. It must not supersede the protected stock-runtime, package-authority, clean-ownership, or no-Riot-modification rules.

### Existing 42-minute capture

Do not promote the stated 42-minute metrics to durable authority unless Codex locates:

- capture directory or archive;
- raw manifest SHA;
- exact TFT layer identity;
- normalizer version/hash;
- query text/hash;
- coverage calculation;
- output receipt.

If those are not present, store the values as:

```text
CLAIMED_PRIOR_OBSERVATION_NOT_YET_RECEIPTED
```

### Gate 1 acceptance

PASS when the authority amendment is internally consistent, all referenced paths exist, and a repository search proves no document still claims both “source build forbidden” and “source build required” without the diagnostic-only exception.

Failure result:

```text
BLOCKED_AUTHORITY_AMENDMENT
```

## Phase 2 — Freeze the protected control and the promotion target

### Runtime modes

Define exactly three modes:

```text
control
advanced_diagnostics
candidate
```

- `control`: current packaged playable runtime and control AVD; default until final cutover.
- `advanced_diagnostics`: isolated source-instrumented runtime and diagnostic AVD; never used for direct stock performance promotion.
- `candidate`: release, instrumentation-disabled, stock-compatible runtime containing only an accepted setting profile or patch.

Add a single mode registry, for example:

```text
ssot/runtime-modes.json
```

Each mode entry must specify:

- executable and library roots;
- AVD identity;
- ADB/console lease;
- manifest;
- configuration SHA;
- allowed purpose;
- comparability class;
- rollback target.

Only one mode may own the AVD/ADB lease at a time. Preserve the current packaged macOS launch chain and logged-in user context.

### Control receipt

Before diagnostic work, record:

- runtime binary SHA/UUID;
- emulator version;
- package version/signature/installer;
- renderer and graphics transport observations;
- exact display/layer identity;
- High/60/Performance Off settings;
- audio/input/login state;
- baseline performance receipt if a valid current run exists.

### Gate 2 acceptance

PASS only when selecting `control` is deterministic, leaves the known playable AVD intact, and produces a complete control receipt.

# PART II — PROVE THE REAL PIPELINE BEFORE INSTRUMENTING IT

## Phase 3 — Renderer-path and exact-surface receipt

### Objective

Prove whether the exact TFT gameplay SurfaceView is driven by direct Vulkan, ANGLE, or a mixed path.

### Evidence to collect

For the exact TFT process and exact gameplay surface generation:

- PID/process generation.
- `/proc/<pid>/maps` library inventory.
- package/activity identity.
- Vulkan instance/device/queue creation evidence.
- loaded ANGLE/EGL/GLES libraries.
- emulator/gfxstream renderer logs.
- SurfaceFlinger layer list and generation.
- color-buffer and queue identities where available.
- relationship between API submissions and the exact gameplay layer.

### Required decision

```text
DIRECT_VULKAN_PROVEN
ANGLE_PATH_PROVEN
MIXED_PATH_PROVEN
UNKNOWN_RENDERER_PATH
```

ANGLE instrumentation may be omitted only for `DIRECT_VULKAN_PROVEN` and only when the receipt proves ANGLE does not contribute work to the exact gameplay layer. Otherwise, add an ANGLE branch to the instrumentation map.

### Gate 3 acceptance

A signed/hash-addressed `PIPELINE_RECEIPT.json` exists and all later instrumentation stages match its decision.

Failure result:

```text
UNKNOWN_PIPELINE_RECEIPT
```

# PART III — ISOLATED DIAGNOSTIC RUNTIME

## Phase 4 — Create the diagnostic source authority and build root

### New external root

Use a new root such as:

```text
/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/
├── Sources/
├── Build/
├── Install/
├── Symbols/
├── Manifests/
├── Traces/
└── AVD/
```

Do not reuse or recreate the retired general-purpose Build tree.

### Initial pinned authority

Unless Gate 0 discovers a newer approved local lock, begin from the existing frozen source family:

```text
AEMU branch: emu-master-dev
QEMU: ae9d18d2b6261179fbd57fffec720a04f7bfb053
AEMU: 3c1ced8a369417db591eb7cd083af5bb2c317975
gfxstream: d047a57228332d995d36600792fa9ccc26cf8ae6
ANGLE: 901e32aa9923b05c3a2af846f8a28fc79c93d0be
integrated MoltenVK prebuilt authority: fb26612eb84576adb974fe7f18a49d263072116f
MoltenVK reference: db66022459ffb663aa2b50f6b018bc2e124f5edf
manifest SHA: 28865cd8a162178ba462b296f5714b6b7b6916e0cafcddfc0c5e44aa03f8e8d3
```

Gate 0 may supersede these only with a newer pinned project authority.

### Build requirements

- Optimized release code.
- Debug symbols and dSYMs retained.
- gfxstream tracing compiled in.
- No debug assertions or validation layers during measured runs unless the specific experiment requires them.
- Build manifest includes:
  - remotes;
  - full commits;
  - dirty state;
  - source blob hashes;
  - build flags;
  - compiler/Xcode versions;
  - binary SHA/UUID;
  - dSYM UUID/hash;
  - instrumentation schema hash;
  - site-manifest hash;
  - runtime configuration hash.

At launch, loaded binary identities must match the manifest or the run fails before TFT starts.

### Diagnostic AVD

Use a separate AVD identity. It may be created from a safely stopped clone only when the clone operation is recorded and the control AVD is untouched.

It must independently pass:

- Google Play installer authority;
- official TFT version/signature;
- Riot login;
- first gameplay frame;
- exact renderer path;
- exact layer;
- input;
- audio;
- reconnect/session behavior.

### Gate 4 acceptance

```text
DIAGNOSTIC_BUILD_IDENTITY_PASS
DIAGNOSTIC_AVD_ACCEPTANCE_PASS
```

Failures leave control untouched.

# PART IV — EVENT ABI, WORK IDENTITY, AND PRESENT LINEAGE

## Phase 5 — Define `PipelineEventV1`

### Fixed record contract

Use a fixed-size, little-endian binary record. A 128-byte layout is recommended. It must contain only fixed-width values:

```text
magic
schema_version
record_size
event_kind
flags
loss_state
diagnostic_epoch_id
manifest_short_id
producer_instance_id
process_id
thread_id
device_id
queue_id
clock_domain_id
site_id
span_id
transport_work_id
present_lineage_id
generation
producer_sequence
parent_work_id
timestamp_ns
duration_or_value_ns
value0
value1
result_code
```

No strings, dynamic arrays, heap allocation, formatting, file I/O, SQLite, symbolization, or blocking synchronization are allowed in a hot hook.

### Site manifest

Generate a static immutable manifest mapping `site_id` to:

- component;
- semantic boundary;
- event kind;
- full source commit;
- file blob SHA;
- file and function;
- line/range;
- site-range hash;
- loaded binary SHA/UUID;
- instrumentation schema.

Line number is navigation metadata. Commit, blob, binary, schema, and site-range hashes are authority.

### Span authority

A slow operation is normally attributed to a span:

```text
root_span_id
start_site_id
end_site_id
decisive_child_site_id nullable
```

Do not collapse a slow span to one exact line unless child evidence isolates that site.

### Gate 5 acceptance

- duplicate site IDs fail the build;
- record ABI self-test passes on every producer;
- binary and site manifests match;
- old readers reject unsupported schema instead of misparsing.

## Phase 6 — Prove `transport_work_id` and `present_lineage_id`

### `transport_work_id`

First audit existing gfxstream negotiated sequence IDs. Reuse an existing protocol identity if it crosses:

```text
guest encode
→ ASG write
→ host receive
→ decode
→ host queue submission
→ completion
```

Call it `transport_work_id`, never `frame_id`.

If the existing protocol cannot preserve identity, add the smallest diagnostic-only sideband. The official TFT APK remains unmodified.

### `present_lineage_id`

Add a separate identity chain for presentation:

```text
transport work
→ host Vulkan submission
→ Metal command buffer
→ color-buffer generation
→ QSRI/release fence
→ emulator source-frame sequence
→ Android buffer generation
→ SurfaceFrame/DisplayFrame token or proven fallback
→ exact TFT actual presentation
```

Include generation counters so handle reuse cannot alias old and new work.

### Required identity fixtures

Prove:

- one-to-one;
- one-to-many;
- many-to-one;
- batching;
- out-of-order completion;
- queue-handle reuse;
- color-buffer reuse;
- surface recreation;
- producer restart;
- sequence wrap;
- dropped-event invalidation.

Timestamps may corroborate identity but may never create it.

### Gate 6 acceptance

At least 99.9% of eligible diagnostic presentation samples must join from the first owned hook to the exact TFT presentation endpoint with no ambiguous generation. Any incident with identity loss is `UNKNOWN_PRESENT_LINEAGE_GAP`.

# PART V — SOURCE INSTRUMENTATION

## Phase 7 — Instrument the approved boundaries

Instrument only boundaries supported by the renderer receipt.

### Required direct-Vulkan stages

| Order | Component/boundary | Required events |
|---:|---|---|
| 1 | Guest Vulkan encoder | `vkQueueSubmit` encode begin/end, submit count, queue/device, transport ID |
| 2 | Guest ASG writer | wait begin/end, bytes, write, flush, ring/backpressure |
| 3 | Host ASG receiver | first byte, complete packet, queue depth, receive wait |
| 4 | gfxstream decoder | decode begin/end, dispatch identity, command count |
| 5 | Host Vulkan queue | queue-lock wait/acquire/release, submit entry/return/result |
| 6 | MoltenVK | pipeline create begin/end, cache hit/miss/unknown, enqueue, Metal association |
| 7 | Metal | command-buffer commit, scheduled callback, GPU start/end when valid, completion/result |
| 8 | Android buffer/QSRI | color-buffer ready, QSRI, acquire/release fence identity and wait |
| 9 | Emulator output | source-frame sequence, new/repeated/stale source status |
| 10 | SurfaceFlinger endpoint | exact TFT present/latch endpoint and actual present classification |

### Conditional ANGLE stages

If Gate 3 returns ANGLE or mixed:

- EGL/ANGLE submit entry/exit;
- ANGLE Vulkan translation work identity;
- ANGLE pipeline/shader translation and cache receipt;
- association to the exact gameplay surface.

### Metal timing

Distinguish:

- CPU commit time;
- scheduled-handler time;
- valid `gpuStartTime`;
- valid `gpuEndTime`;
- completed-handler time.

Do not report scheduled/completed callback deltas as GPU execution time.

### MoltenVK pipeline data

Record pipeline-cache use and creation time. Do not enable internal-representation/statistics capture during performance measurement unless a separate diagnostic experiment proves its observer cost acceptable.

### Gate 7 acceptance

Every instrumented site compiles in release mode, appears in the site manifest, has a controlled-delay fixture, and emits the expected identity.

# PART VI — LOW-OVERHEAD COLLECTION, CLOCKS, AND SEALS

## Phase 8 — Per-thread rings and drain architecture

### Hot-path design

Use one preallocated SPSC ring per registered emitting thread. Registration may allocate before measured work begins. Emission after registration is fixed-record only.

If a thread appears after measurement begins:

- allocate/register outside the graphics critical section if possible;
- otherwise mark that producer `UNINSTRUMENTED_THREAD` and invalidate attribution across its boundary.

### Capacity

For each producer:

```text
capacity >= max(
  4 × measured peak records/second × 10 seconds,
  records needed for 5-second prehistory + 60-second incident segment + 5-second posthistory
)
```

Cap memory explicitly and record the selected capacity in the manifest.

### Overflow

- Never block the producer.
- Increment a monotonic dropped-record counter.
- Emit a loss marker when space returns.
- Any affected incident becomes `UNKNOWN_STREAM_LOSS`.
- No later normalization may hide the loss.

### Drain path

```text
hot hooks
→ fixed binary rings
→ dedicated drain thread
→ append-only binary segment
→ segment hash/seal
→ optional off-path Perfetto mirror
→ post-seal normalizer
```

Perfetto is corroborative; fixed rings are causal authority.

### Segment sealing

Each segment contains:

- epoch/producer/generation;
- first and last producer sequence;
- emitted count;
- persisted count;
- dropped count;
- duplicate count;
- unmatched begin/end count;
- previous segment hash;
- current segment SHA;
- flush result.

### Gate 8 acceptance

Stress above measured peak rate and prove:

- no hot-path allocation;
- no hot-path locks;
- no file or database call;
- deterministic overflow behavior;
- valid hash chain;
- crash leaves the last fully sealed segment valid.

## Phase 9 — Clock-domain calibration

Maintain mappings among:

- guest monotonic;
- host monotonic;
- Perfetto trace clock;
- Vulkan device timestamp domain when available;
- Metal/system mach time.

Use repeated two-way brackets and calibrated timestamp APIs where supported. Each transform records:

```text
source_clock
target_clock
offset
drift
maximum_deviation_ns
valid_from
valid_until
sample_count
receipt_hash
```

Recalibrate:

- at epoch start;
- periodically;
- before and after each incident;
- after sleep/wake;
- after process restart;
- after any discontinuity.

Rules:

- `<= 2 ms`: precise cross-boundary attribution.
- `> 2 ms and <= 10 ms`: ordering only.
- `> 10 ms`: `UNKNOWN_CLOCK_UNCERTAINTY`.

### Gate 9 acceptance

Controlled synchronized markers cross each clock domain within the declared uncertainty, and stale transforms are rejected.

# PART VII — PRESENTATION AUTHORITY AND INCIDENTS

## Phase 10 — Exact TFT presentation endpoint

Perfetto FrameTimeline tables may be queried, but SurfaceView coverage must be proven rather than assumed.

For the exact TFT layer, prove:

- layer name and generation;
- buffer/surface token continuity;
- presentation coverage;
- duplicate/drop semantics;
- agreement with BufferQueue/fence/source-frame identity.

Use:

```text
actual_frame_timeline_slice
expected_frame_timeline_slice
```

only when the exact TFT SurfaceView is represented correctly.

If not, use the instrumented BufferQueue/fence/present chain as authority and retain FrameTimeline as corroboration.

### Gate 10 acceptance

`PRESENT_ENDPOINT_RECEIPT.json` records the exact authority and at least 99% coverage for eligible presented frames. Otherwise:

```text
UNKNOWN_SURFACE_IDENTITY
```

## Phase 11 — Automatic lifecycle and deterministic incident detector

### Lifecycle

Start graphics logging when all are true:

- official TFT process generation exists;
- exact gameplay SurfaceView/layer generation exists;
- renderer-path receipt matches;
- clock and producer health are valid.

End the graphics epoch when the process or exact layer generation disappears. Match markers do not control logging.

### Workload classes

Derive deterministic workload classes from observable lifecycle, not free text:

```text
STARTUP
PATCHING
LOGIN
LOBBY
TRANSITION
GAMEPLAY_LIGHT
GAMEPLAY_HEAVY
SURFACE_RECREATE
UNKNOWN
```

A classifier version/hash is stored with every incident.

### One-second bad window

A one-second window is bad when any is true for the exact TFT present stream:

- presented FPS `< 58`;
- p95 interval `> 20 ms`;
- p99 interval `> 33.334 ms`;
- more than 1% intervals exceed `33.334 ms`;
- any interval exceeds `100 ms`;
- stale/repeated source persists for two or more display intervals;
- exact presentation identity becomes incomplete.

### Incident rules

- Open after two adjacent bad windows.
- Preserve five seconds prehistory.
- Preserve the full incident.
- Preserve five seconds after recovery.
- Merge incidents separated by `<= 2 seconds`.
- Split and chain sealed segments every 60 seconds.
- Surface recreation closes the current generation and opens a new eligible generation after stability.
- Startup/patch/login incidents are retained but not compared to gameplay baselines.

### Gate 11 acceptance

Synthetic timelines exercise open, merge, split, recovery, surface recreation, and exact signature reuse without losing raw evidence.

# PART VIII — SQL KNOWLEDGE BASE AND DETERMINISTIC ANALYZER

## Phase 12 — Append-only schema

Add versioned, idempotent migrations for:

### `pipeline_diagnostic_epochs`

Key fields:

```text
epoch_id
mode
manifest_sha256
runtime_config_sha256
avd_sha256
package_receipt_sha256
renderer_receipt_sha256
present_endpoint_receipt_sha256
clock_receipt_sha256
parity_state
overhead_state
started_at
ended_at
state
```

### `pipeline_events`

Key fields:

```text
epoch_id
producer_instance_id
producer_sequence
site_id
span_id
transport_work_id
present_lineage_id
parent_work_id
generation
clock_domain_id
timestamp_ns
duration_or_value_ns
event_kind
flags
result_code
raw_segment_sha256
```

### `pipeline_stream_seals`

Store all sequence, count, loss, duplicate, unmatched, flush, and hash-chain fields.

### `pipeline_stage_spans`

Store:

```text
epoch_id
incident_id
present_lineage_id
stage
start_site_id
end_site_id
start_ns
end_ns
duration_ns
clock_uncertainty_ns
identity_state
missing_boundary
```

### `pipeline_root_findings`

Insert-only:

```text
finding_id
incident_signature
outcome
unknown_class
component
stage
root_span_id
decisive_site_id
rule_sha256
input_receipt_sha256
healthy_baseline_ids
epoch_ids
confidence
patchable
failed_gate
created_at
```

### Outcome taxonomy

Top-level outcome remains exactly:

```text
ROOT_CANDIDATE
ROOT_NAMED
UNKNOWN
```

Bounded stage is:

```text
outcome = UNKNOWN
unknown_class = BOUNDED_TO_STAGE
```

Other exact unknown classes include:

```text
UNREAL_OR_PRE_ENCODER_UNKNOWN
PIPELINE_RECEIPT_MISSING
ANGLE_PATH_UNINSTRUMENTED
DIAGNOSTIC_NOT_REPRESENTATIVE
PRESENT_LINEAGE_GAP
STREAM_LOSS
CLOCK_UNCERTAINTY
SURFACE_IDENTITY
OBSERVER_EFFECT
HEALTHY_BASELINE_INSUFFICIENT
NO_CAUSAL_FIRST_DIVERGENCE
```

Keep match annotations in a separate table with no causal foreign key.

Use indexes on epoch, incident, work IDs, lineage IDs, site, stage, and timestamp. Raw binary segments remain the source of truth.

### Gate 12 acceptance

- migration from a copy of the current performance-lab DB succeeds;
- `PRAGMA foreign_key_check` is empty;
- re-running migration is idempotent;
- normalized tables rebuild from sealed segments;
- findings cannot be updated or deleted by runtime code.

## Phase 13 — Root-classification algorithm

### Comparable healthy baseline

A degraded incident may compare only against healthy work with the same:

- diagnostic binary and manifest;
- instrumentation schema;
- runtime configuration;
- renderer path;
- cache state;
- workload class;
- exact layer generation rules.

Minimum data:

- incident: at least 30 joined lineage items;
- healthy baseline: at least 500 joined lineage items and at least five healthy minutes across two or more windows.

### First-divergence rule

Evaluate stages in pipeline order. A stage is the first supported divergence only when:

1. degraded p95 exceeds matched healthy p99;
2. median stage latency increases by at least 1 ms;
3. a bootstrap confidence interval for the degraded-minus-healthy difference excludes zero;
4. immediately preceding stage remains within its matched healthy interval;
5. the same lineage IDs carry the delay downstream;
6. all applicable producer streams seal without loss;
7. the clock transform is valid for the required precision;
8. exact surface/present identity is complete;
9. diagnostic symptom parity is already PASS;
10. observer overhead is `<= 5%`.

Use hierarchical pipeline order. Do not scan all sites and pick the most significant result.

### Site decision

- One complete valid incident: `ROOT_CANDIDATE`.
- Exact `ROOT_NAMED`:
  - same component, span, and decisive site;
  - three fresh process epochs;
  - at least two cold epochs and one warm epoch;
  - same incident signature;
  - every gate passes in every epoch.
- Owned stage but no decisive child site:
  - `UNKNOWN / BOUNDED_TO_STAGE`.
- Lateness already present at first owned hook:
  - `UNKNOWN / UNREAL_OR_PRE_ENCODER_UNKNOWN`.

### Logger acceptance is separate

The logger is accepted when identity, fault fixtures, seals, clocks, fail-closed behavior, and overhead pass. It does not need to invent a real `ROOT_NAMED` to prove that it works.

### Gate 13 acceptance

Golden synthetic datasets produce every expected outcome, including every `UNKNOWN` class.

# PART IX — VALIDATION AND DIAGNOSTIC REPRESENTATIVENESS

## Phase 14 — Controlled faults and fail-closed fixtures

Inject deterministic delays separately at:

- guest ASG wait/write;
- host receive;
- gfxstream decode;
- queue lock;
- host Vulkan submit;
- MoltenVK pipeline creation;
- Metal completion;
- QSRI/fence;
- source-frame output.

Each fixture must name the injected component and span/site.

Fail-closed fixtures:

- missing event;
- duplicate work ID;
- fan-out/fan-in error;
- generation collision;
- dropped records;
- unmatched spans;
- clock uncertainty;
- empty Perfetto category;
- manifest mismatch;
- loaded binary mismatch;
- wrong TFT layer;
- surface recreation without generation change.

### Gate 14 acceptance

All injected owned faults are localized correctly. Every invalid fixture returns the exact `UNKNOWN`/blocked result.

## Phase 15 — Observer-overhead gate

On the same diagnostic binary, compare instrumentation enabled versus disabled using randomized AB/BA order.

Measure:

- actual-present p95;
- 1% low;
- CPU;
- memory;
- stall count.

More than 5% degradation in p95 frame interval or 1% low invalidates causal conclusions. Reduce instrumentation or move work farther off-path; do not loosen the threshold.

Failure result:

```text
UNKNOWN_OBSERVER_EFFECT
```

## Phase 16 — Stock-to-diagnostic symptom parity

Before explaining stock Build 8 with diagnostic evidence, run an uninstrumented diagnostic epoch and compare the degradation phenotype, not raw performance promotion.

Required parity:

- same official TFT build/settings;
- same exact layer behavior;
- same stale-source versus slow-present class;
- same general incident signature;
- same affected pipeline generation/workload class;
- no diagnostic-only crash, queue behavior, or source-build defect that explains the incident.

Possible result:

```text
DIAGNOSTIC_REPRESENTATIVE
UNKNOWN_DIAGNOSTIC_NOT_REPRESENTATIVE
```

A failed parity gate blocks transfer of a diagnostic root to the stock symptom.

# PART X — LIVE ROOT CAMPAIGN

## Phase 17 — Three-epoch diagnostic campaign

Run automatically at fixed diagnosis settings:

```text
High
60 FPS
Performance Mode OFF
1920x1080
```

Required epochs:

1. cold epoch;
2. warm epoch;
3. second cold epoch.

Each is five to ten minutes of eligible graphics lifetime or long enough to contain the repeated incident signature.

Every epoch must:

- use a fresh process/producer generation;
- seal all streams;
- satisfy exact layer, clock, parity, and overhead gates;
- produce a deterministic finding.

### Gate 17 outcomes

- `ROOT_NAMED`: proceed to patch generation.
- `ROOT_CANDIDATE`: collect another independent matching epoch; do not patch for production.
- `UNKNOWN`: preserve the exact boundary and failed gate; do not guess.
- `UNREAL_OR_PRE_ENCODER_UNKNOWN`: no source patch is authorized inside Riot/Unreal.

# PART XI — TURN THE ROOT INTO A SETTING OR PATCH

## Phase 18 — Generate one exact patch target

From `ROOT_NAMED`, generate:

```text
ssot/PATCH_TARGET.json
```

Fields:

```text
finding_id
component
root_span_id
decisive_site_id
source_commit
source_blob_sha
allowed_files
allowed_functions
allowed_runtime_knobs
forbidden_files
hypothesis
predicted_metric_change
falsification_condition
rollback
```

### Allowed candidate classes

1. `SETTING_ONLY`
   - an existing, documented runtime knob directly controls the named bottleneck.
2. `OWNED_SOURCE_PATCH`
   - a minimal change in pinned AEMU/gfxstream/MoltenVK or TFTMAC glue.
3. `NOT_PATCHABLE`
   - root is opaque/unowned or no safe causal control exists.

### Stage-specific candidate examples

These are examples, not pre-authorization:

- ASG wait/backpressure:
  - ring/buffer sizing;
  - flush threshold;
  - bounded batching;
  - wakeup policy.
- Decoder:
  - packet batching;
  - lock duration;
  - dispatch scheduling.
- Host queue:
  - critical-section reduction;
  - queue serialization correction;
  - submit batching only when ordering remains correct.
- MoltenVK pipeline creation:
  - persistent pipeline cache;
  - validated prewarm;
  - cache-key/miss correction.
- Metal:
  - bounded command-buffer concurrency;
  - scheduling/commit policy.
- Buffer/QSRI/output:
  - fence wait correction;
  - stale-source handoff;
  - source-frame publication policy.

Do not begin with a knob sweep. The root receipt selects the one causal family.

### Gate 18 acceptance

The target is owned, narrow, reversible, and traceable to one finding.

## Phase 19 — Implement and validate the diagnostic candidate

### Implementation rules

- Modify only the files in `PATCH_TARGET.json`.
- One causal variable per candidate.
- Keep instrumentation available for root-metric confirmation.
- No dependency upgrade.
- No adjacent cleanup.
- No quality-setting change during root-metric validation.

### Root-metric confirmation

With instrumentation enabled, prove:

- named span/site p95 materially improves;
- preceding stage remains healthy;
- delay no longer propagates downstream;
- no new first divergence appears;
- fault fixtures still work.

### True performance A/B

Then build the same candidate with instrumentation disabled.

Use randomized matched AB/BA runs against the unpatched diagnostic build. Require at least three paired repetitions, including cold and warm coverage.

Reject when any is true:

- average FPS decreases by more than 1 FPS;
- p99 worsens by more than 3%;
- jank worsens by more than 0.25 percentage points;
- severe stalls increase;
- input, audio, login, package, rendering, or stability regresses.

### Gate 19 outcome

```text
PATCH_ACCEPTED_DIAGNOSTIC
PATCH_REJECTED_DIAGNOSTIC_AB
```

# PART XII — HIGHEST-QUALITY PROMOTION

## Phase 20 — Quality ladder

After the patch is locked, instrumentation disabled, and the diagnostic candidate accepted:

### Tier A — Reconfirm diagnosis baseline

```text
High / 60 / Performance OFF / 1920x1080
```

Must meet the full 600-second performance contract.

### Tier B — Target

```text
Ultra High / 60 / Performance OFF / 1920x1080
```

Procedure:

1. Enter a live rendered match.
2. Exclude first 120 seconds for warm-up.
3. Capture next 600 continuous seconds.
4. Use exact TFT actual presentation authority.
5. Preserve fixed CPU/RAM/resolution/runtime configuration.
6. Record user visual-correctness confirmation without screenshots.

Pass only if all product thresholds in section 3 pass.

Do not lower resolution, enable Performance Mode, or silently change another variable to make Ultra High pass.

### Gate 20 outcome

```text
ULTRA_HIGH_60_ACCEPTED
PATCH_ACCEPTED_ULTRA_HIGH_OPEN
```

The latter means the patch is valid but the highest-quality goal remains unresolved.

# PART XIII — STOCK-COMPATIBLE CANDIDATE AND CUTOVER

## Phase 21 — Build the production candidate mode

Translate the accepted setting or source patch into a release, instrumentation-disabled runtime.

Requirements:

- exact candidate source commits and patch SHA;
- release optimization;
- no tracing code active;
- binary manifest and symbols archived;
- official package/Play/Riot behavior unchanged;
- `candidate` mode uses an isolated validation AVD first;
- control mode remains untouched.

### Candidate-versus-control validation

The candidate must pass:

- package/signature/installer;
- Riot login and patching;
- input/audio/reconnect;
- first frame and exact layer;
- High/60 acceptance;
- Ultra High/60 acceptance;
- cold and warm launches;
- runtime restart;
- rollback.

Failure result:

```text
PATCH_REJECTED_STOCK_CANDIDATE
```

## Phase 22 — Rollback and default promotion

Create an exact rollback receipt before switching defaults:

```json
{
  "previous_default": "control",
  "candidate_manifest_sha256": "...",
  "control_manifest_sha256": "...",
  "rollback_action": "...",
  "rollback_verified": true
}
```

Default promotion is authorized only when:

- candidate source delivered and validated;
- Ultra High/60 accepted;
- rollback verified;
- control still starts successfully;
- no open blocker affects the candidate.

After cutover, preserve `control` as emergency rollback until a later explicit retirement plan.

# PART XIV — USER-FACING OUTPUT AND DOCUMENTATION

## Phase 23 — Overlay and reports

Display only:

- exact TFT actual-present FPS;
- 1% low;
- source-frame freshness;
- provisional first-divergent stage;
- trace completeness;
- confidence/state;
- active runtime mode;
- current graphics tier.

Do not display the native Mac presenter as a root candidate.

The live overlay must label any stage as provisional. Final status comes only from post-seal analysis.

After TFT exits:

1. stop producers;
2. seal raw evidence;
3. normalize;
4. derive immutable finding;
5. generate an AI-readable explanation.

The explanation includes:

- outcome;
- component/stage/span/site;
- source anchor;
- first late lineage items;
- evidence hashes;
- rejected downstream candidates;
- unknowns;
- patchable state;
- accepted/rejected patch;
- highest accepted quality tier.

## Phase 24 — Final project records

Update:

- canonical facts authority;
- benchmark methodology and receipts;
- development/patch workflow;
- performance lab schema;
- engineering map;
- build instructions;
- runtime mode documentation;
- rollback instructions;
- known limitations.

Remove no historical evidence merely because a candidate failed.

# PART XV — COMMIT WAVES AND CODEX STOP POINTS

Use separate reviewable commits or managed changes:

1. **Wave A — Authority and local reconciliation**
2. **Wave B — Runtime modes and diagnostic build identity**
3. **Wave C — Event ABI, site manifest, and work/present lineage**
4. **Wave D — Source hooks, rings, clocks, and seals**
5. **Wave E — Presentation endpoint, incident detector, SQL, analyzer**
6. **Wave F — Fault fixtures, overhead, parity, and logger acceptance**
7. **Wave G — Live root evidence**
8. **Wave H — Exact settings/patch candidate**
9. **Wave I — Quality ladder**
10. **Wave J — Stock candidate, rollback, and final delivery**

At each wave:

- run only the nearest decisive validation;
- checkpoint the exact head and evidence;
- do not start the next wave if the gate is blocked;
- do not treat a workaround as completion;
- record unrelated discoveries as deferred defects.

# PART XVI — REQUIRED TEST MATRIX

| Test | Required result |
|---|---|
| Dirty local checkout | preserved; no destructive reset |
| Manifest or loaded-binary mismatch | blocked before game launch |
| ANGLE contributes to TFT surface | ANGLE branch instrumented |
| Diagnostic symptom differs from control | `UNKNOWN_DIAGNOSTIC_NOT_REPRESENTATIVE` |
| Work lineage missing | `UNKNOWN_PRESENT_LINEAGE_GAP` |
| Ring overflow | `UNKNOWN_STREAM_LOSS` |
| Clock uncertainty >10 ms | `UNKNOWN_CLOCK_UNCERTAINTY` |
| SurfaceView absent from FrameTimeline | fallback presentation authority used |
| Empty custom Perfetto trace | `TRACE_INSTRUMENTATION_UNAVAILABLE`; fixed-ring evidence retained |
| Controlled delay at every owned stage | exact injected stage/site named |
| Missing/duplicate/fan-in fault | `UNKNOWN`; never `ROOT_NAMED` |
| One valid incident | `ROOT_CANDIDATE` |
| Three matching epochs, two cold | `ROOT_NAMED` |
| Lateness exists before first owned hook | `UNREAL_OR_PRE_ENCODER_UNKNOWN` |
| Owned stage, no decisive child | `UNKNOWN / BOUNDED_TO_STAGE` |
| Instrumentation overhead >5% | causal result invalid |
| Diagnostic A/B regression | patch rejected |
| Stock candidate regression | patch rejected; control retained |
| Ultra High misses contract | patch may remain accepted; quality goal remains open |
| Rollback not verified | default cutover blocked |
| Ultra High and all gates pass | `ULTRA_HIGH_60_ACCEPTED` |

# PART XVII — ZENMC ADVERSARIAL GATE

## Model

The plan was evaluated as a state machine with:

- 10,000 randomized adversarial trajectories;
- 24 targeted single-gate fault mutations;
- one complete success trajectory;
- explicit invariants at root naming, patch admission, candidate promotion, control mutation, and rollback.

The randomized weights were selected for branch coverage and are **not empirical probabilities**.

## Result

```text
ZENMC: PASS
model_sha256: 561820eb6d896728962bae35adef19e7bfc7170e77d9d1c7270ff67b9d2cff6d
unsafe production promotions: 0
false ROOT_NAMED outcomes: 0
patch attempts without owned ROOT_NAMED: 0
early control-runtime mutations: 0
targeted fail-closed cases with expected result: 24 / 24
targeted success cases: 1 / 1
```

Most frequently exercised fail-closed paths included diagnostic non-representativeness, observer effect, missing renderer receipt, insufficient healthy baseline, unpreserved local work, presentation-lineage gaps, and clock uncertainty.

## ZenMC-required remediations now embedded

- local-work preservation gate;
- formal authority amendment;
- conditional ANGLE path;
- stock-to-diagnostic symptom parity;
- presentation lineage separate from transport identity;
- robust healthy sample floor;
- logger acceptance independent of real root discovery;
- exact unknown taxonomy;
- patch ownership gate;
- Ultra High acceptance separated from patch acceptance;
- rollback required before default mutation.

# PART XVIII — EXECUTION-SCOPE LOCK

```text
EXECUTION-SCOPE LOCK — TFTMAC CAUSAL GRAPHICS OPTIMIZATION V1

Implement only:
1. Safe reconciliation and preservation of the current local TFTMAC checkout/worktrees.
2. Formal project-authority amendments needed to authorize an isolated diagnostic graphics runtime.
3. A protected control runtime, an isolated advanced_diagnostics runtime, and later a separately gated candidate runtime.
4. Deterministic renderer-path, exact-layer, build-identity, symptom-parity, work-lineage, clock, stream-integrity, and observer-overhead gates.
5. Source instrumentation in only the pinned AEMU/gfxstream/MoltenVK/Metal-facing open-source code needed to localize the first owned graphics divergence.
6. Raw-first fixed-record collection, sealed evidence, deterministic normalization, causal classification, controlled fault fixtures, and append-only SQL evidence.
7. A narrowly targeted settings adjustment or owned-source patch derived from a valid ROOT_NAMED receipt.
8. Controlled A/B validation and the quality-promotion ladder ending at Ultra High / 60 FPS / Performance Mode OFF / 1920x1080 when all acceptance gates pass.
9. A stock-compatible candidate runtime with one-action rollback, only after diagnostic and production-layer acceptance.

Do not implement:
- Riot APK modification, repacking, re-signing, binary patching, process injection, credential capture, screenshot capture, shader extraction, or fabricated Riot/Unreal source attribution.
- Unrelated refactors, cleanup, renames, reformatting, dependency upgrades, broad architecture replacement, or speculative optimization.
- Any source-built runtime as a hidden replacement for the proven control runtime.
- Any optimization selected only from timestamps, queue handles, aggregate counters, subjective feel, or a single diagnostic epoch.
- Any default-runtime cutover without an exact accepted candidate SHA, a rollback receipt, and Ultra High live acceptance.

A material diff is permitted only when it traces to this lock, a listed phase deliverable, or a proven blocking dependency added through an append-only amendment and a targeted ZenMC/ZenGate rerun.
```

Scope lock SHA-256:

```text
dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e
```

# PART XIX — START HERE FOR LOCAL CODEX

Execute only this sequence now:

1. Run Phase 0 and write the local authority receipt.
2. Preserve/checkpoint every current local change.
3. Copy this plan to:
   ```text
   .clara/plans/tftmac-causal-graphics-v1/IMPLEMENTATION_PLAN.md
   ```
4. Write the scope lock exactly and verify SHA-256 `dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e`.
5. Complete Phase 1 authority amendment.
6. Stop before source instrumentation until the renderer-path receipt, protected control receipt, and diagnostic-only authority all pass.
7. Continue wave-by-wave without expanding scope.

The first product edit is **not** a speculative graphics tweak. It is the runtime-mode/authority foundation that makes later causal evidence and a safe production patch possible.

# Primary technical references

- gfxstream architecture and tracing:
  `https://android.googlesource.com/platform/hardware/google/gfxstream/`
- Perfetto TrackEvent flows and custom clocks:
  `https://perfetto.dev/docs/instrumentation/track-events`
- Perfetto FrameTimeline and SurfaceView limitation:
  `https://perfetto.dev/docs/data-sources/frametimeline`
- Android SurfaceFlinger/BufferQueue:
  `https://source.android.com/docs/core/graphics/surfaceflinger-windowmanager`
- Android synchronization fences:
  `https://source.android.com/docs/core/graphics/sync`
- Vulkan calibrated timestamps:
  `https://registry.khronos.org/vulkan/specs/latest/man/html/VK_KHR_calibrated_timestamps.html`
- Vulkan pipeline cache:
  `https://registry.khronos.org/vulkan/specs/latest/man/html/VkPipelineCache.html`
- MoltenVK runtime/performance guidance:
  `https://github.com/KhronosGroup/MoltenVK/blob/main/Docs/MoltenVK_Runtime_UserGuide.md`
- Metal command-buffer GPU timing:
  `https://developer.apple.com/documentation/metal/mtlcommandbuffer/gpuendtime`

# PART XX — APPEND-ONLY CANONICAL REPOSITORY AMENDMENT V1.1

**Amendment ID:** `TFTMAC_CAUSAL_GRAPHICS_CLEAN_REPOSITORY_V1_1`  
**Effective observation:** 2026-08-31 19:55 America/Chicago (`2026-09-01T00:55:04.583Z`)  
**Canonical repository:** `flashls1/TFTMAC`  
**Canonical branch:** `master`  
**Canonical HEAD at amendment:** `c8b79ea009197c25bc7e64bebd5e8948eea918b1`  
**Authority-input manifest SHA-256:** `1d85f4f2f64f3b6089c79385b329dfe42bb479b8c65877c39bf01bdef13703ac`  
**ZenMC delta model SHA-256:** `e67e5473b309a210816b87dc55c0765567e4d996b48c9ca982eeb66863d7ad85`

## 25. Amendment precedence

This section is append-only and has the highest precedence inside this plan for **repository state, current authority files, implementation base, diagnostic-source baseline, and immediate start sequence**. It supersedes only stale start-state assumptions.

It does **not** weaken or supersede:

- the original execution-scope lock;
- the protected stock `control` runtime;
- renderer-path, lineage, clock, stream-loss, parity, observer-overhead, root-naming, patch-admission, Ultra High, rollback, privacy, or Riot-package boundaries;
- the rule that only an owned, replicated `ROOT_NAMED` may authorize an optimization patch.

The attached source design still governs the core objective: replace symptom-only logging with an automatic source-instrumented causal logger that returns an honest `ROOT_CANDIDATE`, `ROOT_NAMED`, or `UNKNOWN`, while leaving the proven playable runtime untouched.

## 26. Verified clean canonical authority

Clara's current local/GitHub reconciliation now proves:

```text
repository: flashls1/TFTMAC
branch: master
local HEAD: c8b79ea009197c25bc7e64bebd5e8948eea918b1
origin/master: c8b79ea009197c25bc7e64bebd5e8948eea918b1
working tree: clean
ahead: 0
behind: 0
open GitHub pull requests: 0
```

The canonical repository is therefore the implementation authority. The earlier observation at `365e891...` and the assumption that current native-controller work existed only in a dirty managed worktree are superseded. Current `master` already contains the native probe/controller consolidation, including:

- `Probes/EmbeddedControlProbe/EmbeddedControlProbe.swift`;
- the `EmbeddedControlProbe` Xcode target and generated gRPC/protobuf sources;
- `start-native-controller-probe`;
- hidden Qt launch with `-qt-hide-window`;
- authenticated `-grpc-use-token` controller behavior;
- the native runtime, automatic Build 8 logger, graphics stack receipts, and current authority documentation.

Old Clara worktrees and their historical branches remain preserved forensic state. **Do not merge, cherry-pick, rebase, or copy from them merely because Clara still lists them.** They may be consulted only if current canonical `master` demonstrably lacks a required artifact and a targeted append-only plan amendment authorizes recovery.

## 27. Current documentation and machine-readable authority

The root authority files now exist and are current. Do not create alternate copies or substitute new authority locations. Use and minimally amend:

| Authority | Current SHA-256 | Role |
|---|---|---|
| `facts.md` | `78016e5e3c7c08e263e2d8aba435f8519ae199cadc18ea74d6c39634cd0fff18` | locked facts, verified current observations, explicit unknowns |
| `project.md` | `273307f655f0749a12a0a3e48f421f5e61bc6bd40f00b1afb7040c0b2fd15adb` | project history and continuity |
| `dev.md` | `a40e186e4d37a4e7d6024bd069a69509729eb9e6efda36a0fab12162ecf60f7e` | code ownership, active experiments, next engineering gates |
| `benchmark.md` | `15a33754add669bdfea2001053cbfb47df1120658be7f10022a50656fb4069c6` | formulas, validity, SQL, analysis and promotion contract |
| `TFTMAC_GPU_RUNTIME_SSOT.md` | `bad70917a4e3230646748c33a171aeba0f0b1f4ff9b93fdfaa7b04788b84c532` | current stock-runtime and diagnostic-runtime boundary |
| `ssot/STACK.lock.yaml` | `e2b6fca2e3d310f97ca833b0fccd0f5202f766b6f72aeeb795f061a8c1baf096` | machine-readable Build 8 and diagnostic eligibility lock |
| `ssot/AUTHORITY_INPUTS.sha256` | `1d85f4f2f64f3b6089c79385b329dfe42bb479b8c65877c39bf01bdef13703ac` | complete authority-input hash manifest |

Phase 1 is therefore changed from “discover or create authority files” to **append the causal-logger contract to the existing authority set, update relational/machine-readable receipts, regenerate `ssot/AUTHORITY_INPUTS.sha256`, and prove all hashes and cross-references remain consistent**.

Do not overwrite the current short `TFTMAC_FULL_IMPLEMENTATION_PLAN.md`; it is intentionally a historical-plan pointer. Store this implementation authority under `.clara/plans/tftmac-causal-graphics-v1/` and add only a concise current-authority reference from existing project documentation when appropriate.

## 28. The Build 8 degradation capture is now receipted

The original plan's “claimed prior observation not yet receipted” branch is superseded. Current machine-readable authority records:

```text
capture ID: 2026-08-31T22-30-26.086Z-8df607d7-a34a-4e2a-b00d-739aa3143200
private SQLite bytes: 63,897,600
database SHA-256: c1ef9c9ffe591a297cb86660e3ccfea7e9aeb593f22100e4e732b2fc77d4ee77
graphics-run duration: 42m27s
exact-layer coverage: 99.629%
frame intervals: 144,364
weighted FPS: 56.98
1% low: 21.49 FPS
p95: 21.51 ms
p99: 33.434 ms
maximum interval: 2,233.611 ms
jank: 6,544 / 4.53%
severe stalls: 144
missed-vsync equivalents: 7,644
degradation incidents: 189
root attribution: UNKNOWN_UPSTREAM_OF_OR_AT_GUEST_SURFACE
```

This capture is valid as:

- proof that automatic PID/layer-lifetime logging works;
- proof that current High/60/OFF does not hold the target continuously;
- the initial symptom signature and incident corpus for diagnostic parity.

It is **not** an internal root receipt and cannot authorize a patch by itself. The source-instrumented diagnostic program remains necessary.

## 29. Current renderer and control facts

The current stack receipt identifies:

```text
UNREAL_DIRECT_VULKAN
  -> GFXSTREAM_ASG
  -> HOST_VULKAN
  -> MOLTENVK
  -> METAL
```

ANGLE is conditional and is not assumed to render TFT's main surface. Phase 3 is therefore no longer broad renderer rediscovery. It is a **per-build and per-diagnostic-epoch receipt refresh** that must confirm the exact TFT PID, SurfaceView generation, loaded libraries, queue/device identity, and effective route. If that refresh contradicts `UNREAL_DIRECT_VULKAN`, the conditional ANGLE branch activates exactly as specified earlier.

The current protected Control remains:

```text
TFTMAC 2.3.0 build 8
profile base: tftmac_5gb_native_v1
6 vCPU / 5120 MiB
1920x1080 / 60 Hz
TFT High / 60 FPS / Performance Mode OFF
stock Android Emulator 37.1.11
ADB 5038 / console 5582 / emulator-5582
packaged logged-in-session Emulator Host launch
```

Ultra High remains a rejected current setting and the target this plan is intended to make safely promotable; it is not a starting baseline.

## 30. Revised diagnostic source authority

The isolated diagnostic source baseline is now explicitly recorded by current TFTMAC authority:

```text
repository: flashls1/tftmac-runtime
commit: c8aa26ebaa5b977965eb165ad8aac5c98408469f
classification: isolated_non_comparable_diagnostic_eligibility_only
normal-play authority: stock Build 8
```

Phase 4 is amended as follows:

1. Begin from the exact `flashls1/tftmac-runtime@c8aa26e...` tree.
2. Verify its remote, full commit, clean state, source lock, and relationship to the AEMU/gfxstream/MoltenVK commits before editing.
3. Create an instrumentation branch/worktree in the diagnostic repository; do not import a historical Clara worktree into current TFTMAC `master`.
4. Place source-level guest/host graphics hooks in the diagnostic repository.
5. Place TFTMAC mode orchestration, schema readers, normalizers, deterministic analyzer, UI/reporting, and project documentation in `flashls1/TFTMAC`.
6. Install all diagnostic output under the new isolated diagnostics root; do not recreate the retired normal-play Build tree.
7. Preserve `non_comparable_to_stock=true` until the separate representativeness, instrumentation-disabled A/B, and candidate gates pass.

If the diagnostic repository has advanced beyond `c8aa26e...`, Codex may use the newer commit only when it is clean, published, contains the same current diagnostic eligibility contract, and records a superseding source lock. Record the selected exact SHA; never silently follow a moving branch.

## 31. Revised Gate 0A — clean canonical fast path

The original broad Phase 0 preservation procedure is now conditional rather than mandatory. From the canonical TFTMAC checkout, run:

```bash
git fetch origin --prune
git switch master
git status --porcelain=v2 -b
git rev-parse HEAD
git rev-parse origin/master
git remote get-url origin
git worktree list --porcelain
shasum -a 256 -c ssot/AUTHORITY_INPUTS.sha256
/bin/zsh scripts/verify-tftmac.command
```

Write `.clara/plans/tftmac-causal-graphics-v1/BASELINE_AUTHORITY.json` containing:

```json
{
  "repository": "flashls1/TFTMAC",
  "branch": "master",
  "head_sha": "<observed clean aligned SHA>",
  "origin_master_sha": "<same SHA>",
  "expected_sha_at_amendment": "c8b79ea009197c25bc7e64bebd5e8948eea918b1",
  "working_tree_clean": true,
  "authority_inputs_sha256": "1d85f4f2f64f3b6089c79385b329dfe42bb479b8c65877c39bf01bdef13703ac",
  "source_verifier": "PASS",
  "old_managed_worktrees_imported": false,
  "observed_at": "<UTC>"
}
```

### Gate 0A rules

- If `HEAD == origin/master`, the tree is clean, the authority-input check passes, and `scripts/verify-tftmac.command` passes, create `codex/tftmac-causal-graphics-v1` from that exact HEAD and continue.
- `c8b79ea009197c25bc7e64bebd5e8948eea918b1` is the observed authority at amendment creation, not a command to reset a later clean aligned master backward. If master legitimately advances, record the newer SHA and continue only after the same hash and verifier gates pass.
- If the tree is dirty, stop the fast path and execute the original Phase 0 preservation workflow. Never clean or reset it.
- If local and remote diverge, stop with `BLOCKED_CANONICAL_REPO_DRIFT`. Do not pull/rebase/force automatically.
- If an authority hash fails, stop with `BLOCKED_AUTHORITY_HASH_DRIFT`.
- If the source verifier fails, repair only that exact baseline failure before creating implementation changes.
- Do not copy from the old Clara worktrees to “help” the clean canonical tree. Such an attempt is `BLOCKED_NONCANONICAL_WORKTREE_IMPORT`.

### Gate 0A acceptance

```text
CANONICAL_REPOSITORY_CLEAN_ALIGNED
AUTHORITY_INPUTS_PASS
SOURCE_VERIFIER_PASS
IMPLEMENTATION_BRANCH_FROM_CANONICAL_HEAD
NONCANONICAL_WORKTREE_IMPORTS = 0
```

## 32. Current signing-trust issue is separately scoped

Current authority records that Build 8's historical release hashes match, while the current login keychain exposes no valid `TFTMAC Local Code Signing` identity and deep/strict verification reports `CSSMERR_TP_NOT_TRUSTED`.

This means:

- repository changes, source tests, unsigned Release builds, diagnostic-runtime construction, causal logging, root discovery, and instrumentation-disabled diagnostic A/B may proceed;
- do not rebuild or re-sign the protected playable Build 8 merely to clear this operational issue;
- final installed `candidate` validation, signed app replacement, and default cutover remain blocked until the separate signing-identity repair passes `scripts/verify-installed-runtime.command`;
- no code workaround may downgrade or bypass the signing gate.

This is a delivery-layer blocker only when the plan reaches installed candidate promotion. It is not a reason to stop the causal-logger implementation.

## 33. Revised immediate implementation sequence

The original Part XIX start sequence is superseded by this sequence:

1. Run Gate 0A against current canonical `master`.
2. Create `codex/tftmac-causal-graphics-v1` from the verified clean aligned HEAD.
3. Copy this complete v1.1 plan and the v2 ZenMC receipt into `.clara/plans/tftmac-causal-graphics-v1/`.
4. Preserve the existing execution-scope lock exactly; verify SHA-256 `dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e`.
5. Amend the existing `facts.md`, `project.md`, `dev.md`, `benchmark.md`, current SSOT, engineering map, and performance-lab authority only where the causal contract requires it; do not rewrite unrelated Build 8 history.
6. Add the causal authority/schema/design files named in Phase 1 and regenerate the authority-input manifest.
7. Implement the three-mode registry without changing the default `control`.
8. Create/freeze the diagnostic worktree from `flashls1/tftmac-runtime@c8aa26e...`.
9. Refresh the exact renderer/surface receipt, then prove diagnostic symptom parity before source attribution.
10. Continue with the original event ABI, rings, clocks, work/present lineage, hooks, SQL, analyzer, fault fixtures, root replication, narrow patch, A/B, Ultra High ladder, candidate, rollback, and delivery gates.

No broad repository cleanup, old-worktree convergence, native-app reconstruction, or logger rediscovery is part of this start sequence. That work is already present in canonical `master`.

## 34. ZenMC v1.1 delta gate

A targeted state-machine rerun evaluated the change from “unknown/possibly dirty local authority” to “clean canonical GitHub-aligned authority with conditional fallback.”

```text
ZENMC DELTA: PASS
randomized adversarial trajectories: 10,000
model SHA-256: e67e5473b309a210816b87dc55c0765567e4d996b48c9ca982eeb66863d7ad85
implementation from dirty/diverged repository: 0
implementation with authority-hash failure: 0
noncanonical worktree imports admitted: 0
candidate cutovers without signing validation: 0
targeted fail-closed cases: 6 / 6
targeted success cases: 1 / 1
```

Randomized outcome counts:

```text
READY_FOR_IMPLEMENTATION                              5,129
LEGACY_PHASE0_PRESERVATION_REQUIRED                   1,395
READY_FOR_IMPLEMENTATION_AND_LATER_CUTOVER_GATES        729
BLOCKED_BASELINE_SOURCE_VALIDATION                       656
BLOCKED_NONCANONICAL_WORKTREE_IMPORT                     621
SOURCE_WORK_READY_CUTOVER_BLOCKED_SIGNING_IDENTITY       601
BLOCKED_CANONICAL_REPO_DRIFT                             516
BLOCKED_AUTHORITY_HASH_DRIFT                             353
```

These weights are adversarial branch-coverage weights, not forecasts. The amendment changes only how implementation safely starts; it does not lower any causal or production acceptance threshold.

## 35. Effective status after this amendment

```text
PLAN VERSION: 1.1
REPOSITORY BASE: CLEAN CANONICAL MASTER
IMPLEMENTATION STATUS: READY AFTER GATE 0A SOURCE/HASH VERIFICATION
CONTROL STATUS: PROTECTED BUILD 8
CURRENT INTERNAL ROOT: UNKNOWN
DIAGNOSTIC SOURCE ELIGIBILITY: flashls1/tftmac-runtime@c8aa26e...
ULTRA HIGH STATUS: TARGET, NOT CURRENTLY ACCEPTED
FINAL CUTOVER SIGNING STATUS: BLOCKED UNTIL SEPARATE IDENTITY REPAIR
EXECUTION-SCOPE LOCK: UNCHANGED
```

