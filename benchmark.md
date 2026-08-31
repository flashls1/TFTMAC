# TFTMAC Benchmark and Analysis Contract

**Authority date:** 2026-08-30 America/Chicago
**Formula version:** `tftmac-benchmark-v1`
**Current runtime:** TFTMAC 2.2.0 build 7 on the M4 Mac mini
**Purpose:** give a developer or AI agent one exact, reproducible process for turning TFTMAC session data into findings, comparisons, decisions, and explicit unknowns.

This file is the current benchmark-analysis authority. `docs/benchmarks.md` is
the historical M1 Max/userdebug experiment ledger; it must not be mistaken for
current M4 native-runtime evidence. Machine/runtime facts live in `facts.md`,
project history in `project.md`, and active engineering hypotheses in `dev.md`.

## 1. Answer and operating decision

Before this file, the analysis process existed but was split across source,
`facts.md`, `project.md`, `dev.md`, telemetry documentation, SQL tables, and the
historical campaign record. An agent could find the pieces, but it did not have
one complete input/formula/output contract. This file closes that documentation
gap.

TFTMAC recognizes four evidence modes:

| Mode | Meaning | Authority |
| --- | --- | --- |
| `FULL_MATCH` | A user-marked match from `MATCH_ENTRY` through `MATCH_END` | Preferred evidence for real playability, repeated battles, late-game degradation, memory/thermal drift, and promotion to normal play |
| `COMBAT_AB` | A 300–480 second representative-combat window under one named preset | Fast controlled screening of one candidate against a compatible Control |
| `DIAGNOSTIC_ONLY` | Launch, login, lobby, unmarked gameplay, partial capture, or isolated incident | Useful for diagnosis; cannot prove match performance or promote a candidate |
| `INVALID` | Missing/corrupt boundaries, inadequate coverage, changed identity, correctness failure, or other declared invalidator | Retain as negative/operational evidence; do not use for a positive performance claim |

Full matches are preferred because one run contains multiple battles, planning
periods, early/late stages, transitions, and sustained resource pressure. Short
combat A/B runs remain useful because they produce a faster controlled answer.
A short winner is not promoted for normal play until it also survives a full
marked match. A full match can immediately veto a candidate for correctness or
player experience.

A lobby, a reported `SRC 60`, an `OUT 60`, a successful launch, or an emulator
process is never a gameplay benchmark.

## 2. Evidence and claim discipline

Every finding must contain these fields:

```text
claim       narrow statement supported by the evidence
evidence    session/benchmark IDs, tables, time range, and calculated values
confidence  DIRECT | CORRELATED | INFERRED | USER | UNKNOWN
unknowns    unmeasured or invalid boundaries
decision    KEEP | REJECT | PROMISING | INCONCLUSIVE | NO_DECISION
```

The labels mean:

- `DIRECT`: the claimed value exists in current raw/normalized evidence or is a
  deterministic calculation from it.
- `CORRELATED`: two signals are time-aligned closely enough to establish
  ordering or co-occurrence, but not sole cause.
- `INFERRED`: the evidence supports a hypothesis but does not observe the
  claimed internal boundary directly.
- `USER`: the player directly reported experience or correctness. This is
  decisive for playability and not sufficient for internal root cause.
- `UNKNOWN`: the current capture cannot support the claim.

Mandatory rules:

1. Exact SurfaceFlinger actual-present intervals for the semantic TFT Unreal
   `SurfaceView` are guest gameplay-cadence authority.
2. `SRC` is distinct completed controller images. `OUT` is TFTMAC's final Metal
   presentation cadence. Neither is Unreal FPS.
3. A fast final presenter can repeatedly present an old source frame; 60 OUT
   therefore does not contradict 30–50 useful game FPS.
4. Requested configuration, effective receipt, and observed outcome are three
   separate facts.
5. A guest-frame stall does not identify Unreal, ANGLE, ASG/gfxstream,
   MoltenVK, Metal, or TFTMAC as its cause.
6. Cross-host ordering requires valid clock evidence. A trace does not repair a
   bad clock relationship.
7. Never use an average to erase 1% low, p95/p99, severe stalls, worst battle,
   or direct player rejection.
8. Never inspect or report credentials, typed text, tokens, cookies, PINs,
   CAPTCHA/MFA values, login screenshots, or raw frame payloads.

## 3. Canonical inputs and read order for an AI agent

An agent analyzing a TFTMAC run reads, in order:

1. `facts.md` for the immutable/current machine, product, security, and runtime
   boundaries.
2. This `benchmark.md` for evidence modes, formulas, validity, SQL, and output
   shape.
3. `dev.md` for the active Control, candidate, negative-result ledger, and
   hypotheses.
4. The selected session's `TFTMAC_NATIVE_RUNTIME.sqlite` as raw session
   authority.
5. `TFTMAC_LAB.sqlite` only for durable benchmark/comparison history.
6. Raw sidecars or traces only when the requested causal question requires them
   and their hash/processor/privacy receipts are valid.

Per-session authority:

```text
~/Library/Application Support/TFTMAC/Captures/<session-id>/
  TFTMAC_NATIVE_RUNTIME.sqlite
```

Persistent comparison authority:

```text
~/Library/Application Support/TFTMAC/TFTMAC_LAB.sqlite
```

Before calculation, create an analysis manifest:

```json
{
  "analysis_schema": "tftmac.benchmark-report.v1",
  "formula_version": "tftmac-benchmark-v1",
  "evidence_mode": "FULL_MATCH|COMBAT_AB|DIAGNOSTIC_ONLY|INVALID",
  "session_id": "<session UUID>",
  "session_database": "<absolute local path>",
  "profile_id": "<effective profile>",
  "configuration_sha256": "<effective configuration hash or UNKNOWN>",
  "comparison_identity_sha256": "<comparison hash or NOT_APPLICABLE>",
  "tft_package_version": "<observed version>",
  "source_commit": "<Git commit used to interpret formulas>",
  "start_event_id": 0,
  "end_event_id": 0,
  "start_monotonic_ns": 0,
  "end_monotonic_ns": 0,
  "analysis_created_utc": "<UTC>"
}
```

If any field is unavailable, write `UNKNOWN` or `null`; do not guess it from a
different session.

## 4. SQL data dictionary

| Table | Meaning | Analysis use |
| --- | --- | --- |
| `sessions` | app-run identity, profile, lifecycle | top-level session authority |
| `runtime_receipts` | requested/effective runtime facts | configuration and version proof |
| `events` | explicit lifecycle/user/app boundaries | full-match, benchmark, stutter, process, and failure segmentation |
| `game_frame_intervals` | exact TFT actual-present deltas | authoritative FPS/tail calculations |
| `game_frame_windows` | one-second gameplay summaries and availability | incident/worst-window discovery and coverage |
| `stream_freshness_windows` | received, changed, identical, and lost controller frames | distinguish upstream freshness from final output |
| `host_presentation_windows` | Metal submit/complete/reuse/error/latency/GPU time | test whether TFTMAC's final presenter is the late boundary |
| `presentation_samples` | cumulative/instant SRC and OUT behavior | source/presenter cadence trend |
| `resource_samples` | QEMU CPU/RSS, TFT PID, foreground activity | host-emulator load and process continuity |
| `guest_memory_samples` | guest available memory and swap | Android pressure trajectory |
| `host_resource_samples` | host memory/compression/swap/pageouts/thermal/power | Mac pressure and comparability |
| `clock_sync_samples` | host midpoint, guest uptime, RTT, offset | cross-boundary eligibility |
| `surfaceflinger_samples` | render rate and cumulative miss counters | deltas between valid explicit boundaries only |
| `audio_samples` | backend, active output, rate, stereo, tracks, underruns | audio correctness evidence |
| `logcat_aggregates` | bounded sanitized ANR/fatal/LMK/renderer/audio counts | failure-class evidence, not sole cause |
| `pipeline_log_aggregates` | gfxstream/ASG/Vulkan/MoltenVK/shader/fence signals | named warning/failure evidence, not proof of absence |
| `graphics_pipeline_snapshots` | effective layer/API/renderer state | comparable-path gate |
| `diagnostic_artifacts` | trace path/hash/processor/normalization | bounded causal evidence |
| `combat_benchmarks` | finalized short-benchmark identity/validity/metrics | controlled `COMBAT_AB` result |
| `combat_incidents` | bad-window trigger, trace, boundary/unknowns | incident analysis |
| `combat_comparisons` | Control/candidate deltas and code decision | controlled A/B output |
| `game_process_sessions` | TFT PID lifetime | restart and process-stability evidence |

## 5. Time domains and legal joins

TFTMAC data contains different clocks. They must not be joined as though they
were the same number.

### Host monotonic clock

`events.monotonic_ns`, `game_frame_windows.started_monotonic_ns`, resource
samples, stream/presenter windows, and most SQL sampling boundaries use the host
monotonic clock. Use this clock for marked full-match boundaries and ordinary
same-host overlap joins.

### Guest SurfaceFlinger clock

`game_frame_intervals.actual_present_ns` is the guest SurfaceFlinger actual-
present timestamp. Subtract adjacent values only inside the same stable layer
epoch. Do not compare it directly to a host marker.

`game_frame_intervals.observed_monotonic_ns` is the host time at which TFTMAC
observed the interval. It is the legal field for assigning intervals to a
host-marked match, with up to approximately one polling window of boundary
uncertainty. Precise event-to-frame attribution requires valid clock mapping or
a common frame ID.

### UTC

UTC strings are for human display and cross-file orientation. Never calculate
frame intervals from UTC wall time.

### Clock quality

- p95 RTT at or below 2 ms: precise cross-boundary attribution permitted.
- above 2 ms through 10 ms: coarse ordering only.
- above 10 ms, missing bracket, or outside the bracket: cross-host cause is
  `UNKNOWN`.

## 6. Exact frame formulas

The formulas below mirror `GameFrameTelemetry.swift`,
`CombatBenchmarkStore.swift`, and `CombatBenchmarkAnalysis.swift`.

For consecutive actual-present timestamps and a SurfaceFlinger refresh period:

```text
interval_ns[i] = actual_present_ns[i] - actual_present_ns[i-1]
interval_ms[i] = interval_ns[i] / 1,000,000

vsyncs[i] = max(1, round(interval_ns[i] / refresh_period_ns))
missed_vsync_equivalents[i] = max(0, vsyncs[i] - 1)

janky[i]  = interval_ns[i] >  1.5 * refresh_period_ns
severe[i] = interval_ns[i] >= 3.0 * refresh_period_ns
```

At the current 60 Hz target, these boundaries are approximately:

```text
janky  > 25.000 ms
severe >= 50.000 ms
```

For an ordered interval population `I` of size `n`:

```text
weighted_fps = n / (sum(I_ms) / 1000)

nearest_rank_percentile(I, q) =
  sort(I)[min(n - 1, max(0, ceil(n * q) - 1))]

slow_count = max(1, ceil(n * 0.01))
one_percent_low_fps = 1000 / mean(slowest slow_count intervals)

jank_rate = count(janky) / max(1, n)
severe_rate = count(severe) / max(1, n)
missed_vsync_rate = sum(missed_vsync_equivalents) / max(1, n)
```

The one-second window metric is deliberately different:

```text
effective_fps = interval_count * 1,000,000,000 /
                max(1, window_end_ns - window_start_ns)
```

Always name which FPS formula is being reported. Do not average per-window FPS
to create a whole-match FPS when raw intervals are available.

### Availability and clock formulas

For an analysis range `[start,end]`:

```text
overlap(window, range) =
  max(0, min(window_end, end) - max(window_start, start))

surface_coverage =
  sum(overlap for AVAILABLE exact-layer windows) /
  sum(overlap for all measured windows)

clock_coverage =
  max(0, min(end, latest_clock_midpoint) -
         max(start, earliest_clock_midpoint)) /
  (end - start)
```

The code's short-benchmark surface availability denominator is measured-window
time, not marker duration. Reports should also state unmeasured boundary time so
an apparently perfect measured-window ratio is not misleading.

### Candidate deltas

For FPS and interval metrics:

```text
delta_percent = ((candidate - control) / control) * 100
```

Positive FPS/1%-low delta is better. Positive p95/p99 interval delta is worse.
Jank, severe, and missed-vsync deltas stored by the current code are fraction
differences (percentage-point changes when multiplied by 100), not relative
percent reductions.

For a relative rate reduction used by the Home Run rule:

```text
relative_reduction = (control_rate - candidate_rate) / control_rate
```

## 7. Full-match collection and analysis

### Collection

1. Launch one clean named profile and let startup logging begin before the
   emulator/TFT path.
2. Do not change a restart-bound setting during the match.
3. Select `Mark Match Entry` when the actual match/game board begins.
4. Play normally. A full run is preferred; it supplies several battles and
   exposes sustained/late-game behavior.
5. Use `Visible Stutter` whenever practical. Absence of a marker never means
   absence of stutter.
6. Select `Mark Match End` at the result/end boundary.
7. Analyze the marked range immediately; seal the complete session after normal
   app shutdown and AVD rollback.

The current native menu writes `MATCH_ENTRY` and `MATCH_END`. It does not yet
write semantic `COMBAT_START`/`COMBAT_END`, round/stage, placement, or battle
identity. Do not pretend those fields exist.

### Full-match validity

A marked full match is valid product evidence when:

- one ordered `MATCH_ENTRY`/`MATCH_END` pair exists in the same session;
- end is later than start;
- the expected TFT Unreal `SurfaceView` is stable and unambiguous;
- exact-layer measured coverage is at least 95%;
- no SurfaceFlinger history truncation affects the range;
- the effective package/profile/configuration are identified;
- no render/input/audio/login/crash correctness failure invalidates play.

Bad clock quality does not erase direct same-boundary guest-frame performance.
It makes cross-host causal attribution invalid. A full match can therefore be
valid product evidence while its cause remains `UNKNOWN`.

### Battle and high-load segmentation

Full-match analysis must report the whole match and the worst repeated heavy
periods. There are three allowed segment labels:

| Label | Required evidence |
| --- | --- |
| `BATTLE_DIRECT` | explicit user/app `COMBAT_START` and `COMBAT_END`, or a validated in-memory phase classifier receipt |
| `BATTLE_INFERRED` | a versioned classifier using semantic game-state evidence, with confidence and error rate recorded |
| `TELEMETRY_HIGH_LOAD` | deterministic performance/resource clustering only; never call it a proven battle |

Until semantic combat markers/classification are implemented, use fixed
30-second bins from `MATCH_ENTRY` and label the result
`TELEMETRY_HIGH_LOAD`. This finds the periods worth inspecting without falsely
claiming that low FPS itself proves combat.

For each 30-second bin calculate weighted FPS, p95/p99/max, 1% low, jank rate,
severe rate, missed-vsync rate, source freshness, host-presenter behavior, CPU,
and memory. Rank bins lexicographically by:

1. lowest weighted FPS;
2. highest severe rate;
3. highest jank rate;
4. highest missed-vsync rate;
5. largest maximum interval.

Report at least the worst six bins plus every bin overlapping `VISIBLE_STUTTER`.
Do not use the label `BATTLE_DIRECT` just because a bin is graphically intense.

The desired automatic improvement is a privacy-preserving in-memory phase
classifier that stores only `{phase, round, confidence, monotonic_ns,
classifier_version}` and discards sampled pixels. Until it exists and is
validated against manual markers, battle identity remains inferred/unknown.

### Full-match report order

1. Manifest and marker boundaries.
2. Configuration/package/layer identity and correctness.
3. Coverage, clock quality, and invalidators.
4. Whole-match exact frame distribution.
5. High-load/battle segments and worst one-second windows.
6. Visible-stutter neighborhoods.
7. Source freshness and final-presenter behavior.
8. CPU/memory/thermal/power/audio and structured failures.
9. Valid cross-boundary correlations; otherwise explicit unknowns.
10. Claim ledger and next one-factor candidate.

## 8. Short Combat A/B protocol

The existing code's short-benchmark validity gate is exactly:

```text
duration >= 300 seconds
surface_availability >= 0.95
clock_coverage >= 0.95
p95_clock_rtt_ms <= 10
history_truncated == false
exact_layer_stable == true
correctness_passed == true
```

It automatically ends at 480 seconds. It records one 20-second/32-MiB start
trace and permits at most two 15-second/32-MiB incident traces. An automatic
incident requires two adjacent bad one-second windows where 1% low is below
30 FPS, p99 is at least 50 ms, or a severe interval exists. Trace cooldown is
120 seconds and traces never overlap.

Control matching in current code requires:

- the newest earlier valid `control` among the latest 20 Controls;
- the same `comparison_identity_sha256`;
- the same TFT package version;
- semantic layer identity equal to
  `SurfaceView[com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity]`;
- Control ended before candidate.

It does not prove equivalent battle/round workload, power/thermal state, trace
overhead, or full-match context. The report must show those as compatibility
fields rather than silently assume them.

### Implemented decision engine

| Decision | Exact implemented rule |
| --- | --- |
| `INCONCLUSIVE` | either run invalid; baseline correctness false; or valid values land between all resolving rules |
| `REJECT` | candidate correctness false; p95 or p99 interval is at least 10% worse; or weighted FPS gain is below 5% |
| `HOME_RUN` | after the 5% FPS guard: 1%-low gain at least 20%; jank and severe rates each fall at least 30% relative; and weighted FPS rises at least 10% **or** p95 interval falls at least 15% |
| `PROMISING` | weighted FPS rises at least 5%; 1%-low rises at least 10%; p95 and p99 intervals do not worsen |

Current code calculates/persists `observer_overhead_invalid` when trace-active
versus trace-inactive FPS or p95 differs by more than 5% with at least ten
intervals in each population. It does not currently include that flag in the
decision engine. The report must therefore show both:

```text
code_decision: <implemented decision>
causal_interpretation: INVALID_OBSERVER_OVERHEAD | ELIGIBLE
```

A `HOME_RUN` or `PROMISING` short result requires one cold confirmation and one
marked full match before promotion to normal play.

## 9. Reproducible SQL recipes

Use bound parameters rather than copying example IDs into a new analysis.

### Find marked full matches

```sql
WITH marked AS (
  SELECT id, session_id, kind, observed_utc, monotonic_ns,
         lead(id) OVER (PARTITION BY session_id ORDER BY monotonic_ns) AS next_id,
         lead(kind) OVER (PARTITION BY session_id ORDER BY monotonic_ns) AS next_kind,
         lead(observed_utc) OVER (PARTITION BY session_id ORDER BY monotonic_ns) AS next_utc,
         lead(monotonic_ns) OVER (PARTITION BY session_id ORDER BY monotonic_ns) AS next_ns
  FROM events
  WHERE kind IN ('MATCH_ENTRY','MATCH_END')
)
SELECT *
FROM marked
WHERE kind='MATCH_ENTRY' AND next_kind='MATCH_END'
ORDER BY session_id, monotonic_ns;
```

### Calculate exact whole-range frame metrics

Use `observed_monotonic_ns` for the host-marked range; do not compare host
markers directly to guest `actual_present_ns`.

```sql
WITH raw AS (
  SELECT interval_ms, is_janky, is_severe, missed_vsync_equivalents
  FROM game_frame_intervals
  WHERE session_id=:session_id
    AND observed_monotonic_ns BETWEEN :start_ns AND :end_ns
), ranked AS (
  SELECT *,
         row_number() OVER (ORDER BY interval_ms) AS rn,
         row_number() OVER (ORDER BY interval_ms DESC) AS slow_rn,
         count(*) OVER () AS n
  FROM raw
), summary AS (
  SELECT count(*) AS n,
         sum(interval_ms) AS total_ms,
         max(CASE WHEN rn=(n+1)/2 THEN interval_ms END) AS p50_ms,
         max(CASE WHEN rn=(n*95+99)/100 THEN interval_ms END) AS p95_ms,
         max(CASE WHEN rn=(n*99+99)/100 THEN interval_ms END) AS p99_ms,
         max(interval_ms) AS max_ms,
         sum(is_janky) AS jank_count,
         sum(is_severe) AS severe_count,
         sum(missed_vsync_equivalents) AS missed_vsync_count
  FROM ranked
), slow AS (
  SELECT avg(interval_ms) AS slow_mean_ms
  FROM ranked
  WHERE slow_rn <= (n+99)/100
)
SELECT n,
       1000.0*n/total_ms AS weighted_fps,
       1000.0/slow_mean_ms AS one_percent_low_fps,
       p50_ms, p95_ms, p99_ms, max_ms,
       1.0*jank_count/n AS jank_rate,
       1.0*severe_count/n AS severe_rate,
       1.0*missed_vsync_count/n AS missed_vsync_rate
FROM summary, slow;
```

### Validate exact-layer coverage

```sql
SELECT
  sum(max(0,min(ended_monotonic_ns,:end_ns)-
            max(started_monotonic_ns,:start_ns))) AS measured_ns,
  sum(CASE WHEN status='AVAILABLE' THEN
        max(0,min(ended_monotonic_ns,:end_ns)-
              max(started_monotonic_ns,:start_ns)) ELSE 0 END) AS available_ns,
  count(DISTINCT CASE WHEN status='AVAILABLE' THEN layer_name END) AS exact_layers,
  sum(history_truncated) AS truncated_windows
FROM game_frame_windows
WHERE session_id=:session_id
  AND ended_monotonic_ns>=:start_ns
  AND started_monotonic_ns<=:end_ns;
```

### Find worst one-second windows

```sql
SELECT started_monotonic_ns, ended_monotonic_ns, status, unavailable_reason,
       effective_fps, one_percent_low_fps, p50_interval_ms,
       p95_interval_ms, p99_interval_ms, maximum_interval_ms,
       jank_count, severe_count, missed_vsync_equivalents,
       history_truncated, layer_name
FROM game_frame_windows
WHERE session_id=:session_id
  AND started_monotonic_ns>=:start_ns
  AND ended_monotonic_ns<=:end_ns
ORDER BY maximum_interval_ms DESC, p99_interval_ms DESC
LIMIT 20;
```

### Build deterministic 30-second high-load bins

```sql
WITH raw AS (
  SELECT CAST((observed_monotonic_ns-:start_ns)/30000000000 AS INTEGER) AS bin,
         interval_ms, is_janky, is_severe, missed_vsync_equivalents
  FROM game_frame_intervals
  WHERE session_id=:session_id
    AND observed_monotonic_ns BETWEEN :start_ns AND :end_ns
)
SELECT bin,
       1000.0*count(*)/sum(interval_ms) AS weighted_fps,
       1.0*sum(is_janky)/count(*) AS jank_rate,
       1.0*sum(is_severe)/count(*) AS severe_rate,
       1.0*sum(missed_vsync_equivalents)/count(*) AS missed_vsync_rate,
       max(interval_ms) AS max_interval_ms
FROM raw
GROUP BY bin
ORDER BY weighted_fps ASC, severe_rate DESC, jank_rate DESC,
         missed_vsync_rate DESC, max_interval_ms DESC;
```

### Check clock eligibility

```sql
WITH c AS (
  SELECT host_midpoint_ns, round_trip_ns,
         row_number() OVER (ORDER BY round_trip_ns) AS rn,
         count(*) OVER () AS n
  FROM clock_sync_samples
  WHERE session_id=:session_id
    AND host_midpoint_ns BETWEEN :start_ns AND :end_ns
)
SELECT count(*) AS samples,
       max(CASE WHEN rn=(n*95+99)/100 THEN round_trip_ns END)/1e6 AS p95_rtt_ms,
       1.0*(max(host_midpoint_ns)-min(host_midpoint_ns))/
           (:end_ns-:start_ns) AS in_range_clock_coverage
FROM c;
```

### Correlate a guest window with source and presenter windows

```sql
SELECT g.started_monotonic_ns, g.ended_monotonic_ns,
       g.effective_fps, g.p99_interval_ms, g.maximum_interval_ms,
       s.content_changes, s.identical_frames, s.longest_identical_run_ms,
       h.unique_source_uploads, h.repeated_source_presents,
       h.drawable_misses, h.command_errors,
       h.p95_completion_latency_ms, h.p95_gpu_time_ms
FROM game_frame_windows g
LEFT JOIN stream_freshness_windows s
  ON s.session_id=g.session_id
 AND s.started_monotonic_ns<=g.ended_monotonic_ns
 AND s.ended_monotonic_ns>=g.started_monotonic_ns
LEFT JOIN host_presentation_windows h
  ON h.session_id=g.session_id
 AND h.started_monotonic_ns<=g.ended_monotonic_ns
 AND h.ended_monotonic_ns>=g.started_monotonic_ns
WHERE g.session_id=:session_id
  AND g.started_monotonic_ns>=:start_ns
  AND g.ended_monotonic_ns<=:end_ns;
```

SurfaceFlinger miss counters are cumulative. Use only max-minus-min deltas
between explicit boundaries, never their absolute value as a match metric.

## 10. Required AI-readable output

Every analysis must produce the following logical shape, whether rendered as
JSON, SQL rows, or Markdown:

```json
{
  "manifest": {},
  "validity": {
    "product_evidence": "VALID|PARTIAL|INVALID",
    "comparison_evidence": "VALID|INCONCLUSIVE|NOT_APPLICABLE",
    "surface_coverage": 0.0,
    "clock_coverage": 0.0,
    "p95_clock_rtt_ms": 0.0,
    "invalid_reasons": []
  },
  "whole_match": {
    "duration_seconds": 0.0,
    "intervals": 0,
    "weighted_fps": 0.0,
    "one_percent_low_fps": 0.0,
    "p50_ms": 0.0,
    "p95_ms": 0.0,
    "p99_ms": 0.0,
    "max_ms": 0.0,
    "jank_rate": 0.0,
    "severe_rate": 0.0,
    "missed_vsync_rate": 0.0
  },
  "segments": [
    {
      "segment_id": "...",
      "label": "BATTLE_DIRECT|BATTLE_INFERRED|TELEMETRY_HIGH_LOAD",
      "confidence": "DIRECT|INFERRED|UNKNOWN",
      "start_ns": 0,
      "end_ns": 0,
      "metrics": {},
      "incidents": []
    }
  ],
  "pipeline_boundaries": {
    "guest_actual_present": {},
    "source_freshness": {},
    "final_presenter": {},
    "resources": {},
    "clock_eligibility": "PRECISE|COARSE|UNKNOWN"
  },
  "comparison": {
    "control_id": null,
    "candidate_id": null,
    "deltas": null,
    "code_decision": "NO_DECISION",
    "promotion_status": "NOT_ELIGIBLE"
  },
  "findings": [
    {
      "claim": "...",
      "evidence": [],
      "confidence": "DIRECT|CORRELATED|INFERRED|USER|UNKNOWN",
      "unknowns": [],
      "decision": "KEEP|REJECT|PROMISING|INCONCLUSIVE|NO_DECISION"
    }
  ],
  "privacy": {
    "credentials_stored": false,
    "raw_frames_stored": false,
    "raw_sidecars_local_only": true
  }
}
```

Never omit `invalid_reasons`, `unknowns`, or the difference between the code
decision and the engineering/promotion decision.

## 11. Current full-match finding: Build 7 Combat Latency A

### Identity and boundaries

| Field | Direct finding |
| --- | --- |
| Session | `2026-08-31T02-54-28.329Z-14000b50-bf29-44c6-a963-9203d5313494` |
| Session state at analysis | `RUNNING`; the marked range is saved, but the complete capture is not yet sealed |
| Database | `Captures/<session-id>/TFTMAC_NATIVE_RUNTIME.sqlite` |
| Profile | `tftmac_5gb_native_v1_preset_combat_latency_a` |
| Configuration SHA-256 | `05039d1fd0987f46fc7da8de5f483d8c7ffaf8f39bd1eaecdd1aee11603bbb07` |
| `MATCH_ENTRY` | event 1442, `2026-08-31T03:19:25Z`, host monotonic `262537257186708` |
| `MATCH_END` | event 3065, `2026-08-31T03:51:00Z`, host monotonic `264432310804375` |
| Marked duration | 1,895.054 seconds / 31m35.054s |
| Evidence mode | `FULL_MATCH` |

This match has no `COMBAT_START`, `COMBAT_END`, `VISIBLE_STUTTER`, or formal
`combat_benchmarks` row. It is a marked full match, not a short formal A/B.
The marker rows and bounded match data are queryable now; calculate a final
whole-database hash only after normal app shutdown seals the session.

### Exact guest-frame result

| Metric | Finding |
| --- | ---: |
| Actual-present intervals | 93,724 |
| Weighted FPS | **49.449** |
| 1% low | **16.300 FPS** |
| p50 | 16.965 ms |
| p95 | **33.822 ms** |
| p99 | **48.746 ms** |
| Maximum | **1,254.162 ms** |
| Janky intervals | 17,911 / **19.110%** |
| Severe intervals | 572 / **0.610%** |
| Missed-vsync equivalents | 20,004 / 0.2134 per interval |

Tail distribution:

| Interval range | Count | Share |
| --- | ---: | ---: |
| at or below 16.667 ms | 34,812 | 37.143% |
| above 16.667 through 20 ms | 39,487 | 42.131% |
| above 20 through 33.334 ms | 12,188 | 13.004% |
| above 33.334 through 50 ms | 6,665 | 7.111% |
| above 50 through 100 ms | 543 | 0.579% |
| above 100 through 250 ms | 23 | 0.025% |
| above 250 ms | 6 | 0.006% |

The exact TFT layer was stable, all 1,695 overlapping windows were available,
measured overlap coverage was 100%, and no window reported history truncation.
The interval sum is about 0.297 seconds longer than the marker duration because
intervals arrive in polling batches at the range edges; weighted FPS uses the
source-defined interval formula, not marker duration.

### Worst high-load periods

No semantic combat markers exist, so these are
`TELEMETRY_HIGH_LOAD`, not proven battle labels:

| Match time | Weighted FPS | Jank | Severe | Missed vsync | Max interval |
| --- | ---: | ---: | ---: | ---: | ---: |
| 17:00–17:30 | 38.490 | 44.38% | 4.464% | 652 | 102.091 ms |
| 18:30–19:00 | 39.863 | 45.56% | 1.962% | 592 | 81.526 ms |
| 20:00–20:30 | 39.147 | 43.90% | 1.212% | 615 | 666.743 ms |
| 21:30–22:00 | **33.436** | **57.60%** | 2.582% | **798** | **1,254.162 ms** |
| 22:30–23:00 | 39.189 | 47.40% | 1.759% | 633 | 66.334 ms |
| 25:30–26:00 | 37.781 | 53.99% | 0.964% | 671 | 91.910 ms |

The worst cluster was 21:30–22:00. It is direct evidence of a sustained bad
performance period. With current data it is not direct proof of which battle or
which internal graphics component caused it.

### Source, final presenter, and resources

| Boundary | Direct finding |
| --- | --- |
| Source image rate | mean 49.472 FPS; no sequence-drop increase during marked interval |
| Final Metal output | mean 59.968 FPS |
| Host presentation | 113,618 submitted and completed; 90,387 unique uploads; 23,231 repeated-source presents |
| Presenter correctness | zero drawable misses; zero command errors |
| Final Metal cost | maximum completion latency 7.494 ms; maximum GPU time 3.267 ms |
| Emulator CPU | mean 513.65%; range 385.9–589.0% |
| Emulator RSS | mean 4,429.4 MiB; maximum 5,843.3 MiB |
| Guest memory | minimum 777.7 MiB available / 15.81%; maximum swap used 669.5 MiB |
| Host state | AC power; thermal state always `NOMINAL` |
| Audio | CoreAudio, active 48 kHz stereo, one active track, zero underruns |
| Structured faults | 14 confirmed guest memory-kill signatures in one aggregate near +27:17.774; no match-range ANR, input timeout, TFT fatal, ANGLE/Vulkan warning, or audio-error count |
| Pipeline aggregates | zero named gfxstream warning, ASG stall, Vulkan error, MoltenVK warning, shader error, or fence-timeout counts |

The presenter completed near 60 Hz while reusing 23,231 source frames and while
guest actual presentation was irregular. This directly makes TFTMAC's final
Metal pass a poor explanation for the missing useful frames in this match. It
does not distinguish Unreal, ANGLE, ASG/gfxstream, or MoltenVK upstream.

The 14 memory-kill signatures identify actual guest victims by classifier
syntax, but the normalized aggregate does not store victim identity. Their
relationship to TFT frame loss is therefore `UNKNOWN`; do not say TFT itself was
killed.

### Validity and decision

| Gate | Result |
| --- | --- |
| Full-match product evidence | **VALID** for direct player-facing frame distribution |
| Exact layer/coverage/history | pass |
| In-range clock coverage | 97.494% |
| Clock p95 RTT | **86.757 ms**, above 10 ms |
| Precise/coarse cross-host cause | **INVALID / UNKNOWN** |
| Matched Control | absent |
| Formal short benchmark row | absent |
| Candidate performance decision | **NO_DECISION / INCONCLUSIVE** |

Direct conclusion: the marked match had materially poor tail behavior despite a
near-60 final output cadence. Combat Latency A is neither promoted nor rejected
by this single unmatched run. The run is a valid candidate baseline and a valid
product-performance problem record; exact internal ownership remains unknown
because the clock gate failed and the frame-ID boundary ring does not yet exist.

## 12. Comparison and promotion policy

For a one-factor candidate:

1. Preserve one current valid Control full match.
2. Run the candidate under the same package, display, High/60/OFF game settings,
   power state, and comparable play pattern.
3. Compare whole-match distributions and matched high-load/battle segments.
4. Use the short code decision when a valid `COMBAT_AB` pair exists.
5. Reject immediately for any boot/render/input/audio/login/cleanup regression or
   direct unacceptable player experience.
6. Cold-confirm a short winner.
7. Require one full marked match before normal-play promotion.

Full matches need not have identical length. Compare:

- whole-run weighted/tail metrics with coverage shown;
- per-battle metrics when battle segmentation is direct/validated;
- otherwise the median and worst quartile of fixed high-load bins;
- worst one-second incidents;
- sustained resource/thermal/memory state;
- correctness and direct player report.

Never declare a gain from one isolated best window, different package/settings,
different semantic layer, lobby-versus-combat, or output cadence alone.

## 13. Retention and privacy

Retain:

- latest accepted Control full match;
- latest candidate full match and any matching short A/B;
- current package/runtime/configuration receipts;
- every rejected candidate's compact metrics and reason;
- unresolved incident evidence;
- normalized trace summaries and SHA-256 links when valid.

Older raw captures may be compacted only after preserving session ID, marker
range, configuration/package/runtime identity, formula version, verdict, key
metrics, source database hash, and artifact hashes.

Raw logcat, raw traces, and any sensitive sidecars remain local/private. Reports
must never contain credentials, tokens, typed content, login screenshots, or raw
frames.

## 14. Known analysis gaps

1. Native full-match semantic battle/round detection is not implemented.
2. The current menu records only match entry/end, not combat/round/result.
3. Current comparison matching does not enforce equivalent battle phase,
   thermal/power state, or full-match context.
4. `observer_overhead_invalid` is stored but does not alter the code decision.
5. Cold-confirmation/promotion linkage is policy, not a normalized SQL field.
6. Clock RTT is too high in the current full match for cross-host cause.
7. No common frame ID currently spans guest submit through final present.

These gaps limit attribution and automation; they do not erase the direct
player-facing frame distribution already captured.
