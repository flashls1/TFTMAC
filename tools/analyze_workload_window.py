#!/usr/bin/env python3
"""Summarize native frame/resource windows inside one confirmed workload interval."""
from __future__ import annotations

import argparse
import json
import math
import sqlite3
import statistics
from typing import Iterable


def percentile(values: Iterable[float], p: float) -> float | None:
    ordered = sorted(float(v) for v in values if v is not None and math.isfinite(float(v)))
    if not ordered:
        return None
    if len(ordered) == 1:
        return ordered[0]
    index = (len(ordered) - 1) * p
    lower = math.floor(index)
    upper = math.ceil(index)
    if lower == upper:
        return ordered[lower]
    fraction = index - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * fraction


def mean(values: Iterable[float]) -> float | None:
    values = [float(v) for v in values if v is not None and math.isfinite(float(v))]
    return statistics.fmean(values) if values else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("database")
    parser.add_argument("start_monotonic_ns", type=int)
    parser.add_argument("end_monotonic_ns", type=int)
    args = parser.parse_args()
    if args.end_monotonic_ns <= args.start_monotonic_ns:
        raise SystemExit("workload interval must have positive duration")

    connection = sqlite3.connect(args.database)
    connection.row_factory = sqlite3.Row
    frames = connection.execute(
        """
        SELECT started_monotonic_ns, ended_monotonic_ns, frame_count,
               effective_fps, one_percent_low_fps, p95_interval_ms,
               p99_interval_ms, jank_count, severe_count,
               missed_vsync_equivalents
          FROM game_frame_windows
         WHERE status = 'AVAILABLE'
           AND started_monotonic_ns >= ?
           AND ended_monotonic_ns <= ?
         ORDER BY started_monotonic_ns
        """,
        (args.start_monotonic_ns, args.end_monotonic_ns),
    ).fetchall()
    resources = connection.execute(
        """
        SELECT emulator_cpu_percent, emulator_rss_kib
          FROM resource_samples
         WHERE monotonic_ns BETWEEN ? AND ?
        """,
        (args.start_monotonic_ns, args.end_monotonic_ns),
    ).fetchall()
    host = connection.execute(
        """
        SELECT available_kib, swap_used_kib, thermal_state
          FROM host_resource_samples
         WHERE monotonic_ns BETWEEN ? AND ?
        """,
        (args.start_monotonic_ns, args.end_monotonic_ns),
    ).fetchall()
    host_presentation = connection.execute(
        """
        SELECT started_monotonic_ns, ended_monotonic_ns,
               submitted_frames, completed_frames, drawable_misses,
               command_errors, p95_completion_latency_ms,
               maximum_completion_latency_ms, p95_gpu_time_ms,
               maximum_gpu_time_ms
          FROM host_presentation_windows
         WHERE started_monotonic_ns < ?
           AND ended_monotonic_ns > ?
         ORDER BY started_monotonic_ns
        """,
        (args.end_monotonic_ns, args.start_monotonic_ns),
    ).fetchall()
    freshness = connection.execute(
        """
        SELECT started_monotonic_ns, ended_monotonic_ns, received_frames,
               content_changes, identical_frames, longest_identical_run_frames,
               longest_identical_run_ms, sequence_drops
          FROM stream_freshness_windows
         WHERE started_monotonic_ns < ?
           AND ended_monotonic_ns > ?
         ORDER BY started_monotonic_ns
        """,
        (args.end_monotonic_ns, args.start_monotonic_ns),
    ).fetchall()
    pipeline_lineage_count = connection.execute(
        "SELECT count(*) FROM pipeline_lineage WHERE session_id IN (SELECT DISTINCT session_id FROM game_frame_windows)"
    ).fetchone()[0]
    pipeline_event_count = connection.execute(
        "SELECT count(*) FROM pipeline_events WHERE session_id IN (SELECT DISTINCT session_id FROM game_frame_windows)"
    ).fetchone()[0]
    connection.close()

    severe_windows = [
        row for row in frames if int(row["severe_count"] or 0) > 0
    ]
    severe_start = min((int(row["started_monotonic_ns"]) for row in severe_windows), default=None)
    severe_end = max((int(row["ended_monotonic_ns"]) for row in severe_windows), default=None)
    severe_present = [
        row for row in host_presentation
        if severe_start is not None
        and int(row["started_monotonic_ns"]) < severe_end
        and int(row["ended_monotonic_ns"]) > severe_start
    ]
    severe_freshness = [
        row for row in freshness
        if severe_start is not None
        and int(row["started_monotonic_ns"]) < severe_end
        and int(row["ended_monotonic_ns"]) > severe_start
    ]
    presenter_misses = sum(int(row["drawable_misses"] or 0) for row in severe_present)
    presenter_errors = sum(int(row["command_errors"] or 0) for row in severe_present)
    source_updates = sum(int(row["received_frames"] or 0) for row in severe_freshness)
    source_identical = sum(int(row["identical_frames"] or 0) for row in severe_freshness)
    source_drops = sum(int(row["sequence_drops"] or 0) for row in severe_freshness)
    # This is deliberately a bounded classification.  The native presenter can
    # prove that its own Metal work completed, while stream freshness can show
    # that fewer source updates arrived.  Without pipeline lineage we cannot
    # name the guest or upstream owner.
    if severe_windows and severe_present and presenter_misses == 0 and presenter_errors == 0 and severe_freshness:
        bottleneck = {
            "classification": "HOST_PRESENTATION_HEALTHY_GUEST_PRESENT_UNKNOWN",
            "firstProvenBoundary": "GUEST_OR_UPSTREAM_SOURCE_PUBLICATION",
            "owner": "UNKNOWN",
            "confidence": 0.55 if source_updates else 0.35,
            "evidence": {
                "severeWindowCount": len(severe_windows),
                "hostPresentationWindowCount": len(severe_present),
                "hostDrawableMisses": presenter_misses,
                "hostCommandErrors": presenter_errors,
                "sourceReceivedFrames": source_updates,
                "sourceIdenticalFrames": source_identical,
                "sourceSequenceDrops": source_drops,
                "pipelineEventCount": pipeline_event_count,
                "pipelineLineageCount": pipeline_lineage_count,
            },
            "rootOutcome": "UNKNOWN_PRESENT_LINEAGE_GAP",
            "nextSmallestEvidence": "Capture and join a present_lineage_id from guest submission through the exact SurfaceFlinger present.",
        }
    else:
        bottleneck = {
            "classification": "INSUFFICIENT_CROSS_BOUNDARY_EVIDENCE",
            "firstProvenBoundary": "UNKNOWN",
            "owner": "UNKNOWN",
            "confidence": 0.0,
            "evidence": {
                "severeWindowCount": len(severe_windows),
                "hostPresentationWindowCount": len(severe_present),
                "pipelineEventCount": pipeline_event_count,
                "pipelineLineageCount": pipeline_lineage_count,
            },
            "rootOutcome": "UNKNOWN_OWNER",
            "nextSmallestEvidence": "Capture a complete pipeline event and present-lineage join for the scored interval.",
        }

    output = {
        "status": "AVAILABLE" if frames else "UNAVAILABLE",
        "interval": {
            "startMonotonicNs": args.start_monotonic_ns,
            "endMonotonicNs": args.end_monotonic_ns,
            "durationSeconds": (args.end_monotonic_ns - args.start_monotonic_ns) / 1_000_000_000,
        },
        "frameWindows": len(frames),
        "totalFrames": sum(int(row["frame_count"] or 0) for row in frames),
        "totalJankyFrames": sum(int(row["jank_count"] or 0) for row in frames),
        "totalSevereStalls": sum(int(row["severe_count"] or 0) for row in frames),
        "jankyFrameRatePercent": (
            100.0 * sum(int(row["jank_count"] or 0) for row in frames)
            / sum(int(row["frame_count"] or 0) for row in frames)
            if sum(int(row["frame_count"] or 0) for row in frames) else None
        ),
        "averageFPS": mean(row["effective_fps"] for row in frames),
        "medianFPS": percentile((row["effective_fps"] for row in frames), 0.5),
        "p95FPS": percentile((row["effective_fps"] for row in frames), 0.95),
        "p99FPS": percentile((row["effective_fps"] for row in frames), 0.99),
        "medianOnePercentLowFPS": percentile((row["one_percent_low_fps"] for row in frames), 0.5),
        "medianP95FrameIntervalMs": percentile((row["p95_interval_ms"] for row in frames), 0.5),
        "medianP99FrameIntervalMs": percentile((row["p99_interval_ms"] for row in frames), 0.5),
        "jankyFramesPerWindow": mean(row["jank_count"] for row in frames),
        "severeStallsPerWindow": mean(row["severe_count"] for row in frames),
        "missedVsyncPerWindow": mean(row["missed_vsync_equivalents"] for row in frames),
        "resourceSamples": len(resources),
        "emulatorCPUPercentP95": percentile((row["emulator_cpu_percent"] for row in resources), 0.95),
        "emulatorRSSKiBP95": percentile((row["emulator_rss_kib"] for row in resources), 0.95),
        "hostAvailableKiBP05": percentile((row["available_kib"] for row in host), 0.05),
        "hostSwapUsedKiBMax": max((row["swap_used_kib"] for row in host if row["swap_used_kib"] is not None), default=None),
        "thermalStates": sorted({row["thermal_state"] for row in host if row["thermal_state"]}),
        "bottleneckEvidence": bottleneck,
    }
    print(json.dumps(output, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
