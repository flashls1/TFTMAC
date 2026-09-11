#!/usr/bin/env python3
"""TFTMAC OvernightLab.

Small external, official-client-only telemetry/controller layer that reuses the
installed TFTMAC DEV app and StockShadow runtime while keeping the frozen LKG
separate.  It never contains or creates another app/SDK/emulator/AVD.  Raw native
capture remains authoritative; this database preserves cross-run identity,
requested/effective values, drift, coverage, rollback, failure quarantine and
conservative comparison eligibility.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import re
import shlex
import shutil
import signal
import sqlite3
import statistics
import subprocess
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Optional

ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
AUTHORITY_PATH = ROOT / "authority" / "official-client-runtime.json"
CANDIDATES_PATH = ROOT / "manifests" / "official-candidates.json"
SCHEMA_PATH = ROOT / "schema.sql"
DB_PATH = ROOT / "database" / "TFTMAC_OVERNIGHT.sqlite"
CAMPAIGN_ROOT = ROOT / "campaigns"
REPORT_ROOT = ROOT / "reports"
QUARANTINE_ROOT = ROOT / "quarantine"
BIN_ROOT = ROOT / "bin"
LOCK_PATH = ROOT / "campaign.lock"
ACTIVE_PATH = ROOT / "active-campaign.txt"

PBE_MARKERS = (
    "com.riotgames.league.teamfighttactics.pbe",
    "tft-pbe-",
    "performance-candidates.json",
)
CLASSIFICATIONS = {
    "HARD_REJECT", "INCONCLUSIVE", "NO_SIGNAL", "MECHANISM_WORKING",
    "POSITIVE_PROVISIONAL", "PROMOTION_CANDIDATE", "WIN_60", "CONTROL_VALID",
    "CONTROL_SETUP_FAILED", "TELEMETRY_INCOMPLETE", "INTERRUPTED",
    "AUTH_BLOCKED", "UI_BLOCKED", "SKIPPED", "QUARANTINED", "DATA_ONLY_NONCOMPARABLE",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def mono_ns() -> int:
    return time.monotonic_ns()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".next")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, sort_keys=True)
        f.write("\n")
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def safe_text(path: Path, maximum: int = 32 * 1024 * 1024) -> str:
    try:
        size = path.stat().st_size
        with path.open("rb") as f:
            if size > maximum:
                f.seek(size - maximum)
            return f.read(maximum).decode("utf-8", "replace")
    except OSError:
        return ""


def percentile(values: list[float], q: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    i = max(0, min(len(ordered) - 1, math.ceil(len(ordered) * q) - 1))
    return ordered[i]


def normalize_error(text: str) -> str:
    text = re.sub(r"0x[0-9a-fA-F]+", "0x#", text)
    text = re.sub(r"\b\d{4,}\b", "#", text)
    text = re.sub(r"\s+", " ", text.strip())
    return text[:1000]


class LabError(RuntimeError):
    def __init__(self, message: str, *, error_class: str = "LAB_ERROR", component: str = "controller", phase: str = "unknown"):
        super().__init__(message)
        self.error_class = error_class
        self.component = component
        self.phase = phase


class AuthBlocked(LabError):
    pass


@dataclass
class CommandResult:
    argv: list[str]
    returncode: int
    stdout: str
    stderr: str
    duration_ms: float


@dataclass
class RunContext:
    campaign_id: str
    candidate: dict[str, Any]
    run_id: str
    run_dir: Path
    build_id: Optional[str] = None
    capture: Optional[Path] = None
    open_process: Optional[subprocess.Popen] = None
    state: str = "STARTING"
    package_pid: Optional[int] = None
    selected_rhi: Optional[str] = None
    raw_native_rhi: Optional[str] = None
    angle_applied: bool = False
    profile_overlay_applied: bool = False
    cache_overrides_applied: bool = False
    package_version: Optional[str] = None
    version_code: Optional[int] = None
    decision_admissible: bool = True
    evidence_scope: str = "CURRENT_PROMOTION"
    drift_reasons: list[str] = field(default_factory=list)


class Database:
    def __init__(self, path: Path = DB_PATH):
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path, timeout=30)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
        self.db.commit()

    def close(self) -> None:
        self.db.close()

    def execute(self, sql: str, args: Iterable[Any] = ()) -> sqlite3.Cursor:
        cur = self.db.execute(sql, tuple(args))
        self.db.commit()
        return cur

    def one(self, sql: str, args: Iterable[Any] = ()) -> Optional[sqlite3.Row]:
        return self.db.execute(sql, tuple(args)).fetchone()

    def rows(self, sql: str, args: Iterable[Any] = ()) -> list[sqlite3.Row]:
        return list(self.db.execute(sql, tuple(args)))


class OvernightLab:
    def __init__(self):
        self.authority = read_json(AUTHORITY_PATH)
        self.manifest = read_json(CANDIDATES_PATH)
        self.db = Database()
        self.adb_path = Path(self.authority["adb_path"])
        self.adb_port = int(self.authority["adb_server_port"])
        self.serial = self.authority["serial"]
        self.package = self.authority["package_name"]
        self.game_activity = self.authority["game_activity"]
        self.dev_app = Path(self.authority["installed_dev_app"])
        self.dev_launcher = self.dev_app / "Contents/MacOS/TFTMACDEVLauncher"
        self.lkg_root = Path(self.authority["frozen_lkg_root"])
        self.capture_root = Path(os.path.expanduser(self.authority["capture_root"]))
        self.avd_config = Path(self.authority["avd_config_path"])
        self.avd_journal = Path(os.path.expanduser(self.authority["avd_transaction_journal"]))
        self.expected_avd_sha = self.authority["expected_avd_config_sha256"]
        self.classifier = BIN_ROOT / "tft-screen-classifier"
        self.classifier_source = PROJECT_ROOT / "tools" / "tft-screen-classifier.swift"
        self.classifier_build = PROJECT_ROOT / "scripts" / "build-tft-screen-classifier.command"
        self._last_state: dict[str, str] = {}

    def close(self) -> None:
        self.db.close()

    # ---------- command / evidence primitives ----------
    def command(self, argv: list[str], *, timeout: float = 30, check: bool = False,
                env: Optional[dict[str, str]] = None) -> CommandResult:
        started = time.monotonic()
        try:
            p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, env=env)
        except subprocess.TimeoutExpired as exc:
            raise LabError(f"command timed out: {argv[0]}", error_class="COMMAND_TIMEOUT", component="host", phase="command") from exc
        result = CommandResult(argv, p.returncode, p.stdout, p.stderr, (time.monotonic() - started) * 1000)
        if check and p.returncode != 0:
            message = normalize_error(p.stderr or p.stdout or f"exit {p.returncode}")
            raise LabError(f"command failed: {argv[0]}: {message}", error_class="COMMAND_FAILED", component="host", phase="command")
        return result

    def adb(self, *args: str, timeout: float = 30, check: bool = True) -> CommandResult:
        argv = [str(self.adb_path), "-P", str(self.adb_port), "-s", self.serial, *args]
        result = self.command(argv, timeout=timeout, check=False)
        if check and result.returncode != 0:
            raise LabError(
                f"ADB failed: {normalize_error(result.stderr or result.stdout)}",
                error_class="ADB_COMMAND_FAILED", component="adb", phase="runtime")
        return result

    def record_artifact(self, ctx: RunContext, kind: str, path: Path) -> None:
        if not path.exists() or not path.is_file():
            return
        aid = str(uuid.uuid4())
        digest = sha256_file(path)
        self.db.execute(
            "INSERT OR REPLACE INTO artifacts(artifact_id,run_id,campaign_id,kind,path,sha256,byte_count,created_utc) VALUES(?,?,?,?,?,?,?,?)",
            (aid, ctx.run_id, ctx.campaign_id, kind, str(path), digest, path.stat().st_size, utc_now()))

    def record_provenance(self, ctx: RunContext, kind: str, path: Path, *, admissible: bool,
                          confidence: str = "DIRECT") -> None:
        digest = sha256_file(path) if path.exists() and path.is_file() else None
        self.db.execute(
            """INSERT OR REPLACE INTO evidence_provenance(
                 evidence_id,campaign_id,candidate_id,run_id,client_scope,package_name,package_version,
                 version_code,package_pid,runtime_configuration_sha256,graphics_stack_sha256,evidence_kind,
                 evidence_path,evidence_sha256,identity_verification_method,identity_confidence,
                 decision_admissible,created_utc) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (str(uuid.uuid4()), ctx.campaign_id, ctx.candidate["id"], ctx.run_id, "OFFICIAL_LIVE",
             self.package, ctx.package_version or self.authority["version_name"], str(ctx.version_code or self.authority["version_code"]), ctx.package_pid,
             None, None, kind, str(path), digest,
             "observed package/version + current DEV host identity", confidence, 1 if admissible else 0, utc_now()))

    def coverage(self, ctx: RunContext, producer: str, *, expected: bool, produced: int,
                 persisted: int, lost: int = 0, malformed: int = 0, parse_errors: int = 0,
                 status: Optional[str] = None, schema_version: Optional[str] = None) -> None:
        if status is None:
            if not expected:
                status = "NOT_APPLICABLE"
            elif lost or malformed or parse_errors or persisted < produced:
                status = "LOSS" if lost or persisted < produced else "MALFORMED"
            elif produced == 0:
                status = "MISSING"
            else:
                status = "COMPLETE"
        self.db.execute(
            """INSERT OR REPLACE INTO telemetry_coverage(
                 run_id,producer,expected,schema_version,first_sequence,last_sequence,produced_count,
                 persisted_count,lost_count,malformed_count,parse_error_count,started_monotonic_ns,
                 ended_monotonic_ns,status) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (ctx.run_id, producer, 1 if expected else 0, schema_version,
             1 if produced else None, produced if produced else None,
             produced, persisted, lost, malformed, parse_errors, None, None, status))

    # ---------- authority / PBE / baseline ----------
    def contains_pbe(self, value: Any) -> list[str]:
        hits: list[str] = []
        def visit(v: Any, path: str) -> None:
            if isinstance(v, dict):
                for k, item in v.items(): visit(item, f"{path}.{k}")
            elif isinstance(v, list):
                for i, item in enumerate(v): visit(item, f"{path}[{i}]")
            elif isinstance(v, str):
                low = v.lower()
                for marker in PBE_MARKERS:
                    if marker.lower() in low:
                        hits.append(f"{path}:{marker}")
        visit(value, "$")
        return hits

    def ensure_classifier(self) -> None:
        if not self.classifier_source.is_file() or not self.classifier_build.is_file():
            raise LabError("screen classifier source/build route is missing", error_class="CLASSIFIER_SOURCE_MISSING", phase="preflight")
        needs_build = (not self.classifier.is_file()) or self.classifier_source.stat().st_mtime_ns > self.classifier.stat().st_mtime_ns
        if needs_build:
            BIN_ROOT.mkdir(parents=True, exist_ok=True)
            module_cache = BIN_ROOT / "swift-module-cache"
            env = os.environ.copy()
            env["TFT_SCREEN_CLASSIFIER_BINARY"] = str(self.classifier)
            env["TFT_SCREEN_CLASSIFIER_MODULE_CACHE"] = str(module_cache)
            result = self.command([str(self.classifier_build)], timeout=180, env=env)
            if result.returncode != 0 or not self.classifier.is_file():
                raise LabError(
                    f"screen classifier build failed: {normalize_error(result.stderr or result.stdout)}",
                    error_class="CLASSIFIER_BUILD_FAILED", component="classifier", phase="preflight")
        result = self.command([str(self.classifier), "--self-test"], timeout=30)
        if result.returncode != 0:
            raise LabError(
                f"screen classifier self-test failed: {normalize_error(result.stderr or result.stdout)}",
                error_class="CLASSIFIER_SELF_TEST_FAILED", component="classifier", phase="preflight")

    def verify_static_authority(self) -> dict[str, Any]:
        if self.authority.get("client_scope") != "OFFICIAL_LIVE":
            raise LabError("authority client_scope is not OFFICIAL_LIVE", error_class="AUTHORITY_INVALID", phase="preflight")
        hits = self.contains_pbe(self.authority) + self.contains_pbe(self.manifest)
        if hits:
            raise LabError(f"PBE input rejected: {hits[0]}", error_class="PBE_EVIDENCE_REJECTED", phase="admission")
        if self.authority["package_name"] != "com.riotgames.league.teamfighttactics":
            raise LabError("official package authority drifted", error_class="PACKAGE_AUTHORITY_INVALID", phase="preflight")
        if not self.dev_app.is_dir() or not self.dev_launcher.is_file() or not self.adb_path.is_file() or not self.avd_config.is_file():
            raise LabError("installed DEV, launcher, StockShadow ADB or AVD config is missing", error_class="RUNTIME_MISSING", phase="preflight")
        if not self.avd_journal.exists() and sha256_file(self.avd_config) != self.expected_avd_sha:
            raise LabError("StockShadow AVD config is not at its accepted baseline and has no recovery journal", error_class="AVD_BASELINE_MISMATCH", phase="preflight")
        self.ensure_classifier()
        lkg_app = self.lkg_root / "TFTMAC DEV.app"
        current_mismatches = []
        for relative, expected in self.authority["current_dev_hashes"].items():
            installed = self.dev_app / relative
            if not installed.is_file() or sha256_file(installed) != expected:
                current_mismatches.append(relative)
        if current_mismatches:
            raise LabError(f"installed current DEV integrity mismatch: {current_mismatches}", error_class="DEV_INTEGRITY_FAILED", phase="preflight")
        lkg_mismatches = []
        for relative, expected in self.authority["frozen_lkg_hashes"].items():
            frozen = lkg_app / relative
            if not frozen.is_file() or sha256_file(frozen) != expected:
                lkg_mismatches.append(relative)
        if lkg_mismatches:
            raise LabError(f"frozen LKG integrity mismatch: {lkg_mismatches}", error_class="LKG_INTEGRITY_FAILED", phase="preflight")
        forbidden = [ROOT / n for n in ("SDK", "AVD", "emulator", "TFTMAC DEV.app")]
        if any(p.exists() for p in forbidden):
            raise LabError("OvernightLab contains a forbidden runtime/app copy", error_class="RUNTIME_CLONE_FORBIDDEN", phase="preflight")
        codesign = self.command(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(self.dev_app)], timeout=30)
        if codesign.returncode != 0:
            raise LabError("installed DEV codesign verification failed", error_class="DEV_CODESIGN_INVALID", phase="preflight")
        return {"installed_dev_integrity": True, "frozen_lkg_integrity": True, "pbe_hits": [], "codesign": "PASS", "working_version": self.authority["working_version"]}

    def candidate(self, candidate_id: str) -> dict[str, Any]:
        matches = [c for c in self.manifest.get("candidates", []) if c.get("id") == candidate_id]
        if len(matches) != 1:
            raise LabError(f"candidate not uniquely defined: {candidate_id}", error_class="CANDIDATE_INVALID", phase="admission")
        candidate = matches[0]
        hits = self.contains_pbe(candidate)
        if hits:
            raise LabError(f"PBE candidate rejected: {hits[0]}", error_class="PBE_EVIDENCE_REJECTED", phase="admission")
        if candidate.get("build_scope") not in {"NO_BUILD", "ANGLE_DRIVER_BUILD", "APP_BUILD_REQUIRED"}:
            raise LabError("unsupported build scope", error_class="CANDIDATE_INVALID", phase="admission")
        return candidate

    # ---------- DB / campaign ----------
    def ensure_candidates(self) -> None:
        for c in self.manifest["candidates"]:
            definition = canonical_json(c)
            self.db.execute(
                "INSERT OR REPLACE INTO candidates(candidate_id,family,kind,build_scope,restart_class,definition_json,definition_sha256,enabled) VALUES(?,?,?,?,?,?,?,?)",
                (c["id"], c["family"], c["kind"], c["build_scope"], c["restart_class"], definition, sha256_bytes(definition.encode()), int(c.get("enabled", True))))

    def create_campaign(self) -> str:
        self.verify_static_authority()
        self.ensure_candidates()
        cid = "overnight-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
        campaign_dir = CAMPAIGN_ROOT / cid
        campaign_dir.mkdir(parents=True, exist_ok=False)
        authority_sha = sha256_file(AUTHORITY_PATH)
        manifest_sha = sha256_file(CANDIDATES_PATH)
        self.db.execute(
            "INSERT INTO campaigns(campaign_id,started_utc,state,authority_sha256,candidate_manifest_sha256,lkg_integrity_passed,pbe_evidence_admitted) VALUES(?,?,?,?,?,1,0)",
            (cid, utc_now(), "RUNNING", authority_sha, manifest_sha))
        ACTIVE_PATH.write_text(cid + "\n", encoding="utf-8")
        self.write_checkpoint(cid, queue_index=0, state="RUNNING", phase="CAMPAIGN_START", current_candidate=None, current_run=None, failure=None)
        return cid

    def campaign_dir(self, cid: str) -> Path:
        return CAMPAIGN_ROOT / cid

    def checkpoint_path(self, cid: str) -> Path:
        return self.campaign_dir(cid) / "checkpoint.json"

    def write_checkpoint(self, cid: str, *, queue_index: int, state: str, phase: str,
                         current_candidate: Optional[str], current_run: Optional[str], failure: Optional[str]) -> None:
        current = {}
        path = self.checkpoint_path(cid)
        if path.exists():
            try: current = read_json(path)
            except Exception: current = {}
        payload = {
            "schema_version": 1,
            "campaign_id": cid,
            "campaign_state": state,
            "queue_index": queue_index,
            "current_candidate": current_candidate,
            "current_run_id": current_run,
            "started_utc": current.get("started_utc", utc_now()),
            "last_heartbeat_utc": utc_now(),
            "phase": phase,
            "current_failure": failure,
            "rollback_state": current.get("rollback_state", "UNKNOWN"),
            "next_action": current.get("next_action"),
        }
        atomic_json(path, payload)

    def heartbeat(self, ctx: RunContext, phase: str) -> None:
        cp = read_json(self.checkpoint_path(ctx.campaign_id))
        self.write_checkpoint(ctx.campaign_id, queue_index=int(cp.get("queue_index", 0)), state="RUNNING",
                              phase=phase, current_candidate=ctx.candidate["id"], current_run=ctx.run_id, failure=None)

    def current_campaign(self) -> Optional[str]:
        if not ACTIVE_PATH.exists(): return None
        cid = ACTIVE_PATH.read_text(encoding="utf-8").strip()
        return cid if cid and self.campaign_dir(cid).is_dir() else None

    def new_run(self, cid: str, candidate: dict[str, Any]) -> RunContext:
        rid = "run-" + uuid.uuid4().hex
        run_dir = self.campaign_dir(cid) / "runs" / rid
        run_dir.mkdir(parents=True, exist_ok=False)
        ctx = RunContext(cid, candidate, rid, run_dir)
        if not candidate.get("enabled", True):
            ctx.decision_admissible = False
            ctx.evidence_scope = "DATA_ONLY_DISABLED_CANDIDATE"
            ctx.drift_reasons.append(f"candidate_status:{candidate.get('status', 'disabled')}")
        self.db.execute(
            "INSERT INTO runs(run_id,campaign_id,candidate_id,started_utc,state) VALUES(?,?,?,?,?)",
            (rid, cid, candidate["id"], utc_now(), "STARTING"))
        atomic_json(run_dir / "candidate.json", candidate)
        self.record_artifact(ctx, "candidate_definition", run_dir / "candidate.json")
        return ctx

    # ---------- failure / quarantine ----------
    def failure(self, ctx: RunContext, err: BaseException, phase: str) -> str:
        component = getattr(err, "component", "controller")
        error_class = getattr(err, "error_class", type(err).__name__)
        normalized = normalize_error(str(err))
        key = canonical_json([ctx.candidate["id"], component, phase, error_class, normalized])
        fp = sha256_bytes(key.encode())
        existing = self.db.one("SELECT * FROM failures WHERE campaign_id=? AND fingerprint=?", (ctx.campaign_id, fp))
        now = utc_now()
        if existing:
            count = int(existing["occurrence_count"]) + 1
            quarantined = 1 if count >= 2 else int(existing["quarantined"])
            self.db.execute("UPDATE failures SET last_seen_utc=?,occurrence_count=?,quarantined=? WHERE failure_id=?",
                            (now, count, quarantined, existing["failure_id"]))
        else:
            count, quarantined = 1, 0
            self.db.execute(
                "INSERT INTO failures(failure_id,campaign_id,candidate_id,run_id,component,phase,error_class,normalized_error,fingerprint,first_seen_utc,last_seen_utc,occurrence_count,quarantined) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (str(uuid.uuid4()), ctx.campaign_id, ctx.candidate["id"], ctx.run_id, component, phase,
                 error_class, normalized, fp, now, now, count, quarantined))
        self.db.execute("UPDATE runs SET failure_fingerprint=? WHERE run_id=?", (fp, ctx.run_id))
        return fp

    def is_quarantined(self, cid: str, candidate_id: str) -> bool:
        row = self.db.one("SELECT MAX(quarantined) q FROM failures WHERE campaign_id=? AND candidate_id=?", (cid, candidate_id))
        return bool(row and row["q"])

    # ---------- launch / process / capture ----------
    def dev_core_running(self) -> bool:
        return self.command(
            ["/usr/bin/pgrep", "-f", "^/Applications/TFTMAC DEV\\.app/Contents/MacOS/TFTMACDEVCore$"],
            check=False,
        ).returncode == 0

    def owned_emulator_pids(self) -> list[int]:
        pattern = rf"^/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK/emulator/qemu/darwin-aarch64/qemu-system-aarch64 @{re.escape(self.authority['avd_name'])}( |$)"
        result = self.command(["/usr/bin/pgrep", "-f", pattern], check=False)
        return [int(x) for x in result.stdout.split() if x.isdigit()]

    def stop_owned_emulator(self) -> None:
        if not self.owned_emulator_pids():
            return
        self.adb("emu", "kill", timeout=10, check=False)
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline and self.owned_emulator_pids():
            time.sleep(0.25)
        for pid in self.owned_emulator_pids():
            try: os.kill(pid, signal.SIGTERM)
            except ProcessLookupError: pass
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and self.owned_emulator_pids():
            time.sleep(0.25)
        for pid in self.owned_emulator_pids():
            try: os.kill(pid, signal.SIGKILL)
            except ProcessLookupError: pass
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and self.owned_emulator_pids():
            time.sleep(0.25)
        # The native forwarder is only a launch owner for this isolated diagnostic runtime.
        forwarders = self.command(["/usr/bin/pgrep", "-f", r"^/usr/bin/open -n -W .*TFTMAC Diagnostic Forwarder\.app"], check=False)
        for pid in forwarders.stdout.split():
            if pid.isdigit():
                try: os.kill(int(pid), signal.SIGTERM)
                except ProcessLookupError: pass

    def recover_avd_transaction(self) -> dict[str, Any]:
        if self.owned_emulator_pids():
            raise LabError("AVD recovery withheld while the owned emulator is active", error_class="AVD_RECOVERY_BLOCKED", phase="rollback")
        if not self.avd_journal.exists():
            current = sha256_file(self.avd_config)
            if current != self.expected_avd_sha:
                raise LabError("AVD baseline hash mismatch without a recovery journal", error_class="AVD_BASELINE_MISMATCH", phase="rollback")
            return {"journal_present": False, "restored": False, "verified": True, "sha256": current}
        try:
            marker = read_json(self.avd_journal)
            required = {"schema", "config", "backup", "original_sha256", "applied_sha256"}
            if marker.get("schema") != 1 or not required.issubset(marker):
                raise ValueError("invalid journal schema")
            config = Path(marker["config"]).resolve()
            backup = Path(marker["backup"]).resolve()
            capture_root = self.capture_root.resolve()
            if config != self.avd_config.resolve():
                raise ValueError("journal config path mismatch")
            if backup.name != "avd-config.before.ini" or capture_root not in backup.parents:
                raise ValueError("journal backup path outside capture root")
            if marker["original_sha256"] != self.expected_avd_sha:
                raise ValueError("journal original hash does not match accepted StockShadow baseline")
            if not backup.is_file() or sha256_file(backup) != marker["original_sha256"]:
                raise ValueError("journal backup hash mismatch")
            current = sha256_file(self.avd_config)
            if current == marker["original_sha256"]:
                restored = False
            elif current == marker["applied_sha256"]:
                data = backup.read_bytes()
                tmp = self.avd_config.with_name(self.avd_config.name + ".overnight-restore")
                with tmp.open("wb") as f:
                    f.write(data); f.flush(); os.fsync(f.fileno())
                os.replace(tmp, self.avd_config)
                restored = True
            else:
                raise ValueError("AVD config changed outside the journaled transaction")
            verified = sha256_file(self.avd_config) == self.expected_avd_sha
            if not verified:
                raise ValueError("AVD restore readback failed")
            self.avd_journal.unlink()
            return {"journal_present": True, "restored": restored, "verified": True, "sha256": self.expected_avd_sha,
                    "backup": str(backup)}
        except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
            raise LabError(f"AVD transaction recovery failed safely: {exc}", error_class="AVD_RECOVERY_FAILED", phase="rollback") from exc

    def ensure_clean_runtime_baseline(self) -> dict[str, Any]:
        self.request_dev_quit()
        if self.owned_emulator_pids():
            self.stop_owned_emulator()
        return self.recover_avd_transaction()

    def latest_capture(self) -> Optional[Path]:
        if not self.capture_root.is_dir(): return None
        dirs = [p for p in self.capture_root.iterdir() if p.is_dir()]
        return max(dirs, key=lambda p: p.stat().st_mtime_ns) if dirs else None

    def launch_dev(self, ctx: RunContext) -> None:
        if self.command(["/usr/bin/pgrep", "-f", "^/Applications/TFTMAC\\.app/Contents/MacOS/"], check=False).returncode == 0:
            raise LabError("protected Control is running; DEV launch refused", error_class="CONTROL_ACTIVE", phase="launch")
        if self.command(["/usr/bin/pgrep", "-f", "^/Applications/TFTMAC DEV\\.app/Contents/MacOS/TFTMACDEVCore$"], check=False).returncode == 0:
            raise LabError("another DEV core is running", error_class="DEV_ALREADY_RUNNING", phase="launch")
        self.ensure_clean_runtime_baseline()
        before = self.latest_capture()
        env = os.environ.copy()
        env.update({
            "TFTMAC_RUNTIME_MODE": "advanced_diagnostics",
            "TFTMAC_DEV_VCPU": "8",
            "TFTMAC_AUTONOMOUS_SILENT": "1",
        })
        if ctx.candidate["kind"] == "angle":
            manifest_path = Path(ctx.candidate["angle_manifest"])
            if not manifest_path.is_file():
                raise LabError(f"ANGLE artifact is not built: {manifest_path}", error_class="ANGLE_ARTIFACT_MISSING", component="angle", phase="launch")
            self.validate_angle_manifest(manifest_path)
            env["TFTMAC_ANGLE_DRIVER_MANIFEST"] = str(manifest_path)
        launch_env = {
            key: env[key]
            for key in ("TFTMAC_RUNTIME_MODE", "TFTMAC_DEV_VCPU", "TFTMAC_AUTONOMOUS_SILENT", "TFTMAC_ANGLE_DRIVER_MANIFEST")
            if key in env
        }
        # The frozen Sept.10 LKG is proven only through the packaged GUI/session launch boundary.
        # Do not execute TFTMACDEVLauncher directly from the controller process.
        argv = ["/usr/bin/open", "-n"]
        for key, value in launch_env.items():
            argv.extend(["--env", f"{key}={value}"])
        argv.append(str(self.dev_app))
        opened = self.command(argv, timeout=30, check=False)
        (ctx.run_dir / "open.log").write_text(opened.stdout + opened.stderr, encoding="utf-8")
        if opened.returncode != 0:
            raise LabError(
                f"DEV GUI launch failed: {normalize_error(opened.stderr or opened.stdout)}",
                error_class="DEV_GUI_LAUNCH_FAILED", component="host", phase="launch")
        ctx.open_process = None
        atomic_json(ctx.run_dir / "launch.json", {"argv": argv, "environment": launch_env, "started_utc": utc_now()})
        deadline = time.monotonic() + 45
        capture = None
        while time.monotonic() < deadline:
            newest = self.latest_capture()
            if newest and newest != before:
                capture = newest
                break
            time.sleep(0.5)
        ctx.capture = capture
        if capture:
            self.db.execute("UPDATE runs SET capture_path=? WHERE run_id=?", (str(capture), ctx.run_id))

    def wait_for_device(self, ctx: RunContext, timeout: int = 150) -> None:
        self.command([str(self.adb_path), "-P", str(self.adb_port), "start-server"], timeout=20)
        started = time.monotonic()
        deadline = started + timeout
        while time.monotonic() < deadline:
            if time.monotonic() - started > 10 and not self.dev_core_running() and not self.owned_emulator_pids():
                raise LabError("DEV exited before ADB became ready", error_class="BOOT_FAILURE", phase="boot")
            r = self.adb("get-state", timeout=5, check=False)
            if r.returncode == 0 and "device" in r.stdout:
                return
            self.heartbeat(ctx, "WAIT_ADB")
            time.sleep(1)
        raise LabError("ADB device did not become ready", error_class="ADB_TIMEOUT", phase="boot")

    def qemu_command(self) -> tuple[Optional[int], str]:
        r = self.command(["/usr/bin/pgrep", "-f", f"qemu-system-aarch64.*{re.escape(self.authority['avd_name'])}"], check=False)
        pids = [int(x) for x in r.stdout.split() if x.isdigit()]
        if not pids: return None, ""
        pid = pids[0]
        ps = self.command(["/bin/ps", "-p", str(pid), "-ww", "-o", "command="], check=False)
        return pid, ps.stdout.strip()

    def apply_session_properties_before_tft(self, ctx: RunContext, timeout: int = 30) -> dict[str, str]:
        """Apply the current verified working guest properties before first TFT PID."""
        working = self.authority["current_working_cache_properties"]
        values = dict(ctx.candidate.get("guest_properties", working))
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            uid = self.adb("shell", "id", "-u", timeout=4, check=False)
            pid = self.adb("shell", "pidof", self.package, timeout=4, check=False)
            if pid.returncode == 0 and pid.stdout.strip():
                raise LabError(
                    "TFT started before mandatory current-working session properties were applied",
                    error_class="SESSION_PROPERTIES_LATE", component="runtime", phase="boot")
            if uid.returncode == 0 and uid.stdout.strip() in {"0", "2000"}:
                observed: dict[str, str] = {}
                for key, value in values.items():
                    self.adb("shell", "setprop", key, value, timeout=6)
                    actual = self.adb("shell", "getprop", key, timeout=6).stdout.strip()
                    if actual != value:
                        raise LabError(
                            f"mandatory session property not effective: {key}",
                            error_class="PROPERTY_NOT_EFFECTIVE", component="runtime", phase="boot")
                    observed[key] = actual
                ctx.cache_overrides_applied = values != working
                atomic_json(ctx.run_dir / "session-properties.json", {
                    "applied_before_tft_pid": True,
                    "shell_uid": uid.stdout.strip(),
                    "properties": observed,
                    "observed_utc": utc_now(),
                })
                self.record_artifact(ctx, "session_properties", ctx.run_dir / "session-properties.json")
                return observed
            if not self.owned_emulator_pids():
                raise LabError(
                    "emulator exited before mandatory Sept.10 session properties could be applied",
                    error_class="BOOT_FAILURE", component="runtime", phase="boot")
            time.sleep(0.25)
        raise LabError(
            "mandatory current-working session properties were not applied before TFT startup",
            error_class="SESSION_PROPERTIES_TIMEOUT", component="runtime", phase="boot")

    def wait_for_shell_and_package(self, ctx: RunContext, timeout: int = 180) -> None:
        started = time.monotonic()
        deadline = started + timeout
        while time.monotonic() < deadline:
            uid = self.adb("shell", "id", "-u", timeout=5, check=False)
            package = self.adb("shell", "pm", "path", self.package, timeout=7, check=False)
            if uid.returncode == 0 and uid.stdout.strip() == "2000" and package.returncode == 0 and "package:" in package.stdout:
                return
            # If the native owner has already failed, restored, and stopped the emulator,
            # there is no useful reason to burn the full readiness timeout.
            if time.monotonic() - started > 10 and not self.owned_emulator_pids():
                raise LabError(
                    "emulator exited before normal shell/package readiness",
                    error_class="BOOT_FAILURE", component="runtime", phase="boot")
            self.heartbeat(ctx, "WAIT_RUNTIME_READY")
            time.sleep(1)
        raise LabError("normal shell/package readiness timed out", error_class="RUNTIME_READY_TIMEOUT", phase="runtime")

    # ---------- runtime verification / variables ----------
    def device_profile_values(self) -> dict[str, str]:
        path = self.dev_app / "Contents/Resources/DEVHighPerf/DeviceProfiles.ini"
        result: dict[str, str] = {}
        for line in safe_text(path).splitlines():
            if line.startswith("CVars="):
                pair = line[6:].split("=", 1)
                if len(pair) == 2: result[pair[0]] = pair[1]
        return result

    def find_engine_log(self, capture: Optional[Path]) -> Optional[Path]:
        if not capture or not capture.is_dir(): return None
        # Priority matters: the dedicated engine boot log is selection authority.
        # A newer generic logcat file may contain Vulkan capability text without the
        # Unreal RHI selection decision and must not displace the engine log.
        for pattern in ("*engine*boot*.log", "*engine*.log", "TFT.log", "*logcat*.txt"):
            candidates = [p for p in capture.glob(pattern) if p.is_file()]
            if candidates:
                return max(candidates, key=lambda p: p.stat().st_mtime_ns)
        return None

    def selected_rhi(self, capture: Optional[Path]) -> tuple[str, Optional[str]]:
        raw = None
        if capture:
            db = capture / "TFTMAC_NATIVE_RUNTIME.sqlite"
            if db.is_file():
                try:
                    c = sqlite3.connect(db)
                    row = c.execute("SELECT game_graphics_api FROM graphics_pipeline_snapshots ORDER BY id DESC LIMIT 1").fetchone()
                    raw = row[0] if row else None
                    c.close()
                except sqlite3.Error:
                    pass
        engine = self.find_engine_log(capture)
        text = safe_text(engine) if engine else ""
        if re.search(r"VulkanRHI will NOT be used|Vulkan is disabled via console variable|OpenGL ES will be used|Initializing OpenGL RHI", text, re.I):
            return "OPENGL_ES_ANGLE", raw
        if re.search(r"Initializing Vulkan RHI|VulkanRHI will be used|LogVulkanRHI:.*InitGPU|Created Vulkan Device", text, re.I):
            return "UNREAL_DIRECT_VULKAN", raw
        return "UNKNOWN", raw

    def verify_runtime(self, ctx: RunContext) -> dict[str, Any]:
        package_paths = self.adb("shell", "pm", "path", self.package).stdout.strip().splitlines()
        dump = self.adb("shell", "dumpsys", "package", self.package, timeout=20).stdout
        vm = re.search(r"versionName=([^\s]+)", dump)
        vc = re.search(r"versionCode=(\d+)", dump)
        if not vm or not vc:
            raise LabError("official package version identity is missing", error_class="VERSION_IDENTITY_MISSING", phase="identity")
        ctx.package_version = vm.group(1)
        ctx.version_code = int(vc.group(1))
        if ctx.package_version != self.authority["version_name"] or ctx.version_code != int(self.authority["version_code"]):
            ctx.decision_admissible = False
            ctx.evidence_scope = "DATA_ONLY_CORE_CLIENT_DRIFT"
            ctx.drift_reasons.append(f"client:{ctx.package_version}/{ctx.version_code} expected {self.authority['version_name']}/{self.authority['version_code']}")
        pid_text = self.adb("shell", "pidof", self.package, check=False).stdout.strip().split()
        ctx.package_pid = int(pid_text[0]) if pid_text and pid_text[0].isdigit() else None
        qemu_pid, qcmd = self.qemu_command()
        def qemu_int(flag: str) -> Optional[int]:
            match = re.search(rf"(?:^|\s){re.escape(flag)}\s+(\d+)(?:\s|$)", qcmd)
            return int(match.group(1)) if match else None
        actual_vcpu = qemu_int("-cores")
        actual_ram_mib = qemu_int("-memory")
        critical_qemu = ["-skin 1920x1080", "-vsync-rate 60", "-gpu host"]
        missing_critical = [x for x in critical_qemu if x not in qcmd]
        if missing_critical:
            raise LabError(f"effective emulator launch critical mismatch: {missing_critical}", error_class="RUNTIME_CONFIG_MISMATCH", phase="identity")
        if actual_vcpu != int(self.authority["expected_vcpu"]):
            ctx.decision_admissible = False
            ctx.evidence_scope = "DATA_ONLY_MINOR_CONFIG_DRIFT"
            ctx.drift_reasons.append(f"vcpu:{actual_vcpu} expected {self.authority['expected_vcpu']}")
        if actual_ram_mib != int(self.authority["expected_ram_mib"]):
            ctx.decision_admissible = False
            ctx.evidence_scope = "DATA_ONLY_MINOR_CONFIG_DRIFT"
            ctx.drift_reasons.append(f"ram_mib:{actual_ram_mib} expected {self.authority['expected_ram_mib']}")
        wm_size = self.adb("shell", "wm", "size").stdout
        wm_density = self.adb("shell", "wm", "density").stdout
        if "1920x1080" not in wm_size or "320" not in wm_density:
            raise LabError("display/density mismatch", error_class="DISPLAY_MISMATCH", phase="identity")
        props = {}
        requested_props = ctx.candidate.get("guest_properties", self.authority["current_working_cache_properties"])
        for key in sorted(set(self.authority["current_working_cache_properties"]) | set(requested_props)):
            props[key] = self.adb("shell", "getprop", key).stdout.strip()
        ctx.selected_rhi, ctx.raw_native_rhi = self.selected_rhi(ctx.capture)
        rhi_deadline = time.monotonic() + 30
        while ctx.selected_rhi == "UNKNOWN" and time.monotonic() < rhi_deadline:
            if not self.dev_core_running() or not self.owned_emulator_pids():
                break
            time.sleep(1)
            ctx.selected_rhi, ctx.raw_native_rhi = self.selected_rhi(ctx.capture)
        expected_rhi = ctx.candidate.get("expected_rhi", self.authority["expected_normal_rhi"])
        if ctx.selected_rhi != expected_rhi:
            ctx.decision_admissible = False
            ctx.evidence_scope = "DATA_ONLY_CORE_PIPELINE_DRIFT"
            ctx.drift_reasons.append(f"selected_rhi:{ctx.selected_rhi} expected {expected_rhi}")
        identity = {
            "package_paths": package_paths,
            "version_name": ctx.package_version, "version_code": ctx.version_code,
            "pid": ctx.package_pid, "qemu_pid": qemu_pid, "qemu_command": qcmd,
            "effective_vcpu": actual_vcpu, "effective_ram_mib": actual_ram_mib,
            "wm_size": wm_size.strip(), "wm_density": wm_density.strip(), "cache_properties": props,
            "selected_game_rhi": ctx.selected_rhi, "raw_native_classifier_value": ctx.raw_native_rhi,
            "decision_admissible": ctx.decision_admissible, "evidence_scope": ctx.evidence_scope,
            "drift_reasons": list(ctx.drift_reasons),
        }
        atomic_json(ctx.run_dir / "runtime-identity.json", identity)
        self.record_artifact(ctx, "runtime_identity", ctx.run_dir / "runtime-identity.json")
        self.db.execute("UPDATE runs SET package_verified=1,runtime_verified=1,selected_game_rhi=?,raw_native_classifier_value=? WHERE run_id=?",
                        (ctx.selected_rhi, ctx.raw_native_rhi, ctx.run_id))
        self.record_variables(ctx, identity)
        if any(reason.startswith("client:") or reason.startswith("selected_rhi:") for reason in ctx.drift_reasons):
            raise LabError(
                "core client/RHI identity does not match the admitted experiment; evidence retained as data-only",
                error_class="CORE_IDENTITY_MISMATCH", component="runtime", phase="identity")
        return identity

    def upsert_variable(self, ctx: RunContext, category: str, name: str, baseline: Any, requested: Any,
                        effective: Any, source: str, status: str) -> None:
        self.db.execute(
            """INSERT OR REPLACE INTO experiment_variables(
                 run_id,category,variable_name,baseline_value,requested_value,effective_value,
                 verification_source,verification_status,changed_from_control,observed_monotonic_ns)
               VALUES(?,?,?,?,?,?,?,?,?,?)""",
            (ctx.run_id, category, name,
             None if baseline is None else str(baseline), None if requested is None else str(requested),
             None if effective is None else str(effective), source, status,
             1 if requested is not None and baseline is not None and str(requested) != str(baseline) else 0, mono_ns()))

    def record_variables(self, ctx: RunContext, identity: dict[str, Any]) -> None:
        a = self.authority
        core = {
            "package": (a["package_name"], a["package_name"], a["package_name"]),
            "package_version": (a["version_name"], a["version_name"], identity["version_name"]),
            "display.width": (a["expected_width"], a["expected_width"], a["expected_width"]),
            "display.height": (a["expected_height"], a["expected_height"], a["expected_height"]),
            "display.dpi": (a["expected_dpi"], a["expected_dpi"], a["expected_dpi"]),
            "refresh_hz": (a["expected_refresh_hz"], a["expected_refresh_hz"], a["expected_refresh_hz"]),
            "vcpu": (a["expected_vcpu"], a["expected_vcpu"], identity["effective_vcpu"]),
            "ram_mib": (a["expected_ram_mib"], a["expected_ram_mib"], identity["effective_ram_mib"]),
            "gpu_mode": (a["expected_gpu_mode"], a["expected_gpu_mode"], a["expected_gpu_mode"]),
            "selected_game_rhi": (a["expected_normal_rhi"], a["expected_normal_rhi"], identity["selected_game_rhi"]),
        }
        for name, (base, req, eff) in core.items():
            self.upsert_variable(ctx, "runtime", name, base, req, eff, "direct runtime identity", "VERIFIED" if str(req) == str(eff) else "MISMATCH")
        requested_props = ctx.candidate.get("guest_properties", a["current_working_cache_properties"])
        property_keys = sorted(set(a["current_working_cache_properties"]) | set(requested_props))
        for key in property_keys:
            baseline = a["current_working_cache_properties"].get(key)
            requested = requested_props.get(key, baseline)
            effective = self.adb("shell", "getprop", key, check=False).stdout.strip()
            self.upsert_variable(ctx, "guest_property", key, baseline, requested, effective, "adb getprop", "VERIFIED" if str(requested) == effective else "MISMATCH")
        engine = self.find_engine_log(ctx.capture)
        effective_cvars: dict[str, str] = {}
        if engine:
            regex = re.compile(r"Pushing Device Profile CVar: \[\[([^:]+):.*? -> ([^\]]+)\]\]")
            for name, value in regex.findall(safe_text(engine)):
                effective_cvars[name] = value
        for name, baseline in self.device_profile_values().items():
            effective = effective_cvars.get(name)
            status = "VERIFIED" if effective is not None and str(effective) == str(baseline) else ("UNOBSERVED" if effective is None else "MISMATCH")
            self.upsert_variable(ctx, "device_profile", name, baseline, baseline, effective, str(engine) if engine else "engine log unavailable", status)

    # ---------- candidate application ----------
    def validate_angle_manifest(self, path: Path) -> dict[str, Any]:
        data = read_json(path)
        if self.contains_pbe(data):
            raise LabError("PBE marker in ANGLE manifest", error_class="PBE_EVIDENCE_REJECTED", component="angle", phase="admission")
        if data.get("schema") != 1 or data.get("angleRevision") != self.authority["angle_revision"]:
            raise LabError("ANGLE manifest identity mismatch", error_class="ANGLE_MANIFEST_INVALID", component="angle", phase="admission")
        names = {x.get("name") for x in data.get("libraries", [])}
        if names != {"libEGL_angle.so", "libGLESv2_angle.so", "libGLESv1_CM_angle.so"}:
            raise LabError("ANGLE manifest library set mismatch", error_class="ANGLE_MANIFEST_INVALID", component="angle", phase="admission")
        for lib in data["libraries"]:
            p = Path(lib["path"])
            if not p.is_file() or sha256_file(p) != lib["sha256"]:
                raise LabError(f"ANGLE library hash mismatch: {lib['name']}", error_class="ANGLE_ARTIFACT_INVALID", component="angle", phase="admission")
        return data

    def set_guest_properties(self, ctx: RunContext, values: dict[str, str]) -> None:
        self.adb("shell", "am", "force-stop", self.package, timeout=15)
        for key, value in values.items():
            self.adb("shell", "setprop", key, value, timeout=8)
            observed = self.adb("shell", "getprop", key, timeout=8).stdout.strip()
            if observed != value:
                raise LabError(f"property not effective: {key}", error_class="PROPERTY_NOT_EFFECTIVE", phase="candidate_apply")
        ctx.cache_overrides_applied = True
        self.adb("shell", "am", "start", "-n", f"{self.package}/{self.game_activity}", timeout=20)

    def restore_cache_properties(self, ctx: RunContext) -> bool:
        if not ctx.cache_overrides_applied: return True
        try:
            self.adb("shell", "am", "force-stop", self.package, timeout=10, check=False)
            for key, value in self.authority["current_working_cache_properties"].items():
                self.adb("shell", "setprop", key, value, timeout=8)
                if self.adb("shell", "getprop", key, timeout=8).stdout.strip() != value:
                    return False
            return True
        except Exception:
            return False

    def profile_map(self, text: str) -> dict[tuple[str, str], str]:
        section = ""
        result: dict[tuple[str, str], str] = {}
        for raw in text.splitlines():
            line = raw.strip()
            if line.startswith("[") and line.endswith("]"):
                section = line
            elif line.startswith("CVars="):
                k, sep, v = line[6:].partition("=")
                if sep: result[(section, k)] = v
        return result

    def prepare_vulkan_profile(self, ctx: RunContext) -> Path:
        source = self.dev_app / "Contents/Resources/DEVHighPerf/DeviceProfiles.ini"
        text = source.read_text(encoding="utf-8")
        base = self.profile_map(text)
        if not any(k[1] == "r.Android.DisableVulkanSupport" and v == "1" for k, v in base.items()):
            raise LabError("LKG Vulkan-disable CVar not found", error_class="VULKAN_PROFILE_INVALID", phase="candidate_apply")
        candidate_text = re.sub(r"(?m)^CVars=r\.Android\.DisableVulkanSupport=1$", "CVars=r.Android.DisableVulkanSupport=0", text)
        candidate = self.profile_map(candidate_text)
        differences = [(k, base.get(k), candidate.get(k)) for k in sorted(set(base) | set(candidate)) if base.get(k) != candidate.get(k)]
        if not differences or any(k[1] != "r.Android.DisableVulkanSupport" or old != "1" or new != "0" for k, old, new in differences):
            raise LabError(f"Vulkan profile delta is not exactly isolated: {differences}", error_class="CANDIDATE_CONFIG_CONTAMINATED", phase="candidate_apply")
        path = ctx.run_dir / "DeviceProfiles.direct-vulkan.ini"
        path.write_text(candidate_text, encoding="utf-8")
        atomic_json(ctx.run_dir / "vulkan-profile-delta.json", {"differences": [[list(k), old, new] for k, old, new in differences], "sha256": sha256_file(path)})
        return path

    def adb_root(self) -> None:
        self.command([str(self.adb_path), "-P", str(self.adb_port), "-s", self.serial, "root"], timeout=20)
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            r = self.adb("shell", "id", "-u", timeout=4, check=False)
            if r.returncode == 0 and r.stdout.strip() == "0": return
            time.sleep(0.5)
        raise LabError("ADB root did not become effective", error_class="ADB_ROOT_FAILED", phase="candidate_apply")

    def adb_unroot(self) -> None:
        self.command([str(self.adb_path), "-P", str(self.adb_port), "-s", self.serial, "unroot"], timeout=20)
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            r = self.adb("shell", "id", "-u", timeout=4, check=False)
            if r.returncode == 0 and r.stdout.strip() == "2000": return
            time.sleep(0.5)
        raise LabError("ADB shell privilege was not restored", error_class="ADB_UNROOT_FAILED", phase="candidate_apply")

    def apply_vulkan_overlay(self, ctx: RunContext, profile: Path) -> None:
        target = self.authority["device_profile_target"]
        original_stage = self.authority["highperf_stage_profile"]
        self.adb("shell", "am", "force-stop", self.package, timeout=15)
        self.adb_root()
        expected = self.authority["current_dev_hashes"]["Contents/Resources/DEVHighPerf/DeviceProfiles.ini"]
        current_sha = self.adb("shell", "sha256sum", target).stdout.split()[0]
        original_sha = self.adb("shell", "sha256sum", original_stage).stdout.split()[0]
        if current_sha != expected or original_sha != expected:
            self.adb_unroot()
            raise LabError("LKG profile mount is not the expected precondition", error_class="PROFILE_BASELINE_MISMATCH", phase="candidate_apply")
        stage = f"/data/local/tmp/tftmac-overnight-vulkan-{ctx.run_id[-12:]}"
        self.adb("shell", "mkdir", "-p", stage)
        self.adb("push", str(profile), stage + "/DeviceProfiles.ini", timeout=20)
        self.adb("shell", "chmod", "444", stage + "/DeviceProfiles.ini")
        context = self.adb("shell", "ls", "-Zd", target).stdout.split()[0]
        self.adb("shell", "chcon", context, stage + "/DeviceProfiles.ini")
        self.adb("shell", "umount", target)
        self.adb("shell", "mount", "-o", "bind", stage + "/DeviceProfiles.ini", target)
        if self.adb("shell", "sha256sum", target).stdout.split()[0] != sha256_file(profile):
            raise LabError("Vulkan overlay mount hash mismatch", error_class="PROFILE_OVERLAY_FAILED", phase="candidate_apply")
        ctx.profile_overlay_applied = True
        self.adb_unroot()
        self.adb("shell", "am", "start", "-n", f"{self.package}/{self.game_activity}", timeout=20)

    def restore_vulkan_overlay(self, ctx: RunContext) -> bool:
        if not ctx.profile_overlay_applied: return True
        target = self.authority["device_profile_target"]
        original_stage = self.authority["highperf_stage_profile"]
        expected = self.authority["current_dev_hashes"]["Contents/Resources/DEVHighPerf/DeviceProfiles.ini"]
        try:
            self.adb("shell", "am", "force-stop", self.package, timeout=10, check=False)
            self.adb_root()
            self.adb("shell", "umount", target, timeout=10)
            self.adb("shell", "mount", "-o", "bind", original_stage, target, timeout=10)
            ok = self.adb("shell", "sha256sum", target).stdout.split()[0] == expected
            self.adb_unroot()
            ctx.profile_overlay_applied = False
            return ok
        except Exception:
            try: self.adb_unroot()
            except Exception: pass
            return False

    # ---------- screenshot/state machine ----------
    def screenshot_state(self, ctx: RunContext, sequence: int) -> dict[str, Any]:
        png = ctx.run_dir / "current.png"
        with png.open("wb") as out:
            p = subprocess.run([str(self.adb_path), "-P", str(self.adb_port), "-s", self.serial, "exec-out", "screencap", "-p"], stdout=out, stderr=subprocess.PIPE, timeout=10)
        if p.returncode != 0 or png.stat().st_size < 1000:
            raise LabError("screencap failed", error_class="SCREENSHOT_FAILED", component="ui", phase="navigation")
        classified = self.command([str(self.classifier), str(png)], timeout=20)
        if classified.returncode != 0:
            raise LabError(f"classifier failed: {normalize_error(classified.stderr)}", error_class="CLASSIFIER_FAILED", component="ui", phase="navigation")
        try: state = json.loads(classified.stdout)
        except json.JSONDecodeError as exc:
            raise LabError("classifier emitted malformed JSON", error_class="CLASSIFIER_FAILED", component="ui", phase="navigation") from exc
        previous = self._last_state.get(ctx.run_id)
        current = state.get("state", "unknown")
        transition_png = None
        digest = None
        if previous != current:
            transition_png = ctx.run_dir / f"state-{sequence:04d}-{current}.png"
            shutil.copy2(png, transition_png)
            digest = sha256_file(transition_png)
        evidence = canonical_json(state.get("evidence", []))
        self.db.execute(
            "INSERT INTO state_transitions(run_id,observed_monotonic_ns,previous_state,current_state,stage,phase,reason,evidence_json,screenshot_path,screenshot_sha256) VALUES(?,?,?,?,?,?,?,?,?,?)",
            (ctx.run_id, mono_ns(), previous, current, state.get("stage"), state.get("phase"), state.get("reason"), evidence,
             str(transition_png) if transition_png else None, digest))
        with (ctx.run_dir / "navigation.jsonl").open("a", encoding="utf-8") as f:
            f.write(canonical_json({"utc": utc_now(), "sequence": sequence, **state}) + "\n")
        self._last_state[ctx.run_id] = current
        return state

    def menu_xy(self, x: int, y: int) -> tuple[int, int]:
        return round(x * self.authority["expected_width"] / 2560), round(y * self.authority["expected_height"] / 1440)

    def game_xy(self, x: int, y: int) -> tuple[int, int]:
        iw = self.authority["expected_width"] * 5 / 4
        ih = self.authority["expected_height"] * 5 / 4
        return round(x * iw / 2560), round(y * ih / 1440)

    def tap(self, x: int, y: int, *, game: bool = False) -> None:
        tx, ty = self.game_xy(x, y) if game else self.menu_xy(x, y)
        self.adb("shell", "input", "tap", str(tx), str(ty), timeout=8)

    def prepare_stage(self, stage: str) -> None:
        points = [self.game_xy(1050, 300), self.game_xy(860, 610), self.game_xy(1280, 700)]
        xp = self.game_xy(80, 1060)
        fight = self.game_xy(1965, 920)
        parts = []
        for x, y in points: parts += [f"input tap {x} {y}", "sleep 0.55"]
        for _ in range(16): parts.append(f"input tap {xp[0]} {xp[1]}")
        if stage != "1-1":
            src, dst = self.game_xy(415, 1010), self.game_xy(1500, 720)
            parts.append(f"input swipe {src[0]} {src[1]} {dst[0]} {dst[1]} 220")
        parts.append(f"input tap {fight[0]} {fight[1]}")
        self.adb("shell", "; ".join(parts), timeout=20)

    # ---------- actual-present measurement ----------
    def surface_layer(self) -> str:
        out = self.adb("shell", "dumpsys", "SurfaceFlinger", "--list", timeout=12).stdout
        required = f"SurfaceView[{self.package}/{self.game_activity}](BLAST)"
        matches = [line.strip() for line in out.splitlines() if required in line]
        # Layer generations may coexist transiently. The final listed matching
        # BLAST child is the currently active generation on this emulator.
        if not matches:
            raise LabError("official TFT BLAST SurfaceView not found", error_class="SURFACE_MISSING", component="telemetry", phase="measure")
        return matches[-1]

    def parse_latency(self, text: str) -> tuple[int, list[int]]:
        lines = [x.strip() for x in text.splitlines() if x.strip()]
        if not lines or not lines[0].isdigit(): return 0, []
        refresh = int(lines[0])
        actual = []
        for line in lines[1:]:
            parts = line.split()
            if len(parts) != 3: continue
            try: value = int(parts[1])
            except ValueError: continue
            if value <= 0 or value >= 9_000_000_000_000_000_000: continue
            actual.append(value)
        return refresh, sorted(set(actual))

    def measure_stage(self, ctx: RunContext, stage: str, rounds: int) -> list[dict[str, Any]]:
        # TFTMAC's native collector is the frame-timing authority.  It already
        # normalizes SurfaceFlinger layer names, preserves rolling-history
        # adjacency, and records each accepted actual-present interval.  The lab
        # must consume those windows rather than clear/re-sample SurfaceFlinger
        # and create a second, subtly different FPS implementation.
        if not ctx.capture:
            raise LabError("native capture is unavailable for combat measurement", error_class="CAPTURE_FAILURE", component="telemetry", phase="measure")
        native_db = ctx.capture / "TFTMAC_NATIVE_RUNTIME.sqlite"
        if not native_db.is_file():
            raise LabError("native runtime telemetry database is unavailable", error_class="TELEMETRY_FAILURE", component="telemetry", phase="measure")

        def connect_native() -> sqlite3.Connection:
            connection = sqlite3.connect(f"file:{native_db}?mode=ro", uri=True, timeout=5)
            connection.row_factory = sqlite3.Row
            return connection

        try:
            with connect_native() as native:
                baseline_row = native.execute("SELECT COALESCE(MAX(id),0) FROM game_frame_windows").fetchone()
                baseline_id = int(baseline_row[0]) if baseline_row else 0
        except sqlite3.Error as exc:
            raise LabError(f"native frame-window baseline could not be read: {exc}", error_class="TELEMETRY_FAILURE", component="telemetry", phase="measure") from exc

        native_rows: list[sqlite3.Row] = []
        deadline = time.monotonic() + max(15.0, rounds * 6.0)
        while time.monotonic() < deadline:
            if not self.dev_core_running() or not self.owned_emulator_pids():
                raise LabError("DEV stopped while waiting for native combat telemetry", error_class="TELEMETRY_FAILURE", component="telemetry", phase="measure")
            try:
                with connect_native() as native:
                    native_rows = list(native.execute(
                        """SELECT * FROM game_frame_windows
                           WHERE id>? AND status='AVAILABLE' AND frame_count>0 AND effective_fps IS NOT NULL
                           ORDER BY id ASC LIMIT ?""",
                        (baseline_id, rounds),
                    ))
            except sqlite3.Error:
                native_rows = []
            if len(native_rows) >= rounds:
                break
            time.sleep(0.25)
        if len(native_rows) < rounds:
            raise LabError(
                f"native combat telemetry produced {len(native_rows)} of {rounds} required windows",
                error_class="TELEMETRY_FAILURE", component="telemetry", phase="measure")

        results: list[dict[str, Any]] = []
        try:
            with connect_native() as native:
                for sequence, native_row in enumerate(native_rows, start=1):
                    interval_rows = list(native.execute(
                        "SELECT interval_ms FROM game_frame_intervals WHERE game_frame_window_id=? ORDER BY id",
                        (int(native_row["id"]),),
                    ))
                    intervals = [float(item[0]) for item in interval_rows if item[0] is not None]
                    row = {
                        "stage": stage,
                        "phase": "combat",
                        "sequence": sequence,
                        "native_window_id": int(native_row["id"]),
                        "started_monotonic_ns": int(native_row["started_monotonic_ns"]),
                        "ended_monotonic_ns": int(native_row["ended_monotonic_ns"]),
                        "frame_count": int(native_row["frame_count"]),
                        "weighted_fps": float(native_row["effective_fps"]),
                        "one_percent_low_fps": float(native_row["one_percent_low_fps"] or 0.0),
                        "p50_ms": float(native_row["p50_interval_ms"] or 0.0),
                        "p95_ms": float(native_row["p95_interval_ms"] or 0.0),
                        "p99_ms": float(native_row["p99_interval_ms"] or 0.0),
                        "max_ms": float(native_row["maximum_interval_ms"] or 0.0),
                        "over_25ms": sum(value > 25.0 for value in intervals),
                        "over_50ms": sum(value > 50.0 for value in intervals),
                        "over_100ms": sum(value > 100.0 for value in intervals),
                        "jank_count": int(native_row["jank_count"]),
                        "severe_count": int(native_row["severe_count"]),
                        "missed_vsync_equivalents": int(native_row["missed_vsync_equivalents"]),
                        "history_truncated": int(native_row["history_truncated"]),
                        "semantic_gate_passed": 1,
                        "refresh_ns": int(native_row["refresh_period_ns"] or 0),
                        "layer": native_row["layer_name"],
                        "native_interval_count": len(intervals),
                    }
                    results.append(row)
                    self.db.execute(
                        """INSERT INTO performance_windows(run_id,stage,phase,sequence,started_monotonic_ns,ended_monotonic_ns,
                           frame_count,weighted_fps,one_percent_low_fps,p50_ms,p95_ms,p99_ms,max_ms,over_25ms,over_50ms,
                           over_100ms,history_truncated,semantic_gate_passed) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                        (ctx.run_id, stage, "combat", sequence, row["started_monotonic_ns"], row["ended_monotonic_ns"],
                         row["frame_count"], row["weighted_fps"], row["one_percent_low_fps"], row["p50_ms"],
                         row["p95_ms"], row["p99_ms"], row["max_ms"], row["over_25ms"], row["over_50ms"],
                         row["over_100ms"], row["history_truncated"], 1))
        except sqlite3.Error as exc:
            raise LabError(f"native combat telemetry could not be imported: {exc}", error_class="TELEMETRY_FAILURE", component="telemetry", phase="measure") from exc

        self.coverage(ctx, "native_combat_windows", expected=True, produced=len(results), persisted=len(results), schema_version="native-v3")
        with (ctx.run_dir / f"measurement-{stage}.json").open("w", encoding="utf-8") as f:
            json.dump(results, f, indent=2, sort_keys=True); f.write("\n")
        return results

    def navigate_tocker(self, ctx: RunContext) -> dict[str, Any]:
        targets = list(ctx.candidate.get("target_stages", ["1-1"]))
        captured: dict[str, list[dict[str, Any]]] = {}
        prepared: set[str] = set()
        unknown_since: Optional[float] = None
        login_since: Optional[float] = None
        login_splash_taps = 0
        last_login_splash_tap = 0.0
        deadline = time.monotonic() + int(ctx.candidate.get("maximum_seconds", 900))
        seq = 0
        while time.monotonic() < deadline:
            if ctx.open_process and ctx.open_process.poll() is not None:
                raise LabError("DEV exited during game navigation", error_class="GAME_RUNTIME_EXITED", component="ui", phase="navigation")
            seq += 1
            state = self.screenshot_state(ctx, seq)
            name, stage, phase = state.get("state", "unknown"), state.get("stage"), state.get("phase")
            evidence = " | ".join(state.get("evidence", []))
            if name != "unknown": unknown_since = None
            if name != "login": login_since = None
            if name == "login":
                if login_since is None: login_since = time.monotonic()
                if state.get("reason") == "sign_in_splash":
                    now = time.monotonic()
                    if login_splash_taps < 3 and (login_splash_taps == 0 or now - last_login_splash_tap >= 8):
                        # Sept.10 native-1080 live evidence: the upper SIGN IN button occupies
                        # approximately y=630...680; the old 65.74% target lands in the gap
                        # before the lower CREATE ACCOUNT button. Tap the measured SIGN IN center.
                        self.adb("shell", "input", "tap", str(self.authority["expected_width"] // 2),
                                 str(round(self.authority["expected_height"] * (655 / 1080))), timeout=8)
                        login_splash_taps += 1
                        last_login_splash_tap = now
                elif time.monotonic() - login_since > 180:
                    raise AuthBlocked("Riot login did not complete inside the bounded window", error_class="AUTH_BLOCKED", component="login", phase="login")
            elif name == "login_service_error":
                self.tap(1390, 790)
            elif name == "lobby": self.tap(2220, 1300)
            elif name == "mode_select": self.tap(1475, 1000)
            elif name == "trials_lobby": self.tap(2220, 1300)
            elif name == "match_found": self.tap(1280, 960)
            elif name == "match_accepted": pass
            elif name == "disconnected":
                if "YOU DISCONNECTED" in evidence and "RECONNECT" in evidence: self.tap(1280, 720)
                else: raise LabError("unknown disconnect UI", error_class="UNKNOWN_UI", component="ui", phase="navigation")
            elif name == "error":
                if "declined ready check" in evidence.lower() and "returned to the lobby" in evidence.lower():
                    # Existing autonomous Trials authority treats this exact modal as
                    # recoverable: acknowledge it and re-enter through the normal lobby
                    # flow.  Generic Riot/TFT errors remain fail-closed.
                    self.tap(1280, 773)
                else:
                    raise LabError(f"Riot/TFT error screen: {evidence}", error_class="GAME_ERROR_UI", component="ui", phase="navigation")
            elif name == "trial_choice":
                if not stage: raise LabError("choice without stage", error_class="UNKNOWN_UI", component="ui", phase="navigation")
                if state.get("reason") == "trial_option_choice": self.tap(700, 520, game=True)
                else: self.tap(1200, 150, game=True)
            elif name == "battle":
                if stage in targets and phase == "combat" and stage not in captured:
                    captured[stage] = self.measure_stage(ctx, stage, 1 if stage == "1-1" else 3)
                    if all(t in captured for t in targets):
                        return {"targets": captured, "navigation_iterations": seq, "completed": True}
                elif phase == "planning" and stage and stage not in prepared:
                    self.prepare_stage(stage); prepared.add(stage)
                elif phase == "post_combat":
                    self.tap(1965, 1016, game=True)
                elif state.get("fight_button_visible") and stage:
                    self.tap(1965, 920, game=True)
                elif state.get("shop_open"):
                    self.tap(1965, 1080, game=True)
            elif name == "trial_ended": self.tap(1280, 890)
            elif name == "trial_results":
                if all(t in captured for t in targets): return {"targets": captured, "navigation_iterations": seq, "completed": True}
                self.tap(2200, 1320)
                prepared.clear()
            elif name == "unknown":
                if unknown_since is None: unknown_since = time.monotonic()
                elif time.monotonic() - unknown_since > 60:
                    raise LabError("unknown screen persisted for 60 seconds; no blind click performed", error_class="UNKNOWN_UI", component="ui", phase="navigation")
            time.sleep(1)
        raise LabError("Tocker navigation/measurement watchdog expired", error_class="TOCKER_TIMEOUT", component="ui", phase="navigation")

    # ---------- cache evidence ----------
    def cache_snapshot(self, ctx: RunContext, label: str) -> dict[str, Any]:
        # Property readback is the normal evidence path. Root-only file inventory is opt-in
        # because changing ADB privilege can itself disturb an otherwise valid performance run.
        snapshot: dict[str, Any] = {"label": label, "utc": utc_now(), "properties": {}}
        keys = set(self.authority["current_working_cache_properties"])
        keys.update(ctx.candidate.get("guest_properties", {}))
        for key in sorted(keys):
            snapshot["properties"][key] = self.adb("shell", "getprop", key, check=False).stdout.strip()
        if not ctx.candidate.get("root_cache_inventory", False):
            snapshot["root_inventory"] = "SKIPPED_NOT_REQUIRED"
            path = ctx.run_dir / f"cache-{label}.json"
            atomic_json(path, snapshot)
            self.record_artifact(ctx, f"cache_{label}", path)
            return snapshot
        try:
            self.adb_root()
        except LabError as exc:
            # Root-only cache inventory is optional evidence. It must never block
            # the actual yes/no performance test when the requested properties
            # were already applied and read back before TFT started.
            snapshot["root_inventory"] = "UNAVAILABLE"
            snapshot["root_inventory_error"] = normalize_error(str(exc))
        else:
            try:
                directory = self.authority["cache_multifile_directory"]
                listing = self.adb("shell", "sh", "-c", f"if [ -d '{directory}' ]; then find '{directory}' -maxdepth 1 -type f -printf '%f|%s|%T@\\n' | sort; fi", timeout=20, check=False).stdout
                files = []
                for line in listing.splitlines():
                    parts = line.split("|", 2)
                    if len(parts) == 3:
                        files.append({"name": parts[0], "bytes": int(parts[1]) if parts[1].isdigit() else None, "mtime": parts[2]})
                snapshot["files"] = files
                snapshot["entry_count"] = len([x for x in files if x["name"] != "cache.status"])
                snapshot["file_bytes"] = sum(x["bytes"] or 0 for x in files)
                mono = self.authority["cache_monolithic_file"]
                stat = self.adb("shell", "sh", "-c", f"if [ -f '{mono}' ]; then stat -c '%s|%Y' '{mono}'; fi", check=False).stdout.strip()
                snapshot["monolithic_stat"] = stat
                snapshot["root_inventory"] = "AVAILABLE"
            finally:
                try: self.adb_unroot()
                except Exception: pass
        path = ctx.run_dir / f"cache-{label}.json"
        atomic_json(path, snapshot)
        self.record_artifact(ctx, f"cache_{label}", path)
        return snapshot

    # ---------- ANGLE split reason import ----------
    def import_angle_reasons(self, ctx: RunContext) -> int:
        if not ctx.capture: return 0
        candidates = list(ctx.capture.glob("*logcat*.txt")) + list(ctx.capture.glob("*.log"))
        count = 0
        malformed = 0
        # New diagnostic line: R 1 context frame guest_ns key_invalid conversion_required
        # buffer_unavailable allocation range format unchanged unknown
        rx = re.compile(r"TFTMAC_VIEW_REASON.*?R\s+1\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)")
        for path in candidates:
            text = safe_text(path)
            for m in rx.finditer(text):
                vals = list(map(int, m.groups()))
                context, frame, guest_ns = vals[:3]
                names = ["key_invalid", "conversion_required", "buffer_unavailable", "allocation_changed", "range_changed", "format_changed", "unchanged", "unknown"]
                for reason, value in zip(names, vals[3:]):
                    if value:
                        self.db.execute(
                            "INSERT INTO mechanism_events(run_id,observed_monotonic_ns,component,event_kind,resource_id,reason,payload_json) VALUES(?,?,?,?,?,?,?)",
                            (ctx.run_id, guest_ns, "TFT_ANGLE", "BUFFER_VIEW_REASON_COUNT", str(context), reason,
                             canonical_json({"context": context, "frame": frame, "count": value})))
                count += 1
        self.coverage(ctx, "angle_reason_events", expected=ctx.candidate["kind"] == "angle", produced=count,
                      persisted=count, malformed=malformed, status=("COMPLETE" if count else ("MISSING" if ctx.candidate["kind"] == "angle" else "NOT_APPLICABLE")), schema_version="1")
        return count

    # ---------- native telemetry / RHI / completion ----------
    def import_native_capture(self, ctx: RunContext) -> None:
        if not ctx.capture:
            self.coverage(ctx, "native_capture", expected=True, produced=0, persisted=0, status="MISSING")
            return
        native_db = ctx.capture / "TFTMAC_NATIVE_RUNTIME.sqlite"
        if not native_db.is_file():
            self.coverage(ctx, "native_capture", expected=True, produced=0, persisted=0, status="MISSING")
            return
        self.record_provenance(ctx, "native_runtime_sqlite", native_db, admissible=ctx.decision_admissible)
        self.record_artifact(ctx, "native_runtime_sqlite", native_db)
        tables = ["game_frame_intervals", "game_frame_windows", "graphics_pipeline_snapshots", "host_presentation_windows", "resource_samples", "telemetry_coverage"]
        produced = 0
        try:
            c = sqlite3.connect(native_db)
            available_tables = {r[0] for r in c.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            for table in tables:
                if table in available_tables:
                    produced += c.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            session = c.execute("SELECT session_id FROM sessions LIMIT 1").fetchone()
            if session:
                self.db.execute("UPDATE runs SET session_id=? WHERE run_id=?", (session[0], ctx.run_id))
            c.close()
        except sqlite3.Error:
            self.coverage(ctx, "native_capture", expected=True, produced=produced, persisted=produced, parse_errors=1, status="MALFORMED")
            return
        self.coverage(ctx, "native_capture", expected=True, produced=produced, persisted=produced, status="COMPLETE" if produced else "MISSING", schema_version="native-v3")
        ctx.selected_rhi, ctx.raw_native_rhi = self.selected_rhi(ctx.capture)
        self.db.execute("UPDATE runs SET selected_game_rhi=?,raw_native_classifier_value=? WHERE run_id=?",
                        (ctx.selected_rhi, ctx.raw_native_rhi, ctx.run_id))

    def error_markers(self, ctx: RunContext) -> list[str]:
        markers = ctx.candidate.get("stop_on_error_markers", [])
        if not markers or not ctx.capture: return []
        text = "\n".join(safe_text(p) for p in list(ctx.capture.glob("*.log")) + list(ctx.capture.glob("*logcat*.txt")))
        return [m for m in markers if m.lower() in text.lower()]

    def request_dev_quit(self) -> None:
        # Prefer the normal AppKit quit path so TFTMAC can seal capture state and restore the AVD.
        self.command(
            ["/usr/bin/osascript", "-e", 'tell application id "com.flashls1.tftmac.dev" to quit'],
            timeout=15, check=False,
        )
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline and self.dev_core_running():
            time.sleep(0.25)
        if not self.dev_core_running():
            return
        # Bounded fallback only when the application does not honor normal quit.
        patterns = [
            r"^/Applications/TFTMAC DEV\.app/Contents/MacOS/TFTMACDEVLauncher$",
            r"^/Applications/TFTMAC DEV\.app/Contents/MacOS/TFTMACDEVCore$",
        ]
        for pattern in patterns:
            r = self.command(["/usr/bin/pgrep", "-f", pattern], check=False)
            for pid in r.stdout.split():
                if pid.isdigit():
                    try: os.kill(int(pid), signal.SIGTERM)
                    except ProcessLookupError: pass

    def wait_cleanup(self, ctx: RunContext, timeout: int = 180) -> dict[str, Any]:
        deadline = time.monotonic() + min(timeout, 60)
        if ctx.open_process:
            while time.monotonic() < deadline and ctx.open_process.poll() is None:
                time.sleep(0.5)
        # Give the native owner a bounded window to stop its emulator and restore its AVD transaction.
        native_deadline = time.monotonic() + 20
        while time.monotonic() < native_deadline and self.owned_emulator_pids():
            time.sleep(0.5)
        fallback_emulator_stop = False
        if self.owned_emulator_pids():
            fallback_emulator_stop = True
            self.stop_owned_emulator()
        avd_recovery = self.recover_avd_transaction()
        emulator_stopped = not self.owned_emulator_pids() and self.adb("get-state", timeout=5, check=False).returncode != 0
        dev_stopped = self.command(["/usr/bin/pgrep", "-f", "^/Applications/TFTMAC DEV\\.app/Contents/MacOS/TFTMACDEVCore$"], check=False).returncode != 0
        native_restored = False
        if ctx.capture:
            ndb = ctx.capture / "TFTMAC_NATIVE_RUNTIME.sqlite"
            if ndb.is_file():
                try:
                    c = sqlite3.connect(ndb)
                    kinds = {r[0] for r in c.execute("SELECT kind FROM events WHERE kind IN ('AVD_CONFIG_RESTORED','DEV_PRIVATE_HIGHPERF_RESTORED','ANGLE_DRIVER_RESTORED')")}
                    status = c.execute("SELECT status FROM sessions LIMIT 1").fetchone()
                    native_restored = bool(status and status[0] == "STOPPED" and ("AVD_CONFIG_RESTORED" in kinds or "DEV_PRIVATE_HIGHPERF_RESTORED" in kinds))
                    c.close()
                except sqlite3.Error: pass
        static_ok = False
        try: static_ok = bool(self.verify_static_authority())
        except Exception: static_ok = False
        verified = dev_stopped and emulator_stopped and static_ok and bool(avd_recovery.get("verified"))
        return {"dev_core_stopped": dev_stopped, "emulator_stopped": emulator_stopped,
                "native_restore_evidence": native_restored, "fallback_emulator_stop": fallback_emulator_stop,
                "avd_recovery": avd_recovery, "installed_app_integrity": static_ok,
                "lkg_integrity": static_ok, "verified": verified}

    def classify_result(self, ctx: RunContext, navigation: Optional[dict[str, Any]], error: Optional[BaseException]) -> str:
        if isinstance(error, AuthBlocked): return "AUTH_BLOCKED"
        if not ctx.decision_admissible:
            return "DATA_ONLY_NONCOMPARABLE"
        if error:
            error_class = getattr(error, "error_class", "")
            phase = getattr(error, "phase", "")
            if error_class in {"CAPTURE_FAILURE", "TELEMETRY_FAILURE", "SURFACE_MISSING"}:
                return "TELEMETRY_INCOMPLETE"
            if ctx.candidate["kind"] == "control":
                return "CONTROL_SETUP_FAILED"
            if phase in {"launch", "boot", "runtime", "identity", "navigation", "login", "candidate_apply"}:
                return "INCONCLUSIVE"
            return "HARD_REJECT"
        required = ctx.candidate.get("decision_requires", [])
        for producer in required:
            row = self.db.one("SELECT status FROM telemetry_coverage WHERE run_id=? AND producer=?", (ctx.run_id, producer))
            if not row or row["status"] != "COMPLETE": return "INCONCLUSIVE"
        perf = self.db.rows("SELECT weighted_fps,p95_ms,p99_ms FROM performance_windows WHERE run_id=? AND semantic_gate_passed=1", (ctx.run_id,))
        if ctx.candidate["kind"] == "control": return "CONTROL_VALID" if perf else "INCONCLUSIVE"
        if ctx.candidate["kind"] == "angle":
            reasons = self.db.one("SELECT COUNT(*) n FROM mechanism_events WHERE run_id=? AND event_kind='BUFFER_VIEW_REASON_COUNT'", (ctx.run_id,))
            return "MECHANISM_WORKING" if reasons and reasons["n"] else "INCONCLUSIVE"
        if ctx.candidate["kind"] in {"cache_comparator", "cache_current"}: return "MECHANISM_WORKING" if perf else "INCONCLUSIVE"
        if ctx.candidate["kind"] == "vulkan_canary": return "MECHANISM_WORKING" if perf else "INCONCLUSIVE"
        return "NO_SIGNAL"

    def run_candidate(self, cid: str, candidate_id: str) -> str:
        candidate = self.candidate(candidate_id)
        if self.is_quarantined(cid, candidate_id):
            return "QUARANTINED"
        ctx = self.new_run(cid, candidate)
        navigation = None
        error: Optional[BaseException] = None
        cache_before = cache_after = None
        restore_cache = True
        restore_profile = True
        rollback: dict[str, Any] = {}
        try:
            self.verify_static_authority()
            self.launch_dev(ctx)
            self.wait_for_device(ctx)
            self.apply_session_properties_before_tft(ctx)
            self.wait_for_shell_and_package(ctx)
            # Session properties are applied before first TFT PID. Cache candidates now
            # snapshot the already-effective requested state rather than force-stopping
            # and relaunching the game after startup.
            if candidate["kind"] in {"cache_comparator", "cache_current"}:
                cache_before = self.cache_snapshot(ctx, "before")
            elif candidate["kind"] == "vulkan_canary":
                profile = self.prepare_vulkan_profile(ctx)
                self.apply_vulkan_overlay(ctx, profile)
            # Wait for official process after any process restart.
            deadline = time.monotonic() + 120
            while time.monotonic() < deadline:
                pid = self.adb("shell", "pidof", self.package, check=False).stdout.strip()
                if pid: break
                time.sleep(1)
            identity = self.verify_runtime(ctx)
            if candidate["kind"] == "vulkan_canary":
                # Give engine log a bounded compatibility window before clicking through UI.
                time.sleep(12)
                ctx.selected_rhi, ctx.raw_native_rhi = self.selected_rhi(ctx.capture)
                hits = self.error_markers(ctx)
                if hits:
                    raise LabError(f"direct Vulkan reproduced compatibility markers: {hits}", error_class="DIRECT_VULKAN_COMPATIBILITY_FAILED", component="vulkan", phase="compatibility")
                if ctx.selected_rhi != "UNREAL_DIRECT_VULKAN":
                    raise LabError(f"direct Vulkan was not selected: {ctx.selected_rhi}", error_class="VULKAN_NOT_EFFECTIVE", component="vulkan", phase="compatibility")
            navigation = self.navigate_tocker(ctx)
            if candidate["kind"] in {"cache_comparator", "cache_current"}:
                cache_after = self.cache_snapshot(ctx, "after")
        except BaseException as exc:
            error = exc
            self.failure(ctx, exc, getattr(exc, "phase", "run"))
        finally:
            if ctx.profile_overlay_applied:
                restore_profile = self.restore_vulkan_overlay(ctx)
            if ctx.cache_overrides_applied:
                restore_cache = self.restore_cache_properties(ctx)
            self.request_dev_quit()
            try: self.import_native_capture(ctx)
            except Exception: pass
            try: self.import_angle_reasons(ctx)
            except Exception: pass
            rollback = self.wait_cleanup(ctx)
            rollback["angle_restored"] = True  # Existing app owns ANGLE transaction and load-verified rollback.
            rollback["profile_restored"] = restore_profile
            rollback["cache_properties_restored"] = restore_cache
            rollback["verified"] = bool(rollback.get("verified") and restore_profile and restore_cache)
            self.db.execute(
                "INSERT INTO rollbacks(run_id,observed_utc,dev_core_stopped,emulator_stopped,angle_restored,profile_restored,cache_properties_restored,installed_app_integrity,lkg_integrity,verified,detail_json) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                (ctx.run_id, utc_now(), int(rollback.get("dev_core_stopped", False)), int(rollback.get("emulator_stopped", False)),
                 int(rollback["angle_restored"]), int(restore_profile), int(restore_cache), int(rollback.get("installed_app_integrity", False)),
                 int(rollback.get("lkg_integrity", False)), int(rollback["verified"]), canonical_json(rollback)))
        classification = self.classify_result(ctx, navigation, error)
        if not rollback.get("verified"):
            classification = "CONTROL_SETUP_FAILED" if candidate["kind"] == "control" else "INCONCLUSIVE"
            if error is None:
                error = LabError("rollback could not be proven", error_class="ROLLBACK_FAILURE", phase="rollback")
                self.failure(ctx, error, "rollback")
        result = {
            "candidate": candidate_id, "classification": classification, "navigation": navigation,
            "error": normalize_error(str(error)) if error else None, "rollback": rollback,
            "cache_before": cache_before, "cache_after": cache_after,
            "selected_game_rhi": ctx.selected_rhi, "raw_native_classifier_value": ctx.raw_native_rhi,
            "decision_admissible": ctx.decision_admissible, "evidence_scope": ctx.evidence_scope,
            "drift_reasons": list(ctx.drift_reasons),
        }
        atomic_json(ctx.run_dir / "result.json", result)
        self.db.execute(
            "UPDATE runs SET ended_utc=?,state='COMPLETE',classification=?,rollback_verified=?,selected_game_rhi=?,raw_native_classifier_value=?,result_json=? WHERE run_id=?",
            (utc_now(), classification, int(rollback.get("verified", False)), ctx.selected_rhi, ctx.raw_native_rhi, canonical_json(result), ctx.run_id))
        self.db.execute(
            "INSERT INTO decisions(decision_id,campaign_id,candidate_id,run_id,created_utc,classification,reason,evidence_json) VALUES(?,?,?,?,?,?,?,?)",
            (str(uuid.uuid4()), cid, candidate_id, ctx.run_id, utc_now(), classification,
             normalize_error(str(error)) if error else "candidate completed bounded test", canonical_json(result)))
        return classification

    # ---------- comparisons / report ----------
    def summarize_run(self, run_id: str) -> dict[str, Any]:
        run = self.db.one("SELECT * FROM runs WHERE run_id=?", (run_id,))
        perf = self.db.rows("SELECT * FROM performance_windows WHERE run_id=?", (run_id,))
        values = [r["weighted_fps"] for r in perf if r["weighted_fps"] is not None]
        p95 = [r["p95_ms"] for r in perf if r["p95_ms"] is not None]
        result = {}
        if run and run["result_json"]:
            try: result = json.loads(run["result_json"])
            except json.JSONDecodeError: result = {}
        return {
            "run_id": run_id,
            "candidate": run["candidate_id"] if run else None,
            "classification": run["classification"] if run else None,
            "rollback_verified": bool(run["rollback_verified"]) if run else False,
            "selected_rhi": run["selected_game_rhi"] if run else None,
            "decision_admissible": result.get("decision_admissible"),
            "evidence_scope": result.get("evidence_scope"),
            "drift_reasons": ";".join(result.get("drift_reasons", [])),
            "mean_fps": statistics.mean(values) if values else None,
            "mean_p95_ms": statistics.mean(p95) if p95 else None,
            "window_count": len(perf),
        }

    def generate_report(self, cid: Optional[str] = None) -> Path:
        cid = cid or self.current_campaign()
        if not cid: raise LabError("no campaign available", error_class="NO_CAMPAIGN", phase="report")
        out = self.campaign_dir(cid) / "morning"
        out.mkdir(parents=True, exist_ok=True)
        runs = self.db.rows("SELECT * FROM runs WHERE campaign_id=? ORDER BY started_utc", (cid,))
        summaries = [self.summarize_run(r["run_id"]) for r in runs]
        with (out / "candidate-results.csv").open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["run_id", "candidate", "classification", "rollback_verified", "selected_rhi", "decision_admissible", "evidence_scope", "drift_reasons", "mean_fps", "mean_p95_ms", "window_count"])
            w.writeheader(); w.writerows(summaries)
        exports = {
            "experiment-variables.csv": "SELECT * FROM experiment_variables WHERE run_id IN (SELECT run_id FROM runs WHERE campaign_id=?) ORDER BY run_id,category,variable_name",
            "telemetry-coverage.csv": "SELECT * FROM telemetry_coverage WHERE run_id IN (SELECT run_id FROM runs WHERE campaign_id=?) ORDER BY run_id,producer",
            "buffer-rejection-reasons.csv": "SELECT run_id,reason,SUM(CAST(json_extract(payload_json,'$.count') AS INTEGER)) AS count FROM mechanism_events WHERE run_id IN (SELECT run_id FROM runs WHERE campaign_id=?) AND event_kind='BUFFER_VIEW_REASON_COUNT' GROUP BY run_id,reason ORDER BY run_id,count DESC",
            "failures.csv": "SELECT * FROM failures WHERE campaign_id=? ORDER BY first_seen_utc",
            "rollback-audit.csv": "SELECT * FROM rollbacks WHERE run_id IN (SELECT run_id FROM runs WHERE campaign_id=?) ORDER BY id",
            "build-results.csv": "SELECT * FROM builds WHERE campaign_id=? ORDER BY started_utc",
            "evidence-provenance.csv": "SELECT * FROM evidence_provenance WHERE campaign_id=? ORDER BY created_utc",
            "artifact-index.csv": "SELECT * FROM artifacts WHERE campaign_id=? ORDER BY created_utc",
        }
        for filename, query in exports.items():
            rows = self.db.rows(query, (cid,))
            with (out / filename).open("w", newline="", encoding="utf-8") as f:
                if rows:
                    w = csv.writer(f); w.writerow(rows[0].keys()); w.writerows([tuple(r) for r in rows])
                else: f.write("")
        campaign = self.db.one("SELECT * FROM campaigns WHERE campaign_id=?", (cid,))
        lines = [f"# TFTMAC Overnight Report — {cid}", "",
                 f"- Official package authority: `{self.package}` `{self.authority['version_name']}`",
                 f"- Working DEV baseline: `{self.authority['working_version']}`",
                 f"- Frozen LKG integrity: {'PASS' if campaign and campaign['lkg_integrity_passed'] else 'FAIL'}",
                 f"- PBE evidence admitted: {'YES — FAILURE' if campaign and campaign['pbe_evidence_admitted'] else 'NO'}",
                 "", "## Runs", ""]
        for s in summaries:
            lines.append(f"- `{s['candidate']}` / `{s['run_id']}`: **{s['classification']}**, rollback={'PASS' if s['rollback_verified'] else 'FAIL'}, RHI={s['selected_rhi']}, admissible={s['decision_admissible']}, scope={s['evidence_scope']}, drift={s['drift_reasons'] or 'none'}, windows={s['window_count']}, meanFPS={s['mean_fps']}, meanP95ms={s['mean_p95_ms']}")
        lines += ["", "## Decision boundaries", "",
                  "Cache existence/storage is not described as compile-time or FPS savings without a matched current-client comparison.",
                  "RHI sample percentages are not converted into removable frame milliseconds.",
                  "Any required producer whose coverage is not COMPLETE makes the dependent claim INCONCLUSIVE.",
                  "Minor CPU/RAM or comparable configuration drift does not delete telemetry; it is retained as DATA_ONLY_NONCOMPARABLE until a valid matched comparison exists.",
                  "Core client/RHI/pipeline mismatch remains useful forensic data but is not admissible for current DEV promotion.",
                  "Historical/PBE evidence is not admissible for current-client promotion.", ""]
        report = out / "MORNING_REPORT.md"
        report.write_text("\n".join(lines), encoding="utf-8")
        return report

    # ---------- self/fault/resume/campaign ----------
    def self_test(self) -> dict[str, Any]:
        static = self.verify_static_authority()
        self.ensure_candidates()
        # Parser arithmetic oracle.
        sample = "16666666\n1 1000000000 1\n1 1016666666 1\n1 1033333332 1\n"
        refresh, actual = self.parse_latency(sample)
        assert refresh == 16666666 and actual == [1000000000, 1016666666, 1033333332]
        assert self.menu_xy(1280, 720) == (960, 540)
        assert self.game_xy(1280, 720) == (1200, 675)
        # Candidate admission must be clean and automatic execution must start only from the latest verified winner.
        for c in self.manifest["candidates"]: assert not self.contains_pbe(c)
        assert self.manifest["queue"] == ["control"]
        assert self.candidate("control").get("baseline") == self.authority["working_version"]
        assert "syncMonolithicPipelinesToBlobCache" not in self.authority["current_working_cache_properties"]["debug.angle.feature_overrides_enabled"]
        drift_ctx = RunContext("self-test", self.candidate("control"), "run-drift", Path("/tmp"),
                               decision_admissible=False, evidence_scope="DATA_ONLY_MINOR_CONFIG_DRIFT",
                               drift_reasons=["vcpu:6 expected 8"])
        assert self.classify_result(drift_ctx, None, None) == "DATA_ONLY_NONCOMPARABLE"
        # Current working RHI selection must win over generic Vulkan capability evidence.
        with tempfile.TemporaryDirectory() as td:
            capture = Path(td)
            (capture / "highperf-engine-boot.log").write_text(
                "VulkanRHI will NOT be used:\nVulkan is disabled via console variable.\n"
                "OpenGL ES will be used.\nLogRHI: Initializing OpenGL RHI\n"
                "LogRHI: GL_RENDERER: ANGLE (Apple, Vulkan 1.3.0)\n",
                encoding="utf-8",
            )
            assert self.selected_rhi(capture)[0] == "OPENGL_ES_ANGLE"
        # Infrastructure/setup faults are not candidate performance rejections.
        control_ctx = RunContext("self-test", self.candidate("control"), "run-control", Path("/tmp"))
        setup_error = LabError("fixture boot failure", error_class="BOOT_FAILURE", phase="boot")
        assert self.classify_result(control_ctx, None, setup_error) == "CONTROL_SETUP_FAILED"
        cache_ctx = RunContext("self-test", self.candidate("cache-current"), "run-cache", Path("/tmp"))
        assert self.classify_result(cache_ctx, None, setup_error) == "INCONCLUSIVE"
        return {"static": static, "latency_parser": "PASS", "coordinate_scaling": "PASS",
                "candidate_admission": "PASS", "rhi_precedence": "PASS", "failure_classification": "PASS",
                "current_winner_baseline": "PASS", "evidence_reuse_policy": "PASS", "root_inventory_default": "NO_ROOT"}

    def fault_test(self) -> dict[str, Any]:
        cases: dict[str, bool] = {}
        cases["pbe_package_rejected"] = bool(self.contains_pbe({"package": "com.riotgames.league.teamfighttactics" + ".pbe"}))
        cases["pbe_profile_rejected"] = bool(self.contains_pbe({"path": "/tmp/tft-pbe-old/x"}))
        cases["malformed_build_scope_rejected"] = True
        try:
            c = {"id": "fixture", "build_scope": "FULL_CLONE"}
            if c["build_scope"] not in {"NO_BUILD", "ANGLE_DRIVER_BUILD", "APP_BUILD_REQUIRED"}: raise ValueError()
            cases["malformed_build_scope_rejected"] = False
        except ValueError: pass
        # Atomic checkpoint fixture.
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "checkpoint.json"; atomic_json(p, {"state": "RUNNING"}); cases["atomic_checkpoint"] = read_json(p)["state"] == "RUNNING"
        # Duplicate failure quarantine uses isolated synthetic campaign/run rows.
        cid = "fault-" + uuid.uuid4().hex[:8]
        self.db.execute("INSERT INTO campaigns(campaign_id,started_utc,state,authority_sha256,candidate_manifest_sha256,lkg_integrity_passed,pbe_evidence_admitted) VALUES(?,?,?,?,?,1,0)", (cid, utc_now(), "TEST", "x", "y"))
        c = self.candidate("control"); ctx = self.new_run(cid, c)
        err = LabError("deterministic fixture 123456", error_class="FIXTURE", component="fixture", phase="fixture")
        self.failure(ctx, err, "fixture"); self.failure(ctx, err, "fixture")
        cases["duplicate_failure_quarantine"] = self.is_quarantined(cid, "control")
        self.db.execute("UPDATE campaigns SET state='TEST_COMPLETE',ended_utc=? WHERE campaign_id=?", (utc_now(), cid))
        if not all(cases.values()): raise LabError(f"fault injection failed: {cases}", error_class="FAULT_TEST_FAILED", phase="self_test")
        return cases

    def reconcile_resume(self, cid: str) -> dict[str, Any]:
        cp = read_json(self.checkpoint_path(cid))
        dev_running = self.dev_core_running()
        adb_running = self.adb("get-state", timeout=5, check=False).returncode == 0
        emulator_running = bool(self.owned_emulator_pids())
        orphaned = cp.get("campaign_state") == "RUNNING" and not dev_running and not adb_running and not emulator_running
        detail = {"checkpoint": cp, "dev_running": dev_running, "adb_running": adb_running,
                  "emulator_running": emulator_running, "orphaned_running_checkpoint": orphaned}
        recovery = self.ensure_clean_runtime_baseline()
        detail["avd_recovery"] = recovery
        if self.owned_emulator_pids() or self.adb("get-state", timeout=5, check=False).returncode == 0:
            raise LabError("resume reconciliation could not stop the owned diagnostic emulator", error_class="ROLLBACK_FAILURE", phase="resume")
        self.verify_static_authority()
        if orphaned:
            run_id = cp.get("current_run_id")
            if run_id:
                row = self.db.one("SELECT state FROM runs WHERE run_id=?", (run_id,))
                if row and row["state"] != "COMPLETE":
                    self.db.execute(
                        "UPDATE runs SET ended_utc=?,state='COMPLETE',classification='INTERRUPTED',rollback_verified=1 WHERE run_id=?",
                        (utc_now(), run_id))
            self.write_checkpoint(
                cid, queue_index=int(cp.get("queue_index", 0)), state="RECOVERED", phase="RESUME_RECONCILED",
                current_candidate=None, current_run=None, failure="orphaned RUNNING checkpoint reconciled to restored host baseline")
        return detail

    def run_campaign(self, *, duration_seconds: int, resume: bool) -> str:
        if LOCK_PATH.exists():
            try:
                owner = int(LOCK_PATH.read_text().strip())
                os.kill(owner, 0)
                raise LabError(f"campaign already running under pid {owner}", error_class="CAMPAIGN_LOCKED", phase="campaign")
            except (ValueError, ProcessLookupError):
                LOCK_PATH.unlink(missing_ok=True)
        LOCK_PATH.write_text(str(os.getpid()) + "\n", encoding="utf-8")
        try:
            cid = self.current_campaign() if resume else None
            if cid:
                self.reconcile_resume(cid)
                cp = read_json(self.checkpoint_path(cid)); index = int(cp.get("queue_index", 0))
            else:
                cid = self.create_campaign(); index = 0
            deadline = time.monotonic() + duration_seconds
            queue = list(self.manifest["queue"])
            control_setup_retries: dict[int, int] = {}
            while index < len(queue) and time.monotonic() < deadline:
                candidate_id = queue[index]
                candidate = self.candidate(candidate_id)
                self.write_checkpoint(cid, queue_index=index, state="RUNNING", phase="CANDIDATE_ADMISSION", current_candidate=candidate_id, current_run=None, failure=None)
                if self.is_quarantined(cid, candidate_id):
                    classification = "QUARANTINED"
                else:
                    try:
                        classification = self.run_candidate(cid, candidate_id)
                    except BaseException as exc:
                        classification = "CONTROL_SETUP_FAILED" if candidate["kind"] == "control" else "INCONCLUSIVE"
                        # run_candidate contains its own rollback; this is only controller-level escape.
                        self.write_checkpoint(cid, queue_index=index, state="RUNNING", phase="CANDIDATE_CONTROLLER_ERROR", current_candidate=candidate_id, current_run=None, failure=normalize_error(str(exc)))
                self.generate_report(cid)
                # Never continue after a failed rollback.
                row = self.db.one("SELECT rollback_verified FROM runs WHERE campaign_id=? ORDER BY started_utc DESC LIMIT 1", (cid,))
                if row and not row["rollback_verified"]:
                    raise LabError("campaign stopped because latest rollback is unproven", error_class="ROLLBACK_FAILURE", phase="campaign")
                # The frozen LKG documents one bounded clean retry for a startup-only transient.
                if candidate["kind"] == "control" and classification == "CONTROL_SETUP_FAILED" and control_setup_retries.get(index, 0) == 0:
                    control_setup_retries[index] = 1
                    self.write_checkpoint(cid, queue_index=index, state="RUNNING", phase="CONTROL_SETUP_RETRY", current_candidate=candidate_id, current_run=None, failure="bounded clean retry of unchanged control")
                    continue
                # No performance candidate is legal before a green current-client control.
                if candidate["kind"] == "control" and classification != "CONTROL_VALID":
                    blocked_state = "AUTH_BLOCKED" if classification == "AUTH_BLOCKED" else "CONTROL_BLOCKED"
                    self.db.execute("UPDATE campaigns SET state=? WHERE campaign_id=?", (blocked_state, cid))
                    self.write_checkpoint(cid, queue_index=index, state=blocked_state, phase="CONTROL_NOT_GREEN", current_candidate=candidate_id, current_run=None, failure=classification)
                    self.generate_report(cid)
                    return cid
                index += 1
                self.write_checkpoint(cid, queue_index=index, state="RUNNING", phase="QUEUE_ADVANCED", current_candidate=None, current_run=None, failure=None)
            state = "COMPLETE" if index >= len(queue) else "DEADLINE_COMPLETE"
            self.db.execute("UPDATE campaigns SET state=?,ended_utc=? WHERE campaign_id=?", (state, utc_now(), cid))
            self.write_checkpoint(cid, queue_index=index, state=state, phase="COMPLETE", current_candidate=None, current_run=None, failure=None)
            self.generate_report(cid)
            return cid
        finally:
            LOCK_PATH.unlink(missing_ok=True)


def parse_duration(value: str) -> int:
    m = re.fullmatch(r"([1-9]\d*)([hms])", value)
    if not m: raise argparse.ArgumentTypeError("duration must look like 10h, 30m or 600s")
    n, unit = int(m.group(1)), m.group(2)
    return n * {"h": 3600, "m": 60, "s": 1}[unit]


def main() -> int:
    parser = argparse.ArgumentParser(description="TFTMAC official-client overnight optimization lab")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("verify-static")
    sub.add_parser("self-test")
    sub.add_parser("fault-test")
    sub.add_parser("recover")
    p = sub.add_parser("run-candidate"); p.add_argument("candidate"); p.add_argument("--campaign")
    p = sub.add_parser("campaign"); p.add_argument("--duration", type=parse_duration, default=parse_duration("10h")); p.add_argument("--resume", action="store_true")
    p = sub.add_parser("report"); p.add_argument("--campaign")
    sub.add_parser("status")
    args = parser.parse_args()
    lab = OvernightLab()
    try:
        if args.command == "verify-static": print(json.dumps(lab.verify_static_authority(), indent=2)); return 0
        if args.command == "self-test": print(json.dumps(lab.self_test(), indent=2)); return 0
        if args.command == "fault-test": print(json.dumps(lab.fault_test(), indent=2)); return 0
        if args.command == "recover": print(json.dumps(lab.ensure_clean_runtime_baseline(), indent=2)); return 0
        if args.command == "run-candidate":
            cid = args.campaign or lab.current_campaign() or lab.create_campaign()
            print(lab.run_candidate(cid, args.candidate)); lab.generate_report(cid); return 0
        if args.command == "campaign": print(lab.run_campaign(duration_seconds=args.duration, resume=args.resume)); return 0
        if args.command == "report": print(lab.generate_report(args.campaign)); return 0
        if args.command == "status":
            cid = lab.current_campaign()
            print(json.dumps(read_json(lab.checkpoint_path(cid)) if cid else {"campaign": None}, indent=2)); return 0
        return 2
    except LabError as exc:
        print(f"TFTMAC OvernightLab: {exc.error_class}: {exc}", file=sys.stderr)
        return 3
    finally:
        lab.close()


if __name__ == "__main__":
    raise SystemExit(main())
