#!/usr/bin/env python3
"""TURBO 2 identity preflight and exclusive candidate publication primitives.

CLI inspection is read-only. The source-only builder uses the explicit atomic
publication function after verification. No account migration or runtime launch.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import socket
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SIGNING_IDENTITY = "TFTMAC Local Code Signing"


class IsolationError(RuntimeError):
    """A proposed candidate violates the currently accepted boundary."""


def load_contract(root: Path = ROOT) -> dict[str, Any]:
    try:
        data = json.loads((root / "ssot/turbo2-isolation.json").read_text())
    except (OSError, ValueError) as exc:
        raise IsolationError("Cannot read the TURBO 2 isolation contract") from exc
    if not isinstance(data, dict):
        raise IsolationError("Isolation contract must be an object")
    return data


def _home_path(value: Any, home: Path) -> Path:
    if not isinstance(value, str) or not value:
        raise IsolationError("Missing home-relative path")
    p = Path(value)
    if p.is_absolute() or ".." in p.parts:
        raise IsolationError("Absolute or traversing contract path rejected")
    return home / p


def _no_symlink(path: Path) -> None:
    # Check dangling links too, and do not follow a parent alias into an original.
    for part in (path, *path.parents):
        if part.is_symlink():
            raise IsolationError("Symlink/alias path rejected: " + str(part))


def _overlap(left: Path, right: Path) -> bool:
    a, b = (str(p.resolve()).casefold().rstrip("/") for p in (left, right))
    return a == b or a.startswith(b + "/") or b.startswith(a + "/")


def protected_paths(home: Path, registry: dict[str, Any]) -> list[Path]:
    apps = [home / "Desktop" / name for name in (
        "TFT TURBO.app", "TFT Ranked.app", "TFTMAC.app", "TFTMAC DEV.app")]
    apps += [Path("/Applications") / name for name in (
        "TFTMAC.app", "TFTMAC DEV.app", "TFTMAC Control Launcher.app")]
    roots = [home / "Library/Application Support/TFTMAC/InternalRuntime/StockShadow",
             home / "Library/Application Support/TFTMAC/Modes/advanced_diagnostics"]
    for name, mode in registry.get("modes", {}).items():
        if name == "turbo2":
            continue  # Validated independently below; never protect it as an incumbent.
        for key in ("runtime_root", "sdk_root", "avd_home", "avd_directory"):
            if mode.get(key):
                roots.append(Path(mode[key]))
    return apps + roots


def inspect_contract(contract: dict[str, Any], registry: dict[str, Any],
                     output: Path | None = None, home: Path | None = None) -> dict[str, Any]:
    """Validate declarative identity. This function writes nothing."""
    home = (home or Path.home()).absolute()
    try:
        if contract["schema"] != 1 or contract["mode"] != "turbo2":
            raise IsolationError("Unsupported isolation contract")
        if (contract["launch_state"] != "blocked_not_built"
                or contract["native_integration"] != "build_only"):
            raise IsolationError("Build-only integration cannot declare a runtime ready")
        app = contract["application"]
        if (app["name"] != "TFT TURBO 2"
                or app["bundle_identifier"] != "com.flashls1.tftmac.turbo2"
                or app["forwarder_bundle_identifier"] != "com.flashls1.tftmac.turbo2.emulator-host"
                or app["forwarder_relative_path"] != "Contents/Resources/TFTMAC Emulator Host.app"
                or app["signing_identity"] != SIGNING_IDENTITY):
            raise IsolationError("Candidate application/signing identity mismatch")
        if contract["state_namespace"] != "turbo2":
            raise IsolationError("Candidate state must use its own namespace")
        paths = {k: _home_path(v, home) for k, v in contract["paths"].items()}
        runtime = home / "Library/Application Support/TFTMAC/Turbo2/StockShadow"
        support = home / "Library/Application Support/TFTMAC/Modes/turbo2"
        expected = {
            "application": home / "Desktop/TFT TURBO 2.app",
            "runtime_root": runtime, "sdk_root": runtime / "SDK",
            "avd_home": runtime / "AVD", "manifests": runtime / "Manifests",
            "state_root": support / "State", "captures": support / "Captures",
            "build_receipt": home / "Desktop/TFT TURBO 2.build-receipt.json",
        }
        if paths != expected:
            raise IsolationError("Candidate paths differ from the approved isolated layout")
        candidate = Path(output) if output is not None else paths["application"]
        if not candidate.is_absolute() or ".." in candidate.parts:
            raise IsolationError("Output must be an absolute non-traversing candidate path")
        if candidate != paths["application"]:
            raise IsolationError("Only the exact TFT TURBO 2.app output is allowed; originals are protected")
        for path in (*paths.values(), candidate):
            _no_symlink(path)
            if any(_overlap(path, p) for p in protected_paths(home, registry)):
                raise IsolationError("Candidate overlaps a protected application/runtime")
        if candidate.exists() and not candidate.is_dir():
            raise IsolationError("Candidate app path is not a directory")
        ports = contract["ports"]
        keys = {"adb_server", "emulator_console", "emulator_adb_transport", "authenticated_controller"}
        if set(ports) != keys or any(type(n) is not int or not 1024 <= n <= 65535 for n in ports.values()):
            raise IsolationError("Invalid candidate endpoint set")
        console = ports["emulator_console"]
        if console % 2 or not 5554 <= console <= 5682 or ports["emulator_adb_transport"] != console + 1:
            raise IsolationError("Emulator console/adjacent ADB transport pair is invalid")
        if len(set(ports.values())) != 4:
            raise IsolationError("Candidate endpoints collide")
        if set(registry["modes"]) != {"control", "advanced_diagnostics", "candidate", "turbo2"}:
            raise IsolationError("Unexpected native mode registry")
        native = registry["modes"]["turbo2"]
        required = {
            "mode": "turbo2", "launch_state": "blocked_not_built",
            "application_bundle_id": app["bundle_identifier"],
            "runtime_root": str(runtime), "sdk_root": str(paths["sdk_root"]),
            "avd_home": str(paths["avd_home"]), "avd_name": contract["avd_name"],
            "adb_server_port": ports["adb_server"], "console_port": ports["emulator_console"],
            "controller_port": ports["authenticated_controller"], "serial": contract["serial"],
            "state_namespace": "turbo2", "requires_control_stopped": True,
            "emulator_sha256": None, "gfxstream_backend_sha256": None,
        }
        if any(k not in native or native[k] != v for k, v in required.items()):
            raise IsolationError("Native TURBO 2 identity differs from its build-only contract")
        occupied = set()
        for name, mode in registry["modes"].items():
            if name == "turbo2":
                continue
            for key in ("adb_server_port", "console_port", "controller_port"):
                if mode.get(key) is not None:
                    occupied.add(mode[key])
            if mode.get("console_port") is not None:
                occupied.add(mode["console_port"] + 1)
        if occupied.intersection(ports.values()):
            raise IsolationError("Candidate port collides with an existing registered endpoint")
        if contract["serial"] != "emulator-" + str(console):
            raise IsolationError("Serial does not match the console endpoint")
        if contract["avd_name"] != "TFTMAC_Turbo2_StockShadow_R2":
            raise IsolationError("Unexpected candidate AVD identity")
        if any(m.get("avd_name") == contract["avd_name"] for n, m in registry["modes"].items() if n != "turbo2"):
            raise IsolationError("Candidate reuses an incumbent AVD identity")
        lease = "Library/Application Support/TFTMAC/State/native-runtime.lease"
        if (contract["exclusive_lease_home_relative"] != lease
                or registry["active_lease_relative_path"] != "State/native-runtime.lease"):
            raise IsolationError("The shared exclusive runtime lease must not change")
        if contract["controller"] != {"loopback_only": True, "authentication_required": True}:
            raise IsolationError("Authenticated loopback controller is required")
    except (KeyError, TypeError, AttributeError) as exc:
        raise IsolationError("Incomplete or malformed isolation contract") from exc
    return {
        "isolation_contract": "PASS", "read_only": True,
        "app": str(candidate), "bundle_identifier": app["bundle_identifier"],
        "paths": {k: str(v) for k, v in paths.items()}, "ports": dict(ports),
        "serial": contract["serial"], "avd_name": contract["avd_name"],
        "exclusive_lease": str(home / lease),
        "build_allowed": True, "launch_allowed": False,
        "native_integration": "BUILD_ONLY_RUNTIME_PENDING", "credential_access": "DEFERRED_TO_LOCAL_CODEX",
    }


def preflight(output: Path | None = None, root: Path = ROOT) -> dict[str, Any]:
    try:
        registry = json.loads((root / "ssot/runtime-modes.json").read_text())
    except (OSError, ValueError) as exc:
        raise IsolationError("Cannot read existing runtime registry") from exc
    report = inspect_contract(load_contract(root), registry, output)
    source = (root / "tftmac/Runtime/RuntimeMode.swift").read_text()
    expected = re.search(r'expectedRegistrySha256 = "([0-9a-f]{64})"', source)
    observed = hashlib.sha256((root / "ssot/runtime-modes.json").read_bytes()).hexdigest()
    if expected is None or expected.group(1) != observed:
        raise IsolationError("Native runtime registry source digest is not synchronized")
    return report


def observe_ports(ports: dict[str, int]) -> dict[str, str]:
    """Temporarily bind loopback sockets, then close. This is not a reservation."""
    results = {}
    for name, port in ports.items():
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            try:
                probe.bind(("127.0.0.1", port))
            except OSError:
                results[name] = "UNAVAILABLE"
            else:
                results[name] = "AVAILABLE_AT_OBSERVATION_RECHECK_BEFORE_LAUNCH"
    return results


def require_native_integration(root: Path = ROOT) -> None:
    # Build admission is separate from runtime/account readiness. The native
    # mode remains blocked until the later SDK/AVD provisioning checkpoint.
    if not preflight(root=root)["build_allowed"]:
        raise IsolationError("TURBO2_NOT_BUILD_READY: source integration is incomplete")


def staged_candidate_path(app: Path, home: Path | None = None) -> Path:
    home = home or Path.home()
    _no_symlink(app)
    if (not app.is_absolute() or ".." in app.parts
            or app.name != "TFT TURBO 2.app"
            or app.parent.parent != home / "Desktop"
            or not app.parent.name.startswith(".tft-turbo2-build-")):
        raise IsolationError("Invalid exclusive TURBO 2 staging path")
    try:
        status = app.parent.stat()
    except OSError as exc:
        raise IsolationError("Candidate stage is absent") from exc
    if status.st_uid != os.getuid() or status.st_mode & 0o077:
        raise IsolationError("Candidate stage must be owner-only")
    return app


def publish_exclusively(source: Path, destination: Path) -> None:
    """Atomic macOS rename that fails if ANY destination already exists."""
    library = ctypes.CDLL(None, use_errno=True)
    rename = library.renamex_np
    rename.argtypes = (ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint)
    rename.restype = ctypes.c_int
    # Darwin RENAME_EXCL (also VFS_RENAME_EXCL) is 0x00000004.
    if rename(os.fsencode(source), os.fsencode(destination), 0x00000004) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(destination))


def verify_packaged_identity(app: Path, root: Path = ROOT) -> dict[str, Any]:
    """Validate exact source-built resources; does not start runtime or access accounts."""
    require_candidate_bundle(app)
    resources = app / "Contents/Resources"
    registry_path = resources / "runtime-modes.json"
    if registry_path.read_bytes() != (root / "ssot/runtime-modes.json").read_bytes():
        raise IsolationError("Packaged runtime registry differs from reviewed source")
    registry = json.loads(registry_path.read_text())
    native = registry["modes"]["turbo2"]
    if native["launch_state"] != "blocked_not_built":
        raise IsolationError("This build has no authority to activate a runtime")
    host_authority = native["host_application"]
    host = resources / host_authority["path"]
    with (host / "Contents/Info.plist").open("rb") as stream:
        host_info = plistlib.load(stream)
    if host_info.get("CFBundleIdentifier") != host_authority["bundle_identifier"]:
        raise IsolationError("Nested host bundle identity mismatch")
    receipt = json.loads((resources / "turbo2-host-build.json").read_text())
    expected = {
        "state": "TURBO2_NATIVE_HOST_BUILD_PASS",
        "host_application_relative_path": host_authority["path"],
        "bundle_identifier": host_authority["bundle_identifier"],
        "source_path": host_authority["source_path"],
        "source_sha256": host_authority["source_sha256"],
        "info_plist_path": host_authority["info_plist_path"],
        "info_plist_sha256": host_authority["info_plist_sha256"],
        "executable_relative_path": host_authority["executable_relative_path"],
        "compile_arguments": ["-Os", "-arch", "arm64", "-mmacosx-version-min=15.0"],
    }
    if any(receipt.get(k) != v for k, v in expected.items()):
        raise IsolationError("Nested host receipt differs from source authority")
    for relative, expected_hash in [
        (host_authority["executable_relative_path"], receipt.get("executable_sha256")),
        ("Contents/Info.plist", host_authority["info_plist_sha256"]),
    ]:
        if hashlib.sha256((host / relative).read_bytes()).hexdigest() != expected_hash:
            raise IsolationError("Nested host content does not match its signed receipt")
    for directory in (app, *[p for p in app.rglob("*") if p.is_dir()]):
        if directory.is_symlink():
            raise IsolationError("Unexpected linked directory in source-only candidate")
    for private_name in ("DEVGuestPIN.txt", "riot-login.json"):
        if any(app.rglob(private_name)):
            raise IsolationError("Account provisioning must not be embedded in this candidate")
    return {"packaged_identity": "PASS", "runtime": "PENDING_CP4", "accounts": "DEFERRED_TO_LOCAL_CODEX"}


def require_candidate_bundle(app: Path) -> None:
    """Reject a renamed incumbent before any expensive native verification."""
    if not app.is_dir():
        raise IsolationError("TURBO2_NOT_INSTALLED: candidate bundle is absent")
    info = app / "Contents/Info.plist"
    _no_symlink(info)
    try:
        with info.open("rb") as stream:
            data = plistlib.load(stream)
    except (OSError, ValueError, plistlib.InvalidFileException) as exc:
        raise IsolationError("Candidate Info.plist is missing or invalid") from exc
    if data.get("CFBundleIdentifier") != "com.flashls1.tftmac.turbo2":
        raise IsolationError("Candidate is not the TURBO 2 bundle; refusing wrong-app verification")


def parse_signing_identity(output: str) -> str:
    pattern = r'^\s*\d+\)\s+[0-9A-Fa-f]{40}\s+"' + re.escape(SIGNING_IDENTITY) + r'"\s*$'
    if not any(re.match(pattern, line) for line in output.splitlines()):
        raise IsolationError("Required stable signing identity is unavailable; ad-hoc fallback is forbidden")
    return SIGNING_IDENTITY


def required_signing_identity() -> str:
    try:
        result = subprocess.run(["/usr/bin/security", "find-identity", "-v", "-p", "codesigning"],
                                capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        raise IsolationError("Stable signing identity lookup failed; refusing build") from exc
    return parse_signing_identity(result.stdout)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path)
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--staged-app", type=Path)
    parser.add_argument("--check-ports", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.app is not None and args.staged_app is not None:
            raise IsolationError("Choose one exact verification target")
        if not args.preflight and args.app is None and args.staged_app is None:
            raise IsolationError("Explicit --app is required for candidate verification")
        report = preflight(args.app)
        target = staged_candidate_path(args.staged_app) if args.staged_app else Path(report["app"])
        if args.check_ports:
            report["port_observations"] = observe_ports(report["ports"])
            if "UNAVAILABLE" in report["port_observations"].values():
                raise IsolationError("A candidate port is currently occupied; no owner was stopped")
        if args.preflight:
            print(json.dumps(report, indent=2, sort_keys=True))
            return 0
        require_native_integration()
        print(json.dumps(verify_packaged_identity(target), sort_keys=True))
    except IsolationError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
