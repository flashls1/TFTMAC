#!/usr/bin/env python3
"""TFTMAC Riot update evidence recorder.

Captures stopped-app package/data manifests around Google Play + Riot update transitions
and emits complete readable-file diffs. It never modifies Riot package bytes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

PACKAGE = "com.riotgames.league.teamfighttactics"
PBE = "com.riotgames.league.teamfighttactics.pbe"
DEFAULT_ADB = "/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK/platform-tools/adb"
DEFAULT_SERVER_PORT = "5041"
DEFAULT_SERIAL = "emulator-5586"
DEFAULT_ROOT = Path.home() / "Library/Application Support/TFTMAC/Modes/advanced_diagnostics/RiotUpdateAudits"
PHASES = ("PRE_UPDATE", "POST_PLAY_UPDATE", "POST_RIOT_INIT")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def run(cmd: list[str], *, check: bool = True, timeout: int = 120, binary: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=check, timeout=timeout, capture_output=True, text=not binary)


class Audit:
    def __init__(self, args: argparse.Namespace):
        self.adb_bin = args.adb
        self.server_port = str(args.adb_server_port)
        self.serial = args.serial
        self.root = Path(args.output_root).expanduser()
        self.audit_id = args.audit_id
        self.audit_dir = self.root / self.audit_id
        self.audit_dir.mkdir(parents=True, exist_ok=True)

    def adb_cmd(self, *args: str) -> list[str]:
        return [self.adb_bin, "-P", self.server_port, "-s", self.serial, *args]

    def adb(self, *args: str, check: bool = True, timeout: int = 120) -> subprocess.CompletedProcess:
        return run(self.adb_cmd(*args), check=check, timeout=timeout)

    def wait_uid(self, expected: str, timeout: float = 30.0) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                self.adb("wait-for-device", timeout=5)
                uid = self.adb("shell", "id", "-u", check=False, timeout=5).stdout.strip()
                if uid == expected:
                    return True
            except Exception:
                pass
            time.sleep(0.5)
        return False

    def install_source(self, package: str) -> str:
        return self.adb("shell", "pm", "list", "packages", "-i", package, check=False, timeout=20).stdout.strip()

    @staticmethod
    def parse_package_dump(text: str) -> dict[str, Any]:
        vm = re.search(r"versionName=([^\s]+)", text)
        vc = re.search(r"versionCode=(\d+)", text)
        first = re.search(r"firstInstallTime=([^\n]+)", text)
        last = re.search(r"lastUpdateTime=([^\n]+)", text)
        return {
            "version_name": vm.group(1) if vm else None,
            "version_code": int(vc.group(1)) if vc else None,
            "first_install_time": first.group(1).strip() if first else None,
            "last_update_time": last.group(1).strip() if last else None,
        }

    def package_paths(self, package: str) -> list[str]:
        out = self.adb("shell", "pm", "path", package, check=False, timeout=30).stdout
        return [line.split("package:", 1)[1].strip() for line in out.splitlines() if line.startswith("package:")]

    def pull_apk(self, remote: str, local: Path) -> None:
        local.parent.mkdir(parents=True, exist_ok=True)
        pulled = self.adb("pull", remote, str(local), check=False, timeout=300)
        if pulled.returncode == 0 and local.exists() and local.stat().st_size > 0:
            return
        proc = run(self.adb_cmd("exec-out", "cat", remote), check=False, timeout=300, binary=True)
        if proc.returncode != 0 or not proc.stdout:
            raise RuntimeError(f"could not read package split: {remote}")
        local.write_bytes(proc.stdout)

    @staticmethod
    def sha256_path(path: Path) -> str:
        h = hashlib.sha256()
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()

    def inventory_apks(self, phase_dir: Path, paths: list[str]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
        apk_meta: list[dict[str, Any]] = []
        entries: dict[str, Any] = {}
        apk_dir = phase_dir / "apk-copies"
        for idx, remote in enumerate(paths):
            base = Path(remote).name or f"split-{idx}.apk"
            local = apk_dir / f"{idx:03d}-{base}"
            self.pull_apk(remote, local)
            meta = {
                "remote_path": remote,
                "local_evidence_path": str(local),
                "size": local.stat().st_size,
                "sha256": self.sha256_path(local),
            }
            apk_meta.append(meta)
            try:
                with zipfile.ZipFile(local) as zf:
                    for info in zf.infolist():
                        if info.is_dir():
                            continue
                        key = f"{base}!/{info.filename}"
                        h = hashlib.sha256()
                        with zf.open(info) as src:
                            for chunk in iter(lambda: src.read(1024 * 1024), b""):
                                h.update(chunk)
                        entries[key] = {
                            "container": base,
                            "path": info.filename,
                            "size": info.file_size,
                            "compressed_size": info.compress_size,
                            "crc32": f"{info.CRC:08x}",
                            "sha256": h.hexdigest(),
                        }
            except zipfile.BadZipFile:
                entries[f"{base}!/<NON_ZIP_PAYLOAD>"] = {
                    "container": base,
                    "path": "<NON_ZIP_PAYLOAD>",
                    "size": local.stat().st_size,
                    "sha256": meta["sha256"],
                }
        return apk_meta, entries

    def inventory_data_files(self) -> tuple[dict[str, Any], dict[str, Any]]:
        roots = [
            f"/data/user/0/{PACKAGE}",
            f"/data/user_de/0/{PACKAGE}",
            f"/sdcard/Android/data/{PACKAGE}",
        ]
        result: dict[str, Any] = {}
        notes: dict[str, Any] = {"root_requested": False, "root_effective": False, "errors": []}
        before_uid = self.adb("shell", "id", "-u", check=False, timeout=10).stdout.strip()
        if before_uid != "0":
            notes["root_requested"] = True
            self.adb("root", check=False, timeout=20)
            notes["root_effective"] = self.wait_uid("0", 30)
        else:
            notes["root_effective"] = True
        try:
            for root in roots:
                exists = self.adb("shell", "test", "-d", root, check=False, timeout=10).returncode == 0
                if not exists:
                    continue
                # Pass one complete remote-shell command to adb. Supplying
                # `sh`, `-c`, and the command as separate adb argv elements lets
                # adb re-join them without preserving the `-c` payload boundary;
                # the previous form could execute bare `find` from `/` and
                # silently inventory nothing from the requested Riot roots.
                hash_cmd = f"find '{root}' -type f -exec sha256sum {{}} +"
                size_cmd = f"find '{root}' -type f -exec stat -c '%s\t%n' {{}} +"
                hashes = self.adb("shell", hash_cmd, check=False, timeout=600)
                sizes = self.adb("shell", size_cmd, check=False, timeout=600)
                size_map: dict[str, int] = {}
                for line in sizes.stdout.splitlines():
                    try:
                        size, path = line.split("\t", 1)
                        size_map[path] = int(size)
                    except Exception:
                        continue
                for line in hashes.stdout.splitlines():
                    m = re.match(r"^([0-9a-fA-F]{64})\s+(.+)$", line)
                    if not m:
                        continue
                    path = m.group(2)
                    result[path] = {"path": path, "size": size_map.get(path), "sha256": m.group(1).lower()}
                if hashes.returncode != 0:
                    notes["errors"].append({"root": root, "hash_stderr": hashes.stderr.strip()})
        finally:
            if before_uid != "0":
                self.adb("unroot", check=False, timeout=20)
                notes["shell_restored"] = self.wait_uid("2000", 30)
        return result, notes

    def graphics_fingerprint(self) -> dict[str, Any]:
        props = [
            "ro.build.fingerprint", "ro.build.version.release", "ro.build.version.sdk",
            "ro.opengles.version", "debug.egl.blobcache.multifile",
            "debug.angle.feature_overrides_enabled", "debug.angle.feature_overrides_disabled",
            "debug.angle.capture.enabled", "debug.angle.capture.out_dir",
        ]
        values: dict[str, Any] = {}
        for prop in props:
            values[prop] = self.adb("shell", "getprop", prop, check=False, timeout=10).stdout.strip()
        for key in ["angle_gl_driver_all_angle", "angle_gl_driver_selection_pkgs", "angle_gl_driver_selection_values"]:
            values[f"settings.global.{key}"] = self.adb("shell", "settings", "get", "global", key, check=False, timeout=10).stdout.strip()
        values["resolved_main_activity"] = self.adb(
            "shell", "cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN",
            "-c", "android.intent.category.LAUNCHER", PACKAGE, check=False, timeout=20
        ).stdout.strip()
        return values

    def snapshot(self, phase: str) -> Path:
        if phase not in PHASES:
            raise ValueError(f"phase must be one of {PHASES}")
        phase_dir = self.audit_dir / phase
        snapshot_path = phase_dir / "snapshot.json"
        if snapshot_path.exists():
            raise RuntimeError(f"snapshot already exists: {snapshot_path}")
        if phase_dir.exists():
            # A transport loss may leave an incomplete phase directory before any
            # authoritative snapshot is sealed. Remove only that unsealed phase.
            import shutil
            shutil.rmtree(phase_dir)
        phase_dir.mkdir(parents=True)
        self.adb("wait-for-device", timeout=30)
        self.adb("shell", "am", "force-stop", PACKAGE, check=False, timeout=20)
        time.sleep(0.5)
        dump = self.adb("shell", "dumpsys", "package", PACKAGE, check=False, timeout=30).stdout
        pkg = self.parse_package_dump(dump)
        pkg["package_name"] = PACKAGE
        pkg["install_source_raw"] = self.install_source(PACKAGE)
        pkg["pbe_installed"] = bool(self.package_paths(PBE))
        paths = self.package_paths(PACKAGE)
        pkg["split_paths"] = paths
        apk_meta, apk_entries = self.inventory_apks(phase_dir, paths)
        data_files, data_notes = self.inventory_data_files()
        snap = {
            "schema": 1,
            "audit_id": self.audit_id,
            "phase": phase,
            "observed_utc": utc_now(),
            "package": pkg,
            "apk_files": apk_meta,
            "apk_entries": apk_entries,
            "data_files": data_files,
            "data_inventory": data_notes,
            "graphics_fingerprint": self.graphics_fingerprint(),
        }
        out = phase_dir / "snapshot.json"
        out.write_text(json.dumps(snap, indent=2, sort_keys=True) + "\n")
        return out

    @staticmethod
    def file_diff(before: dict[str, Any], after: dict[str, Any]) -> dict[str, Any]:
        keys = sorted(set(before) | set(after))
        rows = []
        counts = {"ADDED": 0, "REMOVED": 0, "MODIFIED": 0, "UNCHANGED": 0}
        for key in keys:
            a, b = before.get(key), after.get(key)
            if a is None:
                state = "ADDED"
            elif b is None:
                state = "REMOVED"
            elif a.get("sha256") != b.get("sha256") or a.get("size") != b.get("size"):
                state = "MODIFIED"
            else:
                state = "UNCHANGED"
            counts[state] += 1
            rows.append({
                "path": key, "state": state,
                "before_size": a.get("size") if a else None,
                "after_size": b.get("size") if b else None,
                "before_sha256": a.get("sha256") if a else None,
                "after_sha256": b.get("sha256") if b else None,
            })
        return {"counts": counts, "files": rows}

    def diff(self, before_phase: str, after_phase: str) -> Path:
        before = json.loads((self.audit_dir / before_phase / "snapshot.json").read_text())
        after = json.loads((self.audit_dir / after_phase / "snapshot.json").read_text())
        apk = self.file_diff(before.get("apk_entries", {}), after.get("apk_entries", {}))
        data = self.file_diff(before.get("data_files", {}), after.get("data_files", {}))
        changed_native = [row for row in apk["files"] if row["state"] != "UNCHANGED" and ("lib/arm64-v8a/" in row["path"] or row["path"].endswith(".so"))]
        out_doc = {
            "schema": 1,
            "audit_id": self.audit_id,
            "before_phase": before_phase,
            "after_phase": after_phase,
            "generated_utc": utc_now(),
            "package_before": before.get("package"),
            "package_after": after.get("package"),
            "graphics_fingerprint_before": before.get("graphics_fingerprint"),
            "graphics_fingerprint_after": after.get("graphics_fingerprint"),
            "apk_entry_diff": apk,
            "data_file_diff": data,
            "changed_native_libraries": changed_native,
        }
        diff_dir = self.audit_dir / "diffs"
        diff_dir.mkdir(exist_ok=True)
        out = diff_dir / f"{before_phase}__TO__{after_phase}.json"
        out.write_text(json.dumps(out_doc, indent=2, sort_keys=True) + "\n")
        return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--adb", default=DEFAULT_ADB)
    p.add_argument("--adb-server-port", type=int, default=int(DEFAULT_SERVER_PORT))
    p.add_argument("--serial", default=DEFAULT_SERIAL)
    p.add_argument("--output-root", default=str(DEFAULT_ROOT))
    p.add_argument("--audit-id", required=True)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("snapshot")
    s.add_argument("--phase", required=True, choices=PHASES)
    d = sub.add_parser("diff")
    d.add_argument("--before", required=True, choices=PHASES)
    d.add_argument("--after", required=True, choices=PHASES)
    args = p.parse_args()
    audit = Audit(args)
    if args.cmd == "snapshot":
        out = audit.snapshot(args.phase)
    else:
        out = audit.diff(args.before, args.after)
    print(json.dumps({"ok": True, "path": str(out), "audit_id": args.audit_id, "command": args.cmd}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
