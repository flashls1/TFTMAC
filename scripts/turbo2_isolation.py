#!/usr/bin/env python3
"""Read-only TURBO 2 identity preflight; never launches, builds or migrates.

The legacy build entrypoints use this guard before reading private seed inputs
or performing effects. CP2 defines isolation, not a launch-ready native mode.
"""
from __future__ import annotations

import argparse
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
    for mode in registry.get("modes", {}).values():
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
                or contract["native_integration"] != "pending"):
            raise IsolationError("CP2 cannot declare a native runtime ready")
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
        occupied = set()
        for mode in registry["modes"].values():
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
        if any(m.get("avd_name") == contract["avd_name"] for m in registry["modes"].values()):
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
        "build_allowed": False, "launch_allowed": False,
        "native_integration": "NOT_IMPLEMENTED", "credential_access": "NOT_VERIFIED",
    }


def preflight(output: Path | None = None, root: Path = ROOT) -> dict[str, Any]:
    try:
        registry = json.loads((root / "ssot/runtime-modes.json").read_text())
    except (OSError, ValueError) as exc:
        raise IsolationError("Cannot read existing runtime registry") from exc
    return inspect_contract(load_contract(root), registry, output)


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


def require_native_integration() -> None:
    # Intentional checkpoint boundary, not an environment flag. Remove only with
    # governed native-mode/build wiring and authenticated-clone acceptance.
    raise IsolationError("TURBO2_NOT_BUILD_READY: native mode, candidate packaging and authenticated clone are not integrated; no build or legacy fallback was started")


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
    parser.add_argument("--check-ports", action="store_true")
    args = parser.parse_args(argv)
    try:
        if not args.preflight and args.app is None:
            raise IsolationError("Explicit --app is required for candidate verification")
        report = preflight(args.app)
        if args.check_ports:
            report["port_observations"] = observe_ports(report["ports"])
            if "UNAVAILABLE" in report["port_observations"].values():
                raise IsolationError("A candidate port is currently occupied; no owner was stopped")
        if args.preflight:
            print(json.dumps(report, indent=2, sort_keys=True))
            return 0
        require_candidate_bundle(Path(report["app"]))
        require_native_integration()
    except IsolationError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
