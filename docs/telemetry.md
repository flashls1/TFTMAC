# TFTMAC Telemetry and Diagnostics

TFTMAC diagnostics are local-first and evidence-driven.

## Native capture

Each native app start creates a private `0700` session directory under:

```text
~/Library/Application Support/TFTMAC/Captures/<session-id>/
```

`TFTMAC_NATIVE_RUNTIME.sqlite` is the queryable session authority. `native-events.jsonl`, emulator stdout/stderr and session-scoped `logcat.raw.txt` are local sidecars. Raw logcat is sensitive, never copied into SQLite, and must not be published.

Useful evidence may include:

- host monotonic timestamps;
- emulator/runtime state;
- one-second native frame-ingress interval windows and visual checkpoints;
- raw-gRPC source freshness plus native Metal presentation internals retained as
  hidden correctness/regression context and never called Unreal FPS;
- aggregate logcat fault counts with raw lines kept outside SQL;
- SurfaceFlinger render-rate and cumulative missed/HWC/GPU counters sampled at boundaries and every 30 seconds during gameplay;
- AudioFlinger active output, sample rate, stereo state, tracks and underruns;
- host CPU/RSS/memory-pressure samples;
- guest `/proc/meminfo` and host/guest monotonic clock calibration;
- renderer/graphics state;
- package version, installer, and signer evidence;
- explicit user stutter markers.

The base graphics logger is automatic: it opens from the observed TFT
process/layer lifecycle, continues through process/layer replacement or loss,
and seals only at TFT process or app close. It does not wait for a match marker,
a battle classifier, or a Combat Benchmark. The Telemetry menu's optional
markers are `MATCH_ENTRY`, `CAROUSEL_START`, `CAROUSEL_END`, `COMBAT_START`,
`COMBAT_END`, `VISIBLE_STUTTER`, and `MATCH_END`. Markers are semantic
annotations; they do not make an incomplete or causally ambiguous capture valid
by themselves. The controlled Combat Benchmark remains an optional A/B
protocol. `gfxinfo` is not Unreal/Vulkan frame authority. Perfetto remains a
bounded incident diagnostic rather than an always-on observer.

Use the read-only flight-recorder analyzer for a sealed capture:

```text
scripts/analyze-flight-recorder.command \
  --format markdown \
  --output /tmp/tft-flight-recorder.md \
  "$HOME/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures/<session>"
```

It joins frame windows, host/guest resources, input dispatch, native clock
offsets, first-present timing, audio health, incidents, and semantic markers.
The first-present value is explicitly labeled temporal evidence because a
shared transport work ID is still required for causal ownership.

The current source schema associates automatically captured samples with
`graphics_runs`, records a canonical graphics-stack receipt and SHA-256 at each
snapshot, and links exact guest intervals to their containing frame window when
available. Every exact guest interval and one-second game window also carries
the active immutable `stack_sha256`, so stack identity survives incomplete
window joins and later layer changes. The older Build 8 captures remain
historical runtime evidence. The schema-v6 flight-recorder implementation is
build-verified in the current worktree, but it is not claimed to be installed
or exercised by the normal 18.3 DEV app until a fresh acceptance run produces
a sealed manifest. A stack receipt establishes the observed route/configuration
for that sample; it does not prove causal ownership of a slow frame.

New captures create one automatic `ONE_MATCH_PER_LAUNCH` row in `game_runs`
when the logger initializes and close it only when the logger seals. This is
the complete capture boundary: startup, loading, lobby, every playable round,
and shutdown remain in one evidence stream. Relaunching the app starts the next
match record. `game_process_sessions` provides additional automatic
TFT-process boundaries and binds them to that one-launch run. `phase_markers` stores optional annotations such as `MATCH_ENTRY`,
`CAROUSEL_START`, `COMBAT_START`, and `MATCH_END`; those annotations never open,
close, or invalidate the automatic run. Missing or accidental manual markers
therefore cannot discard the match or make the capture unusable.

Schema version 6 adds a sealed `capture_manifests` row and
`capture-manifest.json`, producer-health rows, a per-snapshot
`pipeline_truth_matrix`, decoded `PipelineEventV1` segments, stage spans, and
lineage findings. The manifest records the SQLite/WAL/SHM and sidecar hashes,
runtime configuration hash, package-receipt hash, and every producer's
`HEALTHY`, `MISSING`, `GAPPED`, `UNSEALED`, or `UNKNOWN` status. A zero-row
producer is never treated as a healthy absence: it is classified as missing or
unknown with a reason. The database hash is explicitly scoped to the bytes
before the final manifest row, so verification does not claim a circular hash.

Pipeline truth is separated by boundary. `DIRECT` and `CORRELATED` evidence
comes from observed process, package, guest, emulator, SurfaceFlinger, or
presenter facts; launch requests remain `REQUESTED`; inferred values remain
`INFERRED`; and missing evidence is `UNKNOWN`. MoltenVK's internal Metal work
and TFTMAC's native Metal presenter are separate rows. The deterministic
analyzer may name a root only after complete lineage, zero loss, valid clocks,
exact surface identity, repeated late lineages, and the observer-overhead gate;
otherwise it emits an explicit unknown outcome. The read-only analyzer verifies
the manifest file and every listed sidecar hash. The SQLite hash is reported
with its explicit pre-final-row scope. A prior process termination produces
`capture-recovery.json` and `RECOVERED_UNSEALED`; that record is retained for
failure analysis but cannot support a causal root decision.

## Retention

Keep only evidence that protects a current product decision:

- latest successful playable baseline;
- latest native-app acceptance capture;
- current package-authority evidence;
- current promoted A/B evidence;
- current unresolved crash/failure capture.

Superseded runs should be compacted to their session ID, configuration hash, verdict, key metrics, and relevant source hashes before raw bulk is removed.

## Privacy

Diagnostics must not intentionally capture or publish Google/Riot credentials, tokens, cookies, account identifiers, private Android userdata, or unrelated application data. Sanitize any excerpt before sharing it.

No remote telemetry service is required for the current TFTMAC runtime or acceptance path.

## Conservative graphics views

The automatic logger may construct per-window stack joins through
`graphics_run_id`, direct per-frame `stack_sha256`, frame-window linkage, and
the matching snapshot receipt. Its user-facing views are conservative: `TFT`
identifies exact SurfaceFlinger presentation and `PIPE` identifies controller
freshness/transport delivery. The final TFTMAC presenter is retained only as a
hidden correctness receipt. A report must use `UNKNOWN` when a trusted work
handoff is missing; current Build 8 evidence cannot identify an internal
graphics owner. CPU, RAM, thermal, power, and audio samples remain
health/correctness context only in this graphics-only optimization effort.
