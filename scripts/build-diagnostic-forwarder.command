#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

readonly EXPECTED_HEAD="a84aaa7"
readonly EXPECTED_MAIN_C_SHA="c749cd998a6f066e2f7a6ef818eecf05b90d1a8808f6c9966e0b5fc21affeeed"
readonly EXPECTED_PLIST_SHA="91306c277a84a800617b2b5f20e5614795f183e2373f19309d9033530869e483"
readonly EXPECTED_PORT_RECEIPT_SHA="3536b1d54a0643bc3fcbb9dbff01be2402ca9c45d2100e220c2f857e65a129cd"
readonly DEVELOPER_DIR="/Applications/Xcode-26.6.0.app/Contents/Developer"
readonly OUTPUT_ROOT="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/gate4-r9-forwarder-r1"
readonly APP_OUTPUT="$OUTPUT_ROOT/TFTMAC Diagnostic Forwarder.app"
readonly MANIFEST="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Manifests/gate4-r9-20260901/gate4-r9-forwarder-r1-native-host-build.json"

fail() { print -u2 -- "DIAGNOSTIC_FORWARDER_BUILD_FAILED: $*"; exit 1; }
sha() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

[[ "$(git rev-parse --short=7 HEAD)" == "$EXPECTED_HEAD" ]] || fail "repository head drifted"
[[ -z "$(git status --porcelain=v1 --untracked-files=no)" ]] || fail "tracked worktree must be clean"
[[ "$(sha RuntimeHost/main.c)" == "$EXPECTED_MAIN_C_SHA" ]] || fail "proven forwarder source drifted"
[[ "$(sha RuntimeHost/DiagnosticInfo.plist)" == "$EXPECTED_PLIST_SHA" ]] || fail "diagnostic plist drifted"
[[ "$(sha .clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/PORT_ALLOCATION_RECEIPT.json)" == "$EXPECTED_PORT_RECEIPT_SHA" ]] || fail "port authority drifted"
[[ ! -e "$APP_OUTPUT" ]] || fail "immutable app output already exists"
[[ ! -e "$MANIFEST" && ! -e "$MANIFEST.sha256" ]] || fail "immutable build receipt already exists"

readonly SDK_PATH="$(/usr/bin/env DEVELOPER_DIR="$DEVELOPER_DIR" /usr/bin/xcrun --sdk macosx --show-sdk-path)"
readonly CLANG="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
readonly TEMP_ROOT="$(/usr/bin/mktemp -d /tmp/tftmac-diagnostic-forwarder.XXXXXX)"
trap '/bin/rm -rf "$TEMP_ROOT"' EXIT
readonly TEMP_APP="$TEMP_ROOT/TFTMAC Diagnostic Forwarder.app"

/bin/mkdir -p "$TEMP_APP/Contents/MacOS"
/bin/cp RuntimeHost/DiagnosticInfo.plist "$TEMP_APP/Contents/Info.plist"
"$CLANG" \
  -target arm64-apple-macos15.0 \
  -isysroot "$SDK_PATH" \
  -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  RuntimeHost/main.c \
  -o "$TEMP_APP/Contents/MacOS/TFTMACDiagnosticForwarder"
/usr/bin/plutil -lint "$TEMP_APP/Contents/Info.plist" >/dev/null
/usr/bin/codesign --force --sign - --timestamp=none "$TEMP_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$TEMP_APP"

/bin/mkdir -p "$OUTPUT_ROOT"
/bin/mv "$TEMP_APP" "$APP_OUTPUT"

/usr/bin/python3 - "$ROOT" "$APP_OUTPUT" "$MANIFEST" "$DEVELOPER_DIR" <<'PY'
import hashlib
import json
import os
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

root = pathlib.Path(sys.argv[1])
app = pathlib.Path(sys.argv[2])
manifest = pathlib.Path(sys.argv[3])
developer_dir = pathlib.Path(sys.argv[4])
executable = app / "Contents/MacOS/TFTMACDiagnosticForwarder"
plist = app / "Contents/Info.plist"

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

uuid_output = subprocess.check_output(["/usr/bin/dwarfdump", "--uuid", str(executable)], text=True)
uuids = []
for line in uuid_output.splitlines():
    parts = line.split()
    if len(parts) >= 3 and parts[0] == "UUID:":
        uuids.append(f"{parts[1]}:{parts[2].strip('()')}")

receipt = {
    "schema": 1,
    "state": "DIAGNOSTIC_NATIVE_HOST_BUILD_PASS",
    "build_id": "gate4-r9-20260901",
    "attempt_id": "gate4-r9-forwarder-r1",
    "built_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "source": {
        "repository_root": str(root),
        "head_sha": subprocess.check_output(["/usr/bin/git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "forwarder_path": str(root / "RuntimeHost/main.c"),
        "forwarder_sha256": digest(root / "RuntimeHost/main.c"),
        "info_plist_path": str(root / "RuntimeHost/DiagnosticInfo.plist"),
        "info_plist_sha256": digest(root / "RuntimeHost/DiagnosticInfo.plist"),
    },
    "toolchain": {
        "developer_dir": str(developer_dir),
        "clang": str(developer_dir / "Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"),
    },
    "app": {
        "path": str(app),
        "bundle_identifier": "com.flashls1.tftmac.runtime.diagnostic-forwarder",
        "executable": {
            "path": str(executable),
            "sha256": digest(executable),
            "size_bytes": executable.stat().st_size,
            "uuids": uuids,
        },
        "info_plist": {
            "path": str(plist),
            "sha256": digest(plist),
            "size_bytes": plist.stat().st_size,
        },
        "codesign_verify_status": 0,
        "signing_identity": "AD_HOC",
    },
    "launch_contract": {
        "method": "/usr/bin/open -n -W --env ... --args ...",
        "emulator_spawn_owner": "NATIVE_MACOS_APP_PROCESS",
        "service_context_emulator_spawn_forbidden": True,
        "forwards_tft_emulator_environment": True,
    },
    "port_allocation_receipt": {
        "path": str(root / ".clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/PORT_ALLOCATION_RECEIPT.json"),
        "sha256": digest(root / ".clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/PORT_ALLOCATION_RECEIPT.json"),
    },
    "control_runtime_mutation_attempted": False,
    "runtime_launch_attempted": False,
}

data = (json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode()
manifest.parent.mkdir(parents=True, exist_ok=True)
fd = os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
with os.fdopen(fd, "wb") as handle:
    handle.write(data)
manifest_sha = hashlib.sha256(data).hexdigest()
sidecar = pathlib.Path(str(manifest) + ".sha256")
fd = os.open(sidecar, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
with os.fdopen(fd, "w") as handle:
    handle.write(manifest_sha + "\n")
print(json.dumps({
    "state": receipt["state"],
    "app": str(app),
    "executable_sha256": receipt["app"]["executable"]["sha256"],
    "manifest": str(manifest),
    "manifest_sha256": manifest_sha,
}, indent=2))
PY
