# TFTMAC graphics-path boundary summary

**Observed:** 2026-09-09, local Mac, America/Chicago  
**Scope:** the approved silent, evidence-driven 60 FPS campaign

## Decision-critical result

The current evidence does not identify a guest-to-display optimization that can
be claimed to produce 60 FPS. The hidden diagnostic runner now proves the
guest GLES2 decoder, render-control frame marker, and color-buffer blit
boundaries, but it never enters the host `DisplayGl::post` boundary. The
ordinary real-game captures therefore remain the authoritative presentation
oracle.

## What is proven

- The silent policy is active: the rebuilt DEV launch used
  `TFTMAC_AUTONOMOUS_SILENT=1`, enumerated zero visible native windows, and
  reached the native first-frame path. See
  `2026-09-09-silent-launch-gate.md`.
- The exact custom host backend is loaded in the hidden AVD. Constructor
  admission produced a sealed `TFTPIPE1` segment from the decoder process.
- The actual host GLES2 decoder emitted 43,407 opcode markers and 35,925
  completed duration spans. The observed high-cost calls were shader compile,
  draw, link, and buffer-update work; these spans are host-call timings, not a
  displayed-frame budget.
- Render-control flush and frame markers are linked one-to-one in the hidden
  run. Flush duration was median 240.5 microseconds, p95 714.25 microseconds,
  and p99 3.164542 milliseconds. The inner color-buffer blit was median about
  232 microseconds, p95 865 microseconds, and p99 2.60 milliseconds.
- The display-post probe emitted zero events in the same run. Hidden emulator
  tests cannot prove native latch/present cadence or unique delivered frames.

## Real-game oracle

The latest long real TFT capture recorded 110,502 frame intervals at weighted
56.18 FPS, with p95 29.02 ms, p99 33.88 ms, 195 intervals above 50 ms, and
five intervals above one second. Minute windows reached about 44.7–45.8 FPS;
native delivery followed the slower TFT source. The native presenter itself
showed a mean window GPU time of about 0.218 ms and a highest observed command
of 2.706 ms, so the available evidence points upstream of native presentation.

The historical ANGLE reuse lead remains unpromoted: its real-match run proved
the candidate libraries were loaded but recorded zero retained bindings and
zero retained syncs. The older RHI percentages are overlapping inclusive
profiles, not recoverable frame milliseconds.

## Current campaign admission

The existing silent campaign was invoked once after the trace work. It exited
before launching DEV because internal free space was `5,963,923,456` bytes,
below the plan's mandatory 8 GiB floor. This is a resource-pressure blocker,
not a performance result and not a candidate rejection.

## Next admissible action

Restore at least 8 GiB free on the internal volume, then run the existing
campaign admission and a clean baseline/candidate comparison. Do not promote
the ANGLE view-reuse path, a fence path, or a host router until a mechanism is
proven exercised in the same real TFT process and the decision-critical frame
oracle shows a material critical-path change. No 60 FPS win is established by
this receipt.

## Gate status

Fresh ZoeMC and ZenGate V4.1 executions for this exact plan were not callable
in the local tool surface during this run. No current gate pass is claimed;
this receipt records evidence and the blocking admission state only.
