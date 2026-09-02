#!/bin/zsh
set -euo pipefail

readonly ROOT="${0:A:h:h}"
cd "$ROOT"

fail() { print -u2 -- "TFTMAC diagnostic runtime preflight failed: $*"; exit 1; }
sha() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

readonly REGISTRY="ssot/runtime-modes.json"
readonly MODE="advanced_diagnostics"
readonly RELEASE_APP="$ROOT/.build/native-ci-release/Build/Products/Release/TFTMAC.app"
readonly PORT_RECEIPT="$ROOT/.clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/PORT_ALLOCATION_RECEIPT.json"

node .clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/validate-source.mjs >/dev/null \
  || fail "source authority validation failed"
[[ -x "$RELEASE_APP/Contents/MacOS/TFTMAC" ]] || fail "verified unsigned Release app is missing"
cmp -s "$REGISTRY" "$RELEASE_APP/Contents/Resources/runtime-modes.json" \
  || fail "Release app does not package the exact diagnostic registry"

readonly PORT_RECEIPT_SHA="$(sha "$PORT_RECEIPT")"
[[ "$PORT_RECEIPT_SHA" == "3536b1d54a0643bc3fcbb9dbff01be2402ca9c45d2100e220c2f857e65a129cd" ]] \
  || fail "diagnostic port receipt drifted"
jq -e '.state == "DIAGNOSTIC_PORT_ALLOCATION_PASS" and .ports.adb_server == 5041 and .ports.console == 5586 and .ports.controller == 8556' "$PORT_RECEIPT" >/dev/null \
  || fail "diagnostic port receipt is invalid"

for key in build clone native_host; do
  receipt="$(jq -r --arg key "$key" '.modes.advanced_diagnostics.diagnostic_receipts[$key].path' "$REGISTRY")"
  expected="$(jq -r --arg key "$key" '.modes.advanced_diagnostics.diagnostic_receipts[$key].sha256' "$REGISTRY")"
  required_state="$(jq -r --arg key "$key" '.modes.advanced_diagnostics.diagnostic_receipts[$key].required_state' "$REGISTRY")"
  [[ -f "$receipt" && -f "$receipt.sha256" ]] || fail "sealed $key receipt is missing"
  [[ "$(sha "$receipt")" == "$expected" ]] || fail "$key receipt bytes drifted"
  [[ "$(awk '{print $1}' "$receipt.sha256")" == "$expected" ]] || fail "$key receipt sidecar drifted"
  [[ "$(jq -r '.state' "$receipt")" == "$required_state" ]] || fail "$key receipt state drifted"
done

for field in emulator gfxstream_backend adb avd_config avd_ini qemu; do
  case "$field" in
    emulator) path_key=emulator_path; sha_key=emulator_sha256 ;;
    gfxstream_backend) path_key=gfxstream_backend_path; sha_key=gfxstream_backend_sha256 ;;
    adb) path_key=adb_path; sha_key=adb_sha256 ;;
    avd_config) path_key=avd_config_path; sha_key=avd_config_sha256 ;;
    avd_ini) path_key=avd_ini_path; sha_key=avd_ini_sha256 ;;
    qemu) path_key=qemu_path; sha_key=qemu_sha256 ;;
  esac
  artifact="$(jq -r --arg key "$path_key" '.modes.advanced_diagnostics[$key]' "$REGISTRY")"
  expected="$(jq -r --arg key "$sha_key" '.modes.advanced_diagnostics[$key]' "$REGISTRY")"
  [[ -f "$artifact" ]] || fail "$field artifact is missing: $artifact"
  [[ "$(sha "$artifact")" == "$expected" ]] || fail "$field artifact identity drifted"
done

readonly HOST_APP="$(jq -r '.modes.advanced_diagnostics.host_application.path' "$REGISTRY")"
readonly HOST_EXEC_REL="$(jq -r '.modes.advanced_diagnostics.host_application.executable_relative_path' "$REGISTRY")"
readonly HOST_EXEC_SHA="$(jq -r '.modes.advanced_diagnostics.host_application.executable_sha256' "$REGISTRY")"
[[ -d "$HOST_APP" && -x "$HOST_APP/$HOST_EXEC_REL" ]] || fail "diagnostic native forwarder is missing"
[[ "$(sha "$HOST_APP/$HOST_EXEC_REL")" == "$HOST_EXEC_SHA" ]] || fail "diagnostic native forwarder identity drifted"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$HOST_APP" >/dev/null \
  || fail "diagnostic native forwarder signature is invalid"

if /bin/ps -axo command= | /usr/bin/grep -F 'qemu-system-aarch64' | /usr/bin/grep -v grep >/dev/null; then
  fail "an emulator is already running"
fi
for port in 5041 5586 8556; do
  if /usr/sbin/lsof -nP -iTCP:"$port" -sTCP:LISTEN | /usr/bin/grep -q .; then
    fail "diagnostic port $port is already listening"
  fi
done

readonly LEASE="$HOME/Library/Application Support/TFTMAC/State/native-runtime.lease"
if [[ -f "$LEASE" ]]; then
  lease_pid="$(jq -r '.pid // 0' "$LEASE" 2>/dev/null || print 0)"
  if [[ "$lease_pid" == <-> ]] && (( lease_pid > 0 )) && /bin/kill -0 "$lease_pid" 2>/dev/null; then
    fail "runtime lease is owned by live PID $lease_pid"
  fi
fi

print "TFTMAC diagnostic runtime preflight: READY (R9 identities; ports 5041/5586/8556; control stopped)"
