#!/opt/homebrew/bin/python3
"""Analyze sealed TFTMAC native captures without mutating or exposing raw logs.

The analyzer joins the existing automatic recorder layers by monotonic time and
uses native_clock_samples when a guest SurfaceFlinger timestamp must be mapped
to the host input clock. It deliberately reports temporal joins as temporal
evidence; it never promotes them to causal ownership without PipelineEventV1
lineage evidence.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import sqlite3
import statistics
import sys
from bisect import bisect_left
from pathlib import Path
from typing import Any, Iterable


TABLES = (
    "sessions", "runtime_receipts", "events", "game_runs", "phase_markers", "game_frame_windows",
    "game_frame_intervals", "input_dispatch_samples", "audio_samples",
    "resource_samples", "guest_memory_samples", "host_resource_samples",
    "native_clock_samples", "presentation_samples",
    "graphics_pipeline_incidents", "pipeline_experiment_runs",
    "pipeline_lineage", "pipeline_findings", "pipeline_events", "pipeline_event_segments",
    "pipeline_stage_spans", "pipeline_truth_matrix", "pipeline_source_sites", "producer_health", "capture_manifests",
    "clock_sync_samples",
)
MARKER_KINDS = {
    "MATCH_ENTRY", "CAROUSEL_START", "CAROUSEL_END", "PLANNING_START",
    "PLANNING_END", "COMBAT_START", "COMBAT_END", "ROUND_START",
    "ROUND_END", "MATCH_END", "VISIBLE_STUTTER", "CAPTURE_START", "CAPTURE_END",
}
AUTOMATIC_MARKER_KINDS = {"CAPTURE_START", "CAPTURE_END"}


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def resolve_database(path: Path) -> Path:
    if path.is_dir():
        path = path / "TFTMAC_NATIVE_RUNTIME.sqlite"
    if not path.is_file():
        raise ValueError(f"capture database does not exist: {path}")
    return path.resolve()


def open_read_only(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def table_names(connection: sqlite3.Connection) -> set[str]:
    return {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }


def table_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in connection.execute(f"PRAGMA table_info([{table}])")}


def rows(connection: sqlite3.Connection, query: str, args: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    return [dict(row) for row in connection.execute(query, args)]


def percentiles(values: Iterable[float]) -> dict[str, float | int | None]:
    values = sorted(float(value) for value in values if value is not None)
    if not values:
        return {"n": 0, "min": None, "p50": None, "p95": None, "p99": None, "max": None, "avg": None}

    def percentile(p: float) -> float:
        index = min(len(values) - 1, max(0, math.ceil(p * len(values)) - 1))
        return values[index]

    return {
        "n": len(values),
        "min": values[0],
        "p50": percentile(0.50),
        "p95": percentile(0.95),
        "p99": percentile(0.99),
        "max": values[-1],
        "avg": statistics.fmean(values),
    }


def nearest(samples: list[dict[str, Any]], times: list[int], value: int, max_delta_ns: int = 30_000_000_000) -> dict[str, Any] | None:
    if not times:
        return None
    index = bisect_left(times, value)
    candidates = [candidate for candidate in (index - 1, index) if 0 <= candidate < len(times)]
    chosen = min(candidates, key=lambda candidate: abs(times[candidate] - value))
    return samples[chosen] if abs(times[chosen] - value) <= max_delta_ns else None


def correlation(rows_: list[dict[str, Any]], left: str, right: str) -> dict[str, float | int | None]:
    pairs = [
        (float(row[left]), float(row[right]))
        for row in rows_
        if row.get(left) is not None and row.get(right) is not None
    ]
    if len(pairs) < 3:
        return {"n": len(pairs), "r": None}
    left_mean = statistics.fmean(pair[0] for pair in pairs)
    right_mean = statistics.fmean(pair[1] for pair in pairs)
    numerator = sum((a - left_mean) * (b - right_mean) for a, b in pairs)
    denominator = math.sqrt(
        sum((a - left_mean) ** 2 for a, _ in pairs)
        * sum((b - right_mean) ** 2 for _, b in pairs)
    )
    return {"n": len(pairs), "r": numerator / denominator if denominator else 0.0}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_manifest(database: Path, manifests: list[dict[str, Any]]) -> dict[str, Any]:
    """Validate the immutable manifest and every hash it can validate post-seal.

    The recorder hashes SQLite before inserting the final capture_manifests row,
    so the current database file cannot be compared byte-for-byte afterward.
    That limitation is reported explicitly instead of being treated as a pass.
    """
    if not manifests:
        return {"status": "MISSING", "reason": "CAPTURE_MANIFEST_ROW_MISSING", "sidecars": []}
    row = manifests[-1]
    manifest_path = database.parent / str(row.get("manifest_relative_path") or "capture-manifest.json")
    result: dict[str, Any] = {
        "status": "VALIDATED",
        "manifest_path": str(manifest_path),
        "manifest_sha256": {"expected": row.get("manifest_sha256"), "actual": None, "match": False},
        "database_sha256": {
            "expected": row.get("database_sha256"),
            "actual": sha256_file(database),
            "status": "NOT_COMPARABLE_PRE_FINAL_ROW" if row.get("hash_scope") == "database_hash_is_before_capture_manifests_row" else "UNVERIFIED",
        },
        "sidecars": [],
    }
    if not manifest_path.is_file():
        result["status"] = "INVALID"
        result["reason"] = "MANIFEST_FILE_MISSING"
        return result
    try:
        manifest_bytes = manifest_path.read_bytes()
        actual_manifest_hash = hashlib.sha256(manifest_bytes).hexdigest()
        expected_manifest_hash = str(row.get("manifest_sha256") or "")
        result["manifest_sha256"] = {
            "expected": expected_manifest_hash,
            "actual": actual_manifest_hash,
            "match": bool(expected_manifest_hash) and actual_manifest_hash == expected_manifest_hash,
        }
        manifest = json.loads(manifest_bytes.decode("utf-8"))
        expected_sidecars = manifest.get("sidecar_hashes", {})
        if not isinstance(expected_sidecars, dict):
            raise ValueError("sidecar_hashes is not an object")
        for relative, expected in sorted(expected_sidecars.items()):
            sidecar_path = database.parent / str(relative)
            if not sidecar_path.is_file():
                result["sidecars"].append({"path": str(relative), "status": "MISSING"})
                continue
            actual = sha256_file(sidecar_path)
            result["sidecars"].append({
                "path": str(relative),
                "expected": str(expected),
                "actual": actual,
                "match": actual == str(expected),
            })
        valid_manifest_hash = result["manifest_sha256"]["match"]
        valid_sidecars = all(item.get("match") is True for item in result["sidecars"])
        if not valid_manifest_hash or not valid_sidecars:
            result["status"] = "INVALID"
            result["reason"] = "MANIFEST_OR_SIDECAR_HASH_MISMATCH"
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        result["status"] = "INVALID"
        result["reason"] = f"MANIFEST_PARSE_FAILED:{error}"
    return result


def analyze_capture(database: Path) -> dict[str, Any]:
    connection = open_read_only(database)
    try:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise ValueError(f"SQLite integrity_check failed for {database}: {integrity}")
        available_tables = table_names(connection)
        session = rows(connection, "SELECT * FROM sessions ORDER BY started_utc LIMIT 1")
        if not session:
            raise ValueError(f"capture has no session row: {database}")
        session = session[0]
        game_runs: list[dict[str, Any]] = []
        if "game_runs" in available_tables:
            columns = table_columns(connection, "game_runs")
            selected = [
                "game_run_id", "started_utc", "started_monotonic_ns", "ended_utc",
                "ended_monotonic_ns", "status", "configuration_sha256", "profile_id",
            ]
            selected += [name for name in ("run_scope", "start_reason", "end_reason") if name in columns]
            game_runs = rows(connection, f"SELECT {', '.join(selected)} FROM game_runs ORDER BY started_monotonic_ns")
        process_sessions: list[dict[str, Any]] = []
        if "game_process_sessions" in available_tables:
            columns = table_columns(connection, "game_process_sessions")
            selected = ["game_pid", "started_utc", "started_monotonic_ns", "ended_utc", "ended_monotonic_ns"]
            if "game_run_id" in columns:
                selected.append("game_run_id")
            process_sessions = rows(
                connection,
                f"SELECT {', '.join(selected)} FROM game_process_sessions ORDER BY started_monotonic_ns",
            )

        frame_windows = rows(connection, """
            SELECT started_monotonic_ns, ended_monotonic_ns, status,
                   unavailable_reason, effective_fps, one_percent_low_fps,
                   p99_interval_ms, jank_count, severe_count,
                   missed_vsync_equivalents
            FROM game_frame_windows ORDER BY started_monotonic_ns
        """) if "game_frame_windows" in available_tables else []
        available_windows = [row for row in frame_windows if row["status"] == "AVAILABLE"]
        host = rows(connection, """
            SELECT monotonic_ns, available_kib, compressed_kib, swap_used_kib, pageouts
            FROM host_resource_samples ORDER BY monotonic_ns
        """) if "host_resource_samples" in available_tables else []
        emulator = rows(connection, """
            SELECT monotonic_ns, emulator_cpu_percent, emulator_rss_kib
            FROM resource_samples ORDER BY monotonic_ns
        """) if "resource_samples" in available_tables else []
        guest = rows(connection, """
            SELECT monotonic_ns, available_kib, swap_free_kib
            FROM guest_memory_samples ORDER BY monotonic_ns
        """) if "guest_memory_samples" in available_tables else []
        inputs = rows(connection, """
            SELECT sequence, native_event_monotonic_ns, enqueued_monotonic_ns,
                   dispatched_monotonic_ns, rpc_completed_monotonic_ns, status
            FROM input_dispatch_samples ORDER BY enqueued_monotonic_ns
        """) if "input_dispatch_samples" in available_tables else []
        audio = rows(connection, """
            SELECT monotonic_ns, active_output, sample_rate_hz,
                   partial_underruns, empty_underruns
            FROM audio_samples ORDER BY monotonic_ns
        """) if "audio_samples" in available_tables else []
        events = rows(connection, """
            SELECT monotonic_ns, kind, payload_json FROM events ORDER BY monotonic_ns
        """) if "events" in available_tables else []
        normalized_markers = rows(connection, """
            SELECT monotonic_ns, phase AS kind, game_run_id,
                   source, confidence, clock_domain
            FROM phase_markers ORDER BY monotonic_ns
        """) if "phase_markers" in available_tables else []
        clock = rows(connection, """
            SELECT host_t0_ns, host_t3_ns, offset_lower_ns, offset_upper_ns,
                   uncertainty_ns, state
            FROM native_clock_samples ORDER BY host_t0_ns
        """) if "native_clock_samples" in available_tables else []
        intervals = rows(connection, """
            SELECT actual_present_ns FROM game_frame_intervals
            WHERE actual_present_ns IS NOT NULL ORDER BY actual_present_ns
        """) if "game_frame_intervals" in available_tables else []
        incidents = rows(connection, """
            SELECT observed_monotonic_ns, trigger, causal_owner, causal_confidence,
                   layer_name FROM graphics_pipeline_incidents
            ORDER BY observed_monotonic_ns
        """) if "graphics_pipeline_incidents" in available_tables else []
        producer_health = rows(connection, """
            SELECT producer_name, required, first_observed_monotonic_ns, last_observed_monotonic_ns,
                   expected_cadence_ms, row_count, gap_count, loss_count, status, reason, evidence_path
            FROM producer_health WHERE session_id = ? ORDER BY producer_name
        """, (session["session_id"],)) if "producer_health" in available_tables else []
        truth_matrix = rows(connection, """
            SELECT sample_label, boundary, value, source, confidence,
                   observed_interval_start_ns, observed_interval_end_ns,
                   binary_or_source_hash, evidence_state
            FROM pipeline_truth_matrix WHERE session_id = ? ORDER BY observed_monotonic_ns, id
        """, (session["session_id"],)) if "pipeline_truth_matrix" in available_tables else []
        source_sites = rows(connection, """
            SELECT source_site_id, component, source_commit, source_blob_sha256,
                   relative_path, function_name, line_number, instrumentation_state,
                   site_range_hash, loaded_binary_uuid, loaded_binary_sha256,
                   instrumentation_schema_version
            FROM pipeline_source_sites ORDER BY source_site_id, component, source_commit
        """) if "pipeline_source_sites" in available_tables else []
        findings = rows(connection, """
            SELECT finding_id, epoch_id, created_utc, state, first_divergent_boundary,
                   owner_component, confidence, supporting_lineage_count,
                   explicit_unknowns_json, analyzer_version
            FROM pipeline_findings WHERE session_id = ? ORDER BY created_utc
        """, (session["session_id"],)) if "pipeline_findings" in available_tables else []
        manifests = rows(connection, """
            SELECT session_id, game_run_id, schema_version, database_sha256, wal_sha256, shm_sha256,
                   sidecar_hashes_json, runtime_configuration_sha256, package_receipt_sha256,
                   producer_coverage_json, manifest_relative_path, manifest_sha256, hash_scope,
                   sealed_utc, seal_status
            FROM capture_manifests WHERE session_id = ?
        """, (session["session_id"],)) if "capture_manifests" in available_tables else []
        manifest_verification = verify_manifest(database, manifests)

        host_times = [int(row["monotonic_ns"]) for row in host]
        emulator_times = [int(row["monotonic_ns"]) for row in emulator]
        guest_times = [int(row["monotonic_ns"]) for row in guest]
        joined: list[dict[str, Any]] = []
        for frame in available_windows:
            center = (int(frame["started_monotonic_ns"]) + int(frame["ended_monotonic_ns"])) // 2
            host_row = nearest(host, host_times, center)
            emulator_row = nearest(emulator, emulator_times, center)
            guest_row = nearest(guest, guest_times, center)
            joined.append({
                "p99_interval_ms": frame["p99_interval_ms"],
                "host_available_kib": host_row and host_row["available_kib"],
                "host_swap_used_kib": host_row and host_row["swap_used_kib"],
                "emulator_cpu_percent": emulator_row and emulator_row["emulator_cpu_percent"],
                "emulator_rss_kib": emulator_row and emulator_row["emulator_rss_kib"],
                "severe_count": frame["severe_count"],
            })

        severe = [row for row in joined if (row["p99_interval_ms"] or 0) >= 100]
        ordinary = [row for row in joined if row not in severe]

        def values(rows_: list[dict[str, Any]], key: str) -> list[float]:
            return [float(row[key]) for row in rows_ if row.get(key) is not None]

        dispatch_latencies = [
            (int(row["dispatched_monotonic_ns"]) - int(row["enqueued_monotonic_ns"])) / 1_000_000
            for row in inputs
            if row["dispatched_monotonic_ns"] is not None
        ]
        rpc_latencies = [
            (int(row["rpc_completed_monotonic_ns"]) - int(row["enqueued_monotonic_ns"])) / 1_000_000
            for row in inputs
            if row["rpc_completed_monotonic_ns"] is not None
        ]

        # A temporal first-present join. Native clock offsets map the host input
        # timestamp into the guest clock; the result remains attribution-limited.
        clock_times = [int(row["host_t0_ns"]) for row in clock]
        present_times = [int(row["actual_present_ns"]) for row in intervals]
        temporal_response_ms: list[float] = []
        temporal_response_uncertainty_ms: list[float] = []
        mapped_inputs = 0
        for input_row in inputs:
            host_input = int(input_row["enqueued_monotonic_ns"])
            sample = nearest(clock, clock_times, host_input, 60_000_000_000)
            if sample is None:
                continue
            mapped_inputs += 1
            offset = (int(sample["offset_lower_ns"]) + int(sample["offset_upper_ns"])) / 2
            guest_input = host_input + offset
            index = bisect_left(present_times, guest_input)
            if index >= len(present_times):
                continue
            latency_ns = present_times[index] - guest_input
            if 0 <= latency_ns <= 500_000_000:
                temporal_response_ms.append(latency_ns / 1_000_000)
                temporal_response_uncertainty_ms.append(int(sample["uncertainty_ns"]) / 1_000_000)

        if normalized_markers:
            marker_rows = [
                {
                    "monotonic_ns": row["monotonic_ns"],
                    "kind": row["kind"],
                    "game_run_id": row["game_run_id"],
                    "source": row["source"],
                    "confidence": row["confidence"],
                    "clock_domain": row["clock_domain"],
                }
                for row in normalized_markers if row["kind"] in MARKER_KINDS
            ]
        else:
            marker_rows = [
                {"monotonic_ns": row["monotonic_ns"], "kind": row["kind"], "payload": row["payload_json"]}
                for row in events if row["kind"] in MARKER_KINDS
            ]
        automatic_marker_rows = [row for row in marker_rows if row["kind"] in AUTOMATIC_MARKER_KINDS]
        manual_marker_rows = [row for row in marker_rows if row["kind"] not in AUTOMATIC_MARKER_KINDS]
        phase_ranges: list[dict[str, Any]] = []
        for index, marker in enumerate(marker_rows):
            if index + 1 < len(marker_rows):
                next_marker = marker_rows[index + 1]
                phase_ranges.append({
                    "phase": marker["kind"],
                    "started_monotonic_ns": marker["monotonic_ns"],
                    "ended_monotonic_ns": next_marker["monotonic_ns"],
                    "duration_ms": (next_marker["monotonic_ns"] - marker["monotonic_ns"]) / 1_000_000,
                    "next_marker": next_marker["kind"],
                })

        table_counts = {
            table: connection.execute(f"SELECT count(*) FROM [{table}]").fetchone()[0]
            for table in TABLES if table in available_tables
        }
        audio_underrun_samples = sum(
            1 for row in audio if (row["partial_underruns"] or 0) + (row["empty_underruns"] or 0) > 0
        )
        correlations = {
            "p99_vs_swap": correlation(joined, "host_swap_used_kib", "p99_interval_ms"),
            "p99_vs_available": correlation(joined, "host_available_kib", "p99_interval_ms"),
            "p99_vs_cpu": correlation(joined, "emulator_cpu_percent", "p99_interval_ms"),
            "p99_vs_rss": correlation(joined, "emulator_rss_kib", "p99_interval_ms"),
        }
        decision = findings[-1]["state"] if findings else "UNKNOWN_OWNER"
        decision_unknowns: list[str] = []
        if manifest_verification["status"] != "VALIDATED":
            decision_unknowns.append("CAPTURE_MANIFEST_MISSING_OR_INVALID")
            if decision in {"ROOT_NAMED", "ROOT_CANDIDATE"}:
                decision = "UNKNOWN_OWNER"
        if manifest_verification["status"] == "VALIDATED" and not findings and len(severe) >= 3:
            resource_rs = [abs(correlations[key]["r"] or 0) for key in correlations]
            if max(resource_rs, default=0) >= 0.7:
                decision = "RESOURCE_CORRELATION_CANDIDATE_REQUIRES_CONTROLLED_TEST"

        return {
            "capture": str(database),
            "integrity": integrity,
            "session": session,
            "table_counts": table_counts,
            "frame_windows": {
                "total": len(frame_windows),
                "available": len(available_windows),
                "unavailable": len(frame_windows) - len(available_windows),
                "unavailable_reasons": {
                    reason: sum(1 for row in frame_windows if row["unavailable_reason"] == reason)
                    for reason in sorted({row["unavailable_reason"] for row in frame_windows if row["unavailable_reason"]})
                },
            },
            "frame_metrics": {
                "fps": percentiles(row["effective_fps"] for row in available_windows),
                "one_percent_low_fps": percentiles(row["one_percent_low_fps"] for row in available_windows),
                "p99_interval_ms": percentiles(row["p99_interval_ms"] for row in available_windows),
                "jank": percentiles(row["jank_count"] for row in available_windows),
                "severe": percentiles(row["severe_count"] for row in available_windows),
                "missed_vsync": percentiles(row["missed_vsync_equivalents"] for row in available_windows),
            },
            "resource_metrics": {
                "host_available_kib": percentiles(row["available_kib"] for row in host),
                "host_swap_used_kib": percentiles(row["swap_used_kib"] for row in host),
                "emulator_cpu_percent": percentiles(row["emulator_cpu_percent"] for row in emulator),
                "emulator_rss_kib": percentiles(row["emulator_rss_kib"] for row in emulator),
                "guest_available_kib": percentiles(row["available_kib"] for row in guest),
            },
            "input_metrics": {
                "count": len(inputs),
                "dispatch_ms": percentiles(dispatch_latencies),
                "rpc_ms": percentiles(rpc_latencies),
                "clock_mapped": mapped_inputs,
                "first_present_after_input_ms": percentiles(temporal_response_ms),
                "clock_uncertainty_ms": percentiles(temporal_response_uncertainty_ms),
                "attribution": "TEMPORAL_FIRST_PRESENT_ONLY",
            },
            "audio_metrics": {
                "samples": len(audio),
                "underrun_samples": audio_underrun_samples,
                "inactive_output_samples": sum(1 for row in audio if not row["active_output"]),
            },
            "joined_window_analysis": {
                "joined": len(joined),
                "p99_ge_100ms": len(severe),
                "p99_lt_100ms": len(ordinary),
                "p99_ge_100ms_host_available_kib": percentiles(row["host_available_kib"] for row in severe),
                "p99_lt_100ms_host_available_kib": percentiles(row["host_available_kib"] for row in ordinary),
                "p99_ge_100ms_swap_used_kib": percentiles(row["host_swap_used_kib"] for row in severe),
                "p99_lt_100ms_swap_used_kib": percentiles(row["host_swap_used_kib"] for row in ordinary),
                "correlations": correlations,
            },
            "markers": {
                "count": len(marker_rows),
                "automatic_capture_markers": len(automatic_marker_rows),
                "manual_annotation_markers": len(manual_marker_rows),
                "manual_annotations_optional": True,
                "rows": marker_rows,
                "phase_ranges": phase_ranges,
                "missing_semantic_markers": not marker_rows,
                "missing_manual_annotations": not manual_marker_rows,
            },
            "coverage": {
                "automatic_full_session_run_count": sum(
                    1 for run in game_runs if run.get("run_scope") in {"ONE_MATCH_PER_LAUNCH", "AUTOMATIC_FULL_SESSION"}
                ),
                "one_match_per_launch_run_count": sum(
                    1 for run in game_runs if run.get("run_scope") == "ONE_MATCH_PER_LAUNCH"
                ),
                "game_run_count": len(game_runs),
                "game_process_session_count": len(process_sessions),
                "game_runs": game_runs,
                "game_process_sessions": process_sessions,
            },
            "pipeline": {
                "experiment_runs": table_counts.get("pipeline_experiment_runs", 0),
                "lineage_rows": table_counts.get("pipeline_lineage", 0),
                "finding_rows": table_counts.get("pipeline_findings", 0),
                "native_clock_rows": table_counts.get("native_clock_samples", 0),
                "legacy_clock_sync_rows": table_counts.get("clock_sync_samples", 0),
                "graphics_incidents": len(incidents),
                "incident_owners": sorted({row["causal_owner"] for row in incidents}),
                "findings": findings,
                "truth_matrix": truth_matrix,
                "source_sites": source_sites,
                "producer_health": producer_health,
                "capture_manifest": manifests[-1] if manifests else None,
                "manifest_verification": manifest_verification,
                "segment_count": table_counts.get("pipeline_event_segments", 0),
                "event_count": table_counts.get("pipeline_events", 0),
                "stage_span_count": table_counts.get("pipeline_stage_spans", 0),
                "lineage_coverage": (
                    (sum(1 for row in rows(connection, "SELECT unambiguous FROM pipeline_lineage WHERE session_id = ?", (session["session_id"],)) if row["unambiguous"])
                     / max(1, len(rows(connection, "SELECT 1 FROM game_frame_intervals WHERE session_id = ?", (session["session_id"],)))))
                    if "pipeline_lineage" in available_tables else 0.0
                ),
            },
            "decision": decision,
            "decision_unknowns": decision_unknowns,
        }
    finally:
        connection.close()


def markdown(report: dict[str, Any]) -> str:
    output = [
        "# TFTDEV Flight-Recorder Analysis",
        "",
        f"Generated: `{report['generated_utc']}`",
        "",
        "This report is read-only analysis of sealed captures. Temporal joins are not causal ownership proof.",
        "",
    ]
    for capture in report["captures"]:
        session = capture["session"]
        frame = capture["frame_metrics"]
        resource = capture["resource_metrics"]
        joined = capture["joined_window_analysis"]
        inputs = capture["input_metrics"]
        audio = capture["audio_metrics"]
        output += [
            f"## {session['session_id']}",
            "",
            f"- Capture: `{capture['capture']}`",
            f"- Session: `{session['started_utc']} → {session.get('ended_utc')}`; status `{session['status']}`",
            f"- Frame windows: {capture['frame_windows']['available']} available / {capture['frame_windows']['total']} total",
            f"- Average FPS: `{frame['fps']['avg']}`; average 1%-low: `{frame['one_percent_low_fps']['avg']}`; maximum p99 interval: `{frame['p99_interval_ms']['max']} ms`",
            f"- Host minimum available: `{resource['host_available_kib']['min']} KiB`; maximum swap: `{resource['host_swap_used_kib']['max']} KiB`",
            f"- Emulator CPU average/max: `{resource['emulator_cpu_percent']['avg']}% / {resource['emulator_cpu_percent']['max']}%`",
            f"- Inputs: `{inputs['count']}`; dispatch p95 `{inputs['dispatch_ms']['p95']} ms`; temporal first-present join `{inputs['first_present_after_input_ms']}`",
            f"- Audio underrun samples: `{audio['underrun_samples']}`",
            f"- p99 ≥100 ms windows: `{joined['p99_ge_100ms']}`; correlations: `{joined['correlations']}`",
            f"- One-match-per-launch runs: `{capture['coverage']['one_match_per_launch_run_count']}`; process sessions: `{capture['coverage']['game_process_session_count']}`",
            f"- Markers: `{capture['markers']['count']}` (`{capture['markers']['manual_annotation_markers']}` optional manual annotations); pipeline segments/events/lineage: `{capture['pipeline']['segment_count']}`/`{capture['pipeline']['event_count']}`/`{capture['pipeline']['lineage_rows']}`",
            f"- Producer health: `{[(row['producer_name'], row['status']) for row in capture['pipeline']['producer_health']]}`",
            f"- Pipeline truth boundaries: `{len(capture['pipeline']['truth_matrix'])}`; lineage coverage: `{capture['pipeline']['lineage_coverage']:.4f}`; root outcome: **{capture['decision']}**",
            f"- Source-site manifest rows: `{len(capture['pipeline']['source_sites'])}`",
            f"- Manifest verification: `{capture['pipeline']['manifest_verification']['status']}`; decision unknowns: `{capture['decision_unknowns']}`",
            "",
        ]
    return "\n".join(output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("captures", nargs="+", type=Path, help="capture directory or TFTMAC_NATIVE_RUNTIME.sqlite")
    parser.add_argument("--format", choices=("json", "markdown"), default="json")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        captures = [analyze_capture(resolve_database(path)) for path in args.captures]
        report = {"generated_utc": utc_now(), "captures": captures}
        rendered = json.dumps(report, indent=2, sort_keys=True) if args.format == "json" else markdown(report)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(rendered + "\n", encoding="utf-8")
        else:
            print(rendered)
        return 0
    except (OSError, sqlite3.Error, ValueError) as error:
        print(f"flight-recorder analysis failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
