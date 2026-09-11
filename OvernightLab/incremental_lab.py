#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import sqlite3
import statistics
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

import overnight_lab as base

ROOT = Path(__file__).resolve().parent
MANIFEST_PATH = ROOT / "manifests" / "incremental-candidates.json"
STATE_NAME = "incremental-state.json"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def parse_utc(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("UTC deadline must include a timezone")
    return parsed.astimezone(timezone.utc)


def deadline_reached(state: dict[str, Any], *, now: Optional[datetime] = None) -> bool:
    if "deadline_utc" not in state:
        raise base.LabError(
            "campaign checkpoint is missing durable deadline_utc",
            error_class="CAMPAIGN_DEADLINE_MIGRATION_REQUIRED", component="campaign", phase="resume")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    return current >= parse_utc(str(state["deadline_utc"]))


class IncrementalLab(base.OvernightLab):
    def __init__(self):
        super().__init__()
        self.incremental_manifest = base.read_json(MANIFEST_PATH)
        self.installed_profile = self.dev_app / "Contents/Resources/DEVHighPerf/DeviceProfiles.ini"
        self.installed_profile_sha = base.sha256_file(self.installed_profile)
        expected = self.authority["current_dev_hashes"]["Contents/Resources/DEVHighPerf/DeviceProfiles.ini"]
        if self.installed_profile_sha != expected:
            raise base.LabError(
                f"installed DEV profile is not current authority: {self.installed_profile_sha} != {expected}",
                error_class="PROFILE_BASELINE_MISMATCH", component="profile", phase="preflight")

    def candidate_definition(self, spec: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": spec["id"],
            "family": spec["family"],
            "kind": "profile_cvar",
            "build_scope": "NO_BUILD",
            "restart_class": "TFT_PROCESS_COLD",
            "enabled": True,
            "baseline": self.authority["working_version"],
            "target_stages": list(self.incremental_manifest["target_stages"]),
            "maximum_seconds": int(self.incremental_manifest["maximum_seconds_per_run"]),
            "cvar": spec["cvar"],
            "from": str(spec["from"]),
            "to": str(spec["to"]),
            "reason": spec["reason"],
            "expected_rhi": self.authority["expected_normal_rhi"],
            "decision_requires": ["native_combat_windows", "native_capture"],
        }

    def ensure_incremental_candidates(self) -> None:
        for spec in self.incremental_manifest["candidates"]:
            c = self.candidate_definition(spec)
            definition = canonical_json(c)
            self.db.execute(
                "INSERT OR REPLACE INTO candidates(candidate_id,family,kind,build_scope,restart_class,definition_json,definition_sha256,enabled) VALUES(?,?,?,?,?,?,?,1)",
                (c["id"], c["family"], c["kind"], c["build_scope"], c["restart_class"], definition, base.sha256_bytes(definition.encode())))

    def state_path(self, cid: str) -> Path:
        return self.campaign_dir(cid) / STATE_NAME

    def read_state(self, cid: str) -> dict[str, Any]:
        return base.read_json(self.state_path(cid))

    def write_state(self, cid: str, state: dict[str, Any]) -> None:
        state = dict(state)
        state["updated_utc"] = utc_now()
        base.atomic_json(self.state_path(cid), state)

    def create_incremental_campaign(self, deadline_seconds: int) -> str:
        self.verify_static_authority()
        self.ensure_incremental_candidates()
        started = datetime.now(timezone.utc).replace(microsecond=0)
        started_utc = started.isoformat().replace("+00:00", "Z")
        deadline_utc = (started + timedelta(seconds=deadline_seconds)).isoformat().replace("+00:00", "Z")
        cid = "incremental-" + started.strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
        cdir = self.campaign_dir(cid)
        cdir.mkdir(parents=True, exist_ok=False)
        working = cdir / "working-profile.ini"
        shutil.copy2(self.installed_profile, working)
        self.db.execute(
            "INSERT INTO campaigns(campaign_id,started_utc,state,authority_sha256,candidate_manifest_sha256,lkg_integrity_passed,pbe_evidence_admitted) VALUES(?,?,?,?,?,1,0)",
            (cid, started_utc, "RUNNING", base.sha256_file(base.AUTHORITY_PATH), base.sha256_file(MANIFEST_PATH)))
        base.ACTIVE_PATH.write_text(cid + "\n", encoding="utf-8")
        self.write_checkpoint(cid, queue_index=0, state="RUNNING", phase="INCREMENTAL_CAMPAIGN_START", current_candidate=None, current_run=None, failure=None)
        self.write_state(cid, {
            "schema": 1,
            "campaign": "TFTMAC_INCREMENTAL_SMALL_GAINS_V1",
            "campaign_id": cid,
            "started_utc": started_utc,
            "duration_seconds": int(deadline_seconds),
            "deadline_utc": deadline_utc,
            "base_working_version": self.authority["working_version"],
            "installed_profile_sha256": self.installed_profile_sha,
            "working_profile_path": str(working),
            "working_profile_sha256": base.sha256_file(working),
            "accepted": [],
            "results": [],
            "stability_runs": [],
            "queue_index": 0,
            "rollback_verified": True,
        })
        return cid

    def profile_occurrences(self, text: str, cvar: str) -> list[tuple[int, str, str]]:
        section = ""
        found: list[tuple[int, str, str]] = []
        for i, raw in enumerate(text.splitlines()):
            line = raw.strip()
            if line.startswith("[") and line.endswith("]"):
                section = line
            elif line.startswith("CVars="):
                key, sep, value = line[6:].partition("=")
                if sep and key == cvar:
                    found.append((i, section, value))
        return found

    def build_profile_candidate(self, base_profile: Path, spec: dict[str, Any], out: Path) -> dict[str, Any]:
        text = base_profile.read_text(encoding="utf-8")
        occurrences = self.profile_occurrences(text, spec["cvar"])
        if not occurrences:
            raise base.LabError(f"candidate CVar is not present: {spec['cvar']}", error_class="CANDIDATE_CONFIG_MISSING", component="profile", phase="candidate_apply")
        observed = sorted({value for _, _, value in occurrences})
        if observed != [str(spec["from"])]:
            raise base.LabError(
                f"candidate baseline mismatch for {spec['cvar']}: observed={observed} expected={spec['from']}",
                error_class="CANDIDATE_CONFIG_CONTAMINATED", component="profile", phase="candidate_apply")
        lines = text.splitlines()
        changed = []
        for i, section, value in occurrences:
            lines[i] = f"CVars={spec['cvar']}={spec['to']}"
            changed.append({"line": i + 1, "section": section, "cvar": spec["cvar"], "from": value, "to": str(spec["to"])})
        out.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""), encoding="utf-8")
        # Semantic guard: every non-target line must remain byte-identical.
        candidate_lines = out.read_text(encoding="utf-8").splitlines()
        if len(candidate_lines) != len(text.splitlines()):
            raise base.LabError("profile line count changed", error_class="CANDIDATE_CONFIG_CONTAMINATED", component="profile", phase="candidate_apply")
        target_lines = {item["line"] - 1 for item in changed}
        for i, (a, b) in enumerate(zip(text.splitlines(), candidate_lines)):
            if i not in target_lines and a != b:
                raise base.LabError(f"unapproved profile drift at line {i+1}", error_class="CANDIDATE_CONFIG_CONTAMINATED", component="profile", phase="candidate_apply")
        return {"changes": changed, "base_sha256": base.sha256_file(base_profile), "candidate_sha256": base.sha256_file(out)}

    def zygote64_pids(self) -> list[str]:
        raw = self.adb("shell", "pidof", "zygote64", timeout=10).stdout.strip()
        pids = raw.split()
        if not pids or any(not pid.isdigit() for pid in pids):
            raise base.LabError(
                f"invalid zygote64 process set: {raw!r}",
                error_class="PROFILE_OVERLAY_FAILED", component="profile", phase="candidate_apply")
        return pids

    def verify_profile_views(self, expected_sha: str, *, phase: str) -> None:
        target = self.authority["device_profile_target"]
        original_stage = self.authority["highperf_stage_profile"]
        stage_sha = self.adb("shell", "sha256sum", original_stage, timeout=10).stdout.split()[0]
        target_sha = self.adb("shell", "sha256sum", target, timeout=10).stdout.split()[0]
        if stage_sha != expected_sha or target_sha != expected_sha:
            raise base.LabError(
                f"profile view mismatch during {phase}: stage={stage_sha} target={target_sha} expected={expected_sha}",
                error_class="PROFILE_OVERLAY_FAILED", component="profile", phase=phase)
        for pid in self.zygote64_pids():
            visible = self.adb(
                "shell", "nsenter", "-t", pid, "-m", "--", "sha256sum", target, timeout=10
            ).stdout.split()[0]
            if visible != expected_sha:
                raise base.LabError(
                    f"zygote profile view mismatch during {phase}: pid={pid} observed={visible} expected={expected_sha}",
                    error_class="PROFILE_OVERLAY_FAILED", component="profile", phase=phase)

    def apply_profile_overlay(self, ctx: base.RunContext, profile: Path) -> None:
        target = self.authority["device_profile_target"]
        original_stage = self.authority["highperf_stage_profile"]
        expected = self.installed_profile_sha
        wanted = base.sha256_file(profile)
        stage = f"/data/local/tmp/tftmac-incremental-{ctx.run_id[-12:]}"
        candidate_remote = stage + "/candidate.ini"
        baseline_remote = stage + "/baseline.ini"
        self.adb("shell", "am", "force-stop", self.package, timeout=15)
        self.adb_root()
        try:
            if self.adb("shell", "pidof", self.package, timeout=5, check=False).stdout.strip():
                raise base.LabError("TFT process remained alive before candidate profile mutation", error_class="PROFILE_OVERLAY_FAILED", component="profile", phase="candidate_apply")
            self.verify_profile_views(expected, phase="candidate_apply")
            before_inode = self.adb("shell", "stat", "-c", "%i", original_stage, timeout=10).stdout.strip()
            before_meta = self.adb("shell", "stat", "-c", "%u:%g %a", original_stage, timeout=10).stdout.strip()
            before_context = self.adb("shell", "ls", "-Zd", original_stage, timeout=10).stdout.split()[0]
            self.adb("shell", "mkdir", "-p", stage)
            self.adb("push", str(profile), candidate_remote, timeout=20)
            self.adb("push", str(self.installed_profile), baseline_remote, timeout=20)
            if self.adb("shell", "sha256sum", candidate_remote, timeout=10).stdout.split()[0] != wanted:
                raise base.LabError("candidate staging hash mismatch", error_class="PROFILE_OVERLAY_FAILED", component="profile", phase="candidate_apply")
            if self.adb("shell", "sha256sum", baseline_remote, timeout=10).stdout.split()[0] != expected:
                raise base.LabError("baseline staging hash mismatch", error_class="PROFILE_OVERLAY_FAILED", component="profile", phase="candidate_apply")
            # The native HighPerf stage inode is already bind-mounted into zygote's namespace.
            # Mutate only its bytes while TFT is stopped so every inherited mount sees the
            # candidate without unmounting/remounting or changing the protected LKG source.
            ctx.profile_overlay_applied = True
            self.adb("shell", "sh", "-c", f"cat {candidate_remote} > {original_stage} && sync", timeout=15)
            after_inode = self.adb("shell", "stat", "-c", "%i", original_stage, timeout=10).stdout.strip()
            after_meta = self.adb("shell", "stat", "-c", "%u:%g %a", original_stage, timeout=10).stdout.strip()
            after_context = self.adb("shell", "ls", "-Zd", original_stage, timeout=10).stdout.split()[0]
            if (after_inode, after_meta, after_context) != (before_inode, before_meta, before_context):
                raise base.LabError("candidate stage inode or metadata changed", error_class="PROFILE_OVERLAY_FAILED", component="profile", phase="candidate_apply")
            self.verify_profile_views(wanted, phase="candidate_apply")
        finally:
            self.adb_unroot()
        self.adb("shell", "am", "start", "-n", f"{self.package}/{self.game_activity}", timeout=20)

    def restore_profile_overlay(self, ctx: base.RunContext) -> bool:
        if not ctx.profile_overlay_applied:
            return True
        original_stage = self.authority["highperf_stage_profile"]
        stage = f"/data/local/tmp/tftmac-incremental-{ctx.run_id[-12:]}"
        baseline_remote = stage + "/baseline.ini"
        try:
            self.adb("shell", "am", "force-stop", self.package, timeout=10, check=False)
            self.adb_root()
            try:
                if self.adb("shell", "pidof", self.package, timeout=5, check=False).stdout.strip():
                    raise base.LabError("TFT process remained alive before profile restoration", error_class="ROLLBACK_FAILURE", component="profile", phase="rollback")
                before_inode = self.adb("shell", "stat", "-c", "%i", original_stage, timeout=10).stdout.strip()
                before_meta = self.adb("shell", "stat", "-c", "%u:%g %a", original_stage, timeout=10).stdout.strip()
                before_context = self.adb("shell", "ls", "-Zd", original_stage, timeout=10).stdout.split()[0]
                baseline_sha = self.adb("shell", "sha256sum", baseline_remote, timeout=10).stdout.split()[0]
                if baseline_sha != self.installed_profile_sha:
                    raise base.LabError("rollback baseline staging hash mismatch", error_class="ROLLBACK_FAILURE", component="profile", phase="rollback")
                self.adb("shell", "sh", "-c", f"cat {baseline_remote} > {original_stage} && sync", timeout=15)
                after_inode = self.adb("shell", "stat", "-c", "%i", original_stage, timeout=10).stdout.strip()
                after_meta = self.adb("shell", "stat", "-c", "%u:%g %a", original_stage, timeout=10).stdout.strip()
                after_context = self.adb("shell", "ls", "-Zd", original_stage, timeout=10).stdout.split()[0]
                if (after_inode, after_meta, after_context) != (before_inode, before_meta, before_context):
                    raise base.LabError("rollback stage inode or metadata changed", error_class="ROLLBACK_FAILURE", component="profile", phase="rollback")
                self.verify_profile_views(self.installed_profile_sha, phase="rollback")
                ok = True
            finally:
                self.adb_unroot()
            ctx.profile_overlay_applied = False
            return ok
        except Exception:
            try:
                self.adb_unroot()
            except Exception:
                pass
            return False

    def wait_profile_value(self, ctx: base.RunContext, cvar: str, expected: str, timeout: int = 45) -> bool:
        rx = re.compile(rf"Pushing Device Profile CVar: \[\[{re.escape(cvar)}:.*? -> {re.escape(expected)}\]\]")
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if ctx.capture:
                for path in list(ctx.capture.glob("*engine*.log")) + list(ctx.capture.glob("*logcat*.txt")) + list(ctx.capture.glob("*.log")):
                    if rx.search(base.safe_text(path)):
                        return True
            if not self.dev_core_running() or not self.owned_emulator_pids():
                break
            time.sleep(1)
        return False

    def register_run_candidate(self, spec: dict[str, Any], role: str, base_profile: Path, profile: Path) -> dict[str, Any]:
        c = self.candidate_definition(spec)
        c = dict(c)
        c["id"] = f"{spec['id']}--{role}"
        c["family"] = spec["family"]
        c["profile_role"] = role
        c["profile_sha256"] = base.sha256_file(profile)
        definition = canonical_json(c)
        self.db.execute(
            "INSERT OR REPLACE INTO candidates(candidate_id,family,kind,build_scope,restart_class,definition_json,definition_sha256,enabled) VALUES(?,?,?,?,?,?,?,1)",
            (c["id"], c["family"], c["kind"], c["build_scope"], c["restart_class"], definition, base.sha256_bytes(definition.encode())))
        return c

    def wait_native_tft_ready(self, ctx: base.RunContext, timeout: int = 180) -> None:
        if not ctx.capture:
            raise base.LabError("native capture is unavailable while waiting for LKG readiness", error_class="CAPTURE_FAILURE", component="runtime", phase="identity")
        events = ctx.capture / "native-events.jsonl"
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            text = base.safe_text(events)
            if '"kind":"RUNTIME_FAILED"' in text:
                raise base.LabError("native DEV reported runtime failure before LKG readiness", error_class="NATIVE_RUNTIME_FAILED", component="runtime", phase="identity")
            if ('"kind":"DEV_PRIVATE_HIGHPERF_MOUNT_VERIFIED"' in text and
                    '"kind":"DEV_HIGHPERF_ENGINE_TARGETS_ACCEPTED"' in text and
                    '"kind":"TFT_READY_FOR_USER"' in text):
                return
            if not self.dev_core_running() or not self.owned_emulator_pids():
                raise base.LabError("DEV stopped before verified LKG readiness", error_class="BOOT_FAILURE", component="runtime", phase="identity")
            time.sleep(0.5)
        raise base.LabError("verified LKG readiness timed out", error_class="LKG_READY_TIMEOUT", component="runtime", phase="identity")

    def run_profile(self, cid: str, spec: dict[str, Any], role: str, profile: Path, expected_cvar_value: Optional[str]) -> tuple[str, str]:
        c = self.register_run_candidate(spec, role, profile, profile)
        ctx = self.new_run(cid, c)
        navigation = None
        error: Optional[BaseException] = None
        restore_profile = True
        rollback: dict[str, Any] = {}
        try:
            self.verify_static_authority()
            self.launch_dev(ctx)
            self.wait_for_device(ctx)
            self.apply_session_properties_before_tft(ctx)
            self.wait_for_shell_and_package(ctx)
            # Native DEV may briefly launch TFT to create its private config tree before
            # installing the verified LKG profile. Never treat that bootstrap PID as the
            # measured workload. Wait for the native owner to prove the unchanged LKG is
            # mounted, consumed by Unreal, and ready for the user before control
            # measurement or a one-factor candidate overlay begins.
            self.wait_native_tft_ready(ctx)
            if base.sha256_file(profile) != self.installed_profile_sha:
                self.apply_profile_overlay(ctx, profile)
            deadline = time.monotonic() + 120
            while time.monotonic() < deadline:
                pid = self.adb("shell", "pidof", self.package, check=False).stdout.strip()
                if pid:
                    break
                time.sleep(1)
            self.verify_runtime(ctx)
            if expected_cvar_value is not None:
                if not self.wait_profile_value(ctx, spec["cvar"], expected_cvar_value):
                    raise base.LabError(
                        f"engine log did not prove effective CVar {spec['cvar']}={expected_cvar_value}",
                        error_class="CVAR_NOT_EFFECTIVE", component="profile", phase="identity")
                self.upsert_variable(ctx, "device_profile_candidate", spec["cvar"], spec["from"], expected_cvar_value, expected_cvar_value, "engine log Pushing Device Profile CVar", "VERIFIED")
            navigation = self.navigate_tocker(ctx)
        except BaseException as exc:
            error = exc
            self.failure(ctx, exc, getattr(exc, "phase", "run"))
        finally:
            if ctx.profile_overlay_applied:
                restore_profile = self.restore_profile_overlay(ctx)
            self.request_dev_quit()
            try:
                self.import_native_capture(ctx)
            except Exception:
                pass
            rollback = self.wait_cleanup(ctx)
            rollback["profile_restored"] = restore_profile
            rollback["cache_properties_restored"] = True
            rollback["angle_restored"] = True
            rollback["verified"] = bool(rollback.get("verified") and restore_profile)
            self.db.execute(
                "INSERT INTO rollbacks(run_id,observed_utc,dev_core_stopped,emulator_stopped,angle_restored,profile_restored,cache_properties_restored,installed_app_integrity,lkg_integrity,verified,detail_json) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                (ctx.run_id, utc_now(), int(rollback.get("dev_core_stopped", False)), int(rollback.get("emulator_stopped", False)), 1,
                 int(restore_profile), 1, int(rollback.get("installed_app_integrity", False)), int(rollback.get("lkg_integrity", False)),
                 int(rollback["verified"]), canonical_json(rollback)))
        perf = self.db.rows("SELECT weighted_fps FROM performance_windows WHERE run_id=? AND semantic_gate_passed=1", (ctx.run_id,))
        classification = "CONTROL_VALID" if role.startswith("control") and perf and error is None and rollback.get("verified") else (
            "MECHANISM_WORKING" if perf and error is None and rollback.get("verified") else "INCONCLUSIVE")
        if not ctx.decision_admissible:
            classification = "DATA_ONLY_NONCOMPARABLE"
        if not rollback.get("verified"):
            classification = "INCONCLUSIVE"
            if error is None:
                error = base.LabError("rollback could not be proven", error_class="ROLLBACK_FAILURE", phase="rollback")
                self.failure(ctx, error, "rollback")
        result = {
            "candidate": spec["id"], "role": role, "classification": classification, "navigation": navigation,
            "error": base.normalize_error(str(error)) if error else None, "rollback": rollback,
            "profile_sha256": base.sha256_file(profile), "working_profile_sha256": base.sha256_file(profile),
            "selected_game_rhi": ctx.selected_rhi, "decision_admissible": ctx.decision_admissible,
        }
        base.atomic_json(ctx.run_dir / "result.json", result)
        self.db.execute(
            "UPDATE runs SET ended_utc=?,state='COMPLETE',classification=?,rollback_verified=?,selected_game_rhi=?,raw_native_classifier_value=?,result_json=? WHERE run_id=?",
            (utc_now(), classification, int(rollback.get("verified", False)), ctx.selected_rhi, ctx.raw_native_rhi, canonical_json(result), ctx.run_id))
        self.db.execute(
            "INSERT INTO decisions(decision_id,campaign_id,candidate_id,run_id,created_utc,classification,reason,evidence_json) VALUES(?,?,?,?,?,?,?,?)",
            (str(uuid.uuid4()), cid, c["id"], ctx.run_id, utc_now(), classification, base.normalize_error(str(error)) if error else role, canonical_json(result)))
        return ctx.run_id, classification

    def metrics(self, run_id: str) -> dict[str, float]:
        rows = self.db.rows(
            "SELECT frame_count,weighted_fps,one_percent_low_fps,p95_ms,p99_ms,over_25ms,over_50ms FROM performance_windows WHERE run_id=? AND semantic_gate_passed=1",
            (run_id,))
        if not rows:
            return {}
        total_frames = sum(int(r["frame_count"] or 0) for r in rows)
        return {
            "fps": statistics.fmean(float(r["weighted_fps"]) for r in rows),
            "low1": statistics.fmean(float(r["one_percent_low_fps"] or 0) for r in rows),
            "p95": statistics.fmean(float(r["p95_ms"] or 0) for r in rows),
            "p99": statistics.fmean(float(r["p99_ms"] or 0) for r in rows),
            "jank_rate": sum(int(r["over_25ms"] or 0) for r in rows) / max(1, total_frames),
            "severe_rate": sum(int(r["over_50ms"] or 0) for r in rows) / max(1, total_frames),
            "windows": float(len(rows)),
        }

    @staticmethod
    def pct(candidate: float, control: float) -> float:
        if control == 0:
            return 0.0 if candidate == 0 else math.inf
        return (candidate - control) / control * 100.0

    def compare(self, control_id: str, candidate_id: str) -> dict[str, Any]:
        control = self.metrics(control_id)
        candidate = self.metrics(candidate_id)
        if not control or not candidate:
            return {"decision": "INCONCLUSIVE", "reason": "missing matched performance windows", "control": control, "candidate": candidate}
        delta = {
            "weighted_fps_percent": self.pct(candidate["fps"], control["fps"]),
            "one_percent_low_fps_percent": self.pct(candidate["low1"], control["low1"]),
            "p95_interval_percent": self.pct(candidate["p95"], control["p95"]),
            "p99_interval_percent": self.pct(candidate["p99"], control["p99"]),
            "jank_rate_delta": candidate["jank_rate"] - control["jank_rate"],
            "severe_rate_delta": candidate["severe_rate"] - control["severe_rate"],
        }
        veto = (
            delta["weighted_fps_percent"] <= -5.0 or
            delta["one_percent_low_fps_percent"] <= -10.0 or
            delta["p95_interval_percent"] >= 10.0 or
            delta["p99_interval_percent"] >= 10.0
        )
        directional = (
            delta["weighted_fps_percent"] > 0 or
            delta["one_percent_low_fps_percent"] > 0 or
            (delta["p95_interval_percent"] < 0 and delta["p99_interval_percent"] < 0) or
            delta["jank_rate_delta"] < 0 or delta["severe_rate_delta"] < 0
        )
        home = (
            delta["one_percent_low_fps_percent"] >= 20 and
            control["jank_rate"] > 0 and candidate["jank_rate"] <= control["jank_rate"] * .7 and
            control["severe_rate"] > 0 and candidate["severe_rate"] <= control["severe_rate"] * .7 and
            (delta["weighted_fps_percent"] >= 10 or delta["p95_interval_percent"] <= -15)
        )
        decision = "REJECT" if veto else ("HOME_RUN" if home else ("PROMISING" if directional else "INCONCLUSIVE"))
        return {"decision": decision, "control": control, "candidate": candidate, "delta": delta}

    def incremental_report(self, cid: str) -> Path:
        state = self.read_state(cid)
        out = self.campaign_dir(cid) / "incremental-report.md"
        lines = [
            f"# TFTMAC Incremental Sweep — {cid}", "",
            f"- Base winner: `{state['base_working_version']}`",
            f"- Working profile SHA-256: `{state['working_profile_sha256']}`",
            f"- Accepted cumulative candidates: {', '.join(x['id'] for x in state['accepted']) or 'none'}",
            f"- Stability-control runs: {len(state.get('stability_runs', []))}",
            f"- Rollback verified: `{state['rollback_verified']}`", "", "## Results", ""
        ]
        for item in state["results"]:
            lines.append(f"- `{item['candidate']}`: initial={item.get('initial_decision')}, confirmation={item.get('confirmation_decision')}, kept={item.get('kept')}, control={item.get('control_run')}, candidateRun={item.get('candidate_run')}")
        if state.get("stability_runs"):
            lines.extend(["", "## Stability controls", ""])
            for item in state["stability_runs"]:
                m = item.get("metrics", {})
                lines.append(f"- `{item['run_id']}`: classification={item['classification']}, profile={item['profile_sha256']}, fps={m.get('fps')}, low1={m.get('low1')}, p95={m.get('p95')}, p99={m.get('p99')}, rollback={item.get('rollback_verified')}")
        out.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return out

    @staticmethod
    def stability_spec() -> dict[str, Any]:
        return {
            "id": "stability-control",
            "family": "campaign_stability",
            "cvar": "",
            "from": "",
            "to": "",
            "reason": "Queue-exhaustion stability control using the current working profile without changing any CVar.",
        }

    def run_incremental_campaign(self, duration_seconds: int, resume: bool, impact_only: bool = False) -> str:
        if base.LOCK_PATH.exists():
            try:
                owner = int(base.LOCK_PATH.read_text().strip()); os.kill(owner, 0)
                raise base.LabError(f"campaign already running under pid {owner}", error_class="CAMPAIGN_LOCKED", phase="campaign")
            except (ValueError, ProcessLookupError):
                base.LOCK_PATH.unlink(missing_ok=True)
        base.LOCK_PATH.write_text(str(os.getpid()) + "\n", encoding="utf-8")
        try:
            cid = self.current_campaign() if resume else None
            if cid and self.state_path(cid).exists():
                state = self.read_state(cid)
                if "deadline_utc" not in state:
                    raise base.LabError(
                        "existing campaign requires an evidence-backed durable deadline migration",
                        error_class="CAMPAIGN_DEADLINE_MIGRATION_REQUIRED", component="campaign", phase="resume")
                self.reconcile_resume(cid)
                state = self.read_state(cid)
                state.pop("blocked_reason", None)
                state["campaign_state"] = "RUNNING"
                last_rollback = self.db.one(
                    "SELECT rollback_verified FROM runs WHERE campaign_id=? ORDER BY started_utc DESC LIMIT 1", (cid,))
                if last_rollback is not None:
                    state["rollback_verified"] = bool(last_rollback["rollback_verified"])
                self.write_state(cid, state)
                self.db.execute("UPDATE campaigns SET state='RUNNING',ended_utc=NULL WHERE campaign_id=?", (cid,))
            else:
                cid = self.create_incremental_campaign(duration_seconds)
                state = self.read_state(cid)
            specs = list(self.incremental_manifest["candidates"])
            while state["queue_index"] < len(specs):
                if deadline_reached(state):
                    break
                spec = specs[state["queue_index"]]
                parent = spec.get("requires_parent")
                accepted_ids = {x["id"] for x in state["accepted"]}
                if parent and parent not in accepted_ids:
                    state["results"].append({"candidate": spec["id"], "initial_decision": "SKIPPED_PARENT_NOT_ACCEPTED", "kept": False})
                    state["queue_index"] += 1; self.write_state(cid, state); continue
                working = Path(state["working_profile_path"])
                candidate_profile = self.campaign_dir(cid) / f"candidate-{spec['id']}.ini"
                delta_receipt = self.build_profile_candidate(working, spec, candidate_profile)
                base.atomic_json(self.campaign_dir(cid) / f"candidate-{spec['id']}.delta.json", delta_receipt)
                # Fresh matched control then candidate.
                control_id, control_class = self.run_profile(cid, spec, "control-initial", working, str(spec["from"]) if base.sha256_file(working) != self.installed_profile_sha else None)
                control_rollback_row = self.db.one("SELECT rollback_verified FROM runs WHERE run_id=?", (control_id,))
                control_rollback_verified = bool(control_rollback_row and control_rollback_row["rollback_verified"])
                state["rollback_verified"] = control_rollback_verified
                if control_class != "CONTROL_VALID":
                    state["blocked_reason"] = {
                        "kind": "CONTROL_NOT_GREEN",
                        "run_id": control_id,
                        "classification": control_class,
                        "rollback_verified": control_rollback_verified,
                    }
                    state["results"].append({
                        "candidate": spec["id"], "initial_decision": "CONTROL_NOT_GREEN",
                        "control_run": control_id, "rollback_verified": control_rollback_verified, "kept": False})
                    self.write_state(cid, state)
                    self.incremental_report(cid)
                    break
                candidate_id, candidate_class = self.run_profile(cid, spec, "candidate-initial", candidate_profile, str(spec["to"]))
                initial = self.compare(control_id, candidate_id) if candidate_class == "MECHANISM_WORKING" else {"decision": "INCONCLUSIVE", "reason": candidate_class}
                item: dict[str, Any] = {"candidate": spec["id"], "control_run": control_id, "candidate_run": candidate_id, "initial_decision": initial["decision"], "initial_comparison": initial, "kept": False}
                if initial["decision"] in {"PROMISING", "HOME_RUN"} and not deadline_reached(state):
                    confirm_control, cc = self.run_profile(cid, spec, "control-confirm", working, str(spec["from"]) if base.sha256_file(working) != self.installed_profile_sha else None)
                    if cc != "CONTROL_VALID":
                        confirmation = {"decision": "INCONCLUSIVE", "reason": f"confirmation control={cc}"}
                        confirm_candidate, kc = None, "SKIPPED_CONTROL_NOT_GREEN"
                    else:
                        confirm_candidate, kc = self.run_profile(cid, spec, "candidate-confirm", candidate_profile, str(spec["to"]))
                        confirmation = self.compare(confirm_control, confirm_candidate) if kc == "MECHANISM_WORKING" else {"decision": "INCONCLUSIVE", "reason": f"candidate={kc}"}
                    item.update({"confirmation_control_run": confirm_control, "confirmation_candidate_run": confirm_candidate, "confirmation_decision": confirmation["decision"], "confirmation_comparison": confirmation})
                    if confirmation["decision"] in {"PROMISING", "HOME_RUN"}:
                        shutil.copy2(candidate_profile, working)
                        state["working_profile_sha256"] = base.sha256_file(working)
                        accepted = {"id": spec["id"], "cvar": spec["cvar"], "from": str(spec["from"]), "to": str(spec["to"]), "profile_sha256": state["working_profile_sha256"], "initial": initial, "confirmation": confirmation}
                        state["accepted"].append(accepted)
                        item["kept"] = True
                state["results"].append(item)
                state["queue_index"] += 1
                self.write_state(cid, state)
                self.incremental_report(cid)
                # Hard rollback guard: latest two runs must prove rollback before queue advance.
                latest = self.db.rows("SELECT rollback_verified FROM runs WHERE campaign_id=? ORDER BY started_utc DESC LIMIT 2", (cid,))
                if latest and any(not bool(r["rollback_verified"]) for r in latest):
                    state["rollback_verified"] = False; self.write_state(cid, state)
                    raise base.LabError("incremental campaign stopped because rollback is unproven", error_class="ROLLBACK_FAILURE", phase="campaign")

            # Queue exhausted before the four-hour deadline: accumulate stability evidence only.
            # No new tuning candidate is invented or admitted in this tail loop.
            stability = self.stability_spec()
            while (not impact_only) and state["queue_index"] >= len(specs) and not deadline_reached(state):
                working = Path(state["working_profile_path"])
                run_id, classification = self.run_profile(cid, stability, "stability-control", working, None)
                rollback_row = self.db.rows("SELECT rollback_verified FROM runs WHERE run_id=?", (run_id,))
                rollback_verified = bool(rollback_row and rollback_row[0]["rollback_verified"])
                state.setdefault("stability_runs", []).append({
                    "run_id": run_id,
                    "classification": classification,
                    "profile_sha256": base.sha256_file(working),
                    "metrics": self.metrics(run_id),
                    "rollback_verified": rollback_verified,
                })
                if not rollback_verified:
                    state["rollback_verified"] = False
                self.write_state(cid, state)
                self.incremental_report(cid)
                # Stability controls are evidence-only after the candidate queue is exhausted.
                # An inconclusive soak reduces confidence but must not abort the campaign when
                # rollback is proven; only an unproven rollback may stop future admission.
                if not rollback_verified:
                    raise base.LabError(
                        f"stability-control rollback is unproven: classification={classification}",
                        error_class="ROLLBACK_FAILURE",
                        phase="campaign")

            deadline_has_elapsed = deadline_reached(state)
            if state.get("blocked_reason"):
                end_state = "BLOCKED_INCONCLUSIVE"
            elif impact_only and state["queue_index"] >= len(specs):
                end_state = "COMPLETE"
            elif deadline_has_elapsed:
                end_state = "DEADLINE_COMPLETE"
            elif state["queue_index"] >= len(specs):
                end_state = "COMPLETE"
            else:
                end_state = "BLOCKED_INCONCLUSIVE"
            state["campaign_state"] = end_state
            self.write_state(cid, state)
            self.db.execute("UPDATE campaigns SET state=?,ended_utc=? WHERE campaign_id=?", (end_state, utc_now(), cid))
            blocked = state.get("blocked_reason")
            self.write_checkpoint(
                cid, queue_index=int(state["queue_index"]), state=end_state,
                phase="BLOCKED" if end_state == "BLOCKED_INCONCLUSIVE" else "COMPLETE",
                current_candidate=None, current_run=None,
                failure=canonical_json(blocked) if blocked else None)
            self.incremental_report(cid)
            self.generate_report(cid)
            return cid
        finally:
            base.LOCK_PATH.unlink(missing_ok=True)


def parse_duration(value: str) -> int:
    return base.parse_duration(value)


def main() -> int:
    p = argparse.ArgumentParser(description="TFTMAC evidence-grounded incremental small-gains sweep")
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("self-test")
    c = sub.add_parser("campaign"); c.add_argument("--duration", type=parse_duration, default=parse_duration("4h")); c.add_argument("--resume", action="store_true"); c.add_argument("--impact-only", action="store_true")
    sub.add_parser("status")
    args = p.parse_args()
    lab = IncrementalLab()
    try:
        if args.command == "self-test":
            static = lab.verify_static_authority()
            manifest = lab.incremental_manifest
            assert manifest["baseline"] == lab.authority["working_version"]
            assert [x["id"] for x in manifest["candidates"]] == ["pso-precompile-threads-2","shader-background-batch-4","animation-budget-5ms","animation-budget-4ms"]
            # prove exact candidate generation against the current installed profile
            import tempfile
            receipts=[]
            current=lab.installed_profile
            with tempfile.TemporaryDirectory() as td:
                for spec in manifest["candidates"][:3]:
                    out=Path(td)/f"{spec['id']}.ini"; receipts.append(lab.build_profile_candidate(current,spec,out)); current=lab.installed_profile
            stability = lab.stability_spec()
            assert stability["id"] == "stability-control" and stability["cvar"] == "" and stability["from"] == stability["to"] == ""
            deadline_fixture = {"deadline_utc": "2026-09-11T12:21:51Z"}
            assert not deadline_reached(deadline_fixture, now=datetime(2026, 9, 11, 8, 21, 51, tzinfo=timezone.utc))
            assert deadline_reached(deadline_fixture, now=datetime(2026, 9, 11, 12, 21, 51, tzinfo=timezone.utc))
            assert args.command == "self-test"
            print(json.dumps({"static": static, "incremental_manifest": "PASS", "exact_one_cvar_generation": "PASS", "stability_tail_policy": "PASS", "impact_only_queue_completion": "PASS", "durable_deadline_policy": "PASS", "candidate_receipts": receipts}, indent=2)); return 0
        if args.command == "campaign":
            print(lab.run_incremental_campaign(args.duration, args.resume, args.impact_only)); return 0
        if args.command == "status":
            cid=lab.current_campaign(); print(json.dumps(lab.read_state(cid) if cid and lab.state_path(cid).exists() else {"campaign":None}, indent=2)); return 0
        return 2
    except base.LabError as exc:
        print(f"TFTMAC IncrementalLab: {exc.error_class}: {exc}", file=__import__('sys').stderr); return 3
    finally:
        lab.close()

if __name__ == "__main__":
    raise SystemExit(main())
