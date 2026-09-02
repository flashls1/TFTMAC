#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly SOURCE_MOUNT="/Volumes/TFTMAC Causal Source"
readonly SOURCE_ROOT="${SOURCE_MOUNT}/emu-main-dev-2692acc6"
readonly RECEIPT_ROOT="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Manifests/causal-source-20260902"
readonly BUILD_ROOT="${SOURCE_MOUNT}/Build/causal-stock-20260902"
readonly INSTALL_ROOT="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/causal-stock-20260902"
readonly REBUILD="${SOURCE_ROOT}/external/qemu/android/rebuild.sh"

fail() { print -u2 "TFTMAC causal stock build failed: $*"; exit 1; }

[[ -x "${REBUILD}" ]] || fail "prepared modern emulator source is unavailable"
[[ -d "${SOURCE_MOUNT}" ]] || fail "case-sensitive source volume is not mounted"
[[ "$(/usr/bin/jq -r '.state' "${RECEIPT_ROOT}/source-receipt.json")" == "CAUSAL_SOURCE_LOCK_PASS" ]] \
  || fail "modern source receipt is not accepted"
if /bin/ps -axo command | /usr/bin/grep -E '/Applications/TFTMAC( DEV)?\.app/Contents/MacOS/' | /usr/bin/grep -v grep >/dev/null; then
  fail "Control or DEV is running; source build is intentionally deferred"
fi

export DEVELOPER_DIR="/Applications/Xcode-26.6.0.app/Contents/Developer"
export CMAKE_BUILD_PARALLEL_LEVEL=4
/bin/mkdir -p "${BUILD_ROOT}" "${INSTALL_ROOT}"
"${REBUILD}" \
  --out="${BUILD_ROOT}/aemu-out" \
  --config release \
  --task-disable CTest \
  --task-disable ZipIntegrationTests \
  --task-disable PackageSamples \
  --verbose

readonly DISTRIBUTION="${BUILD_ROOT}/aemu-out/distribution/emulator"
[[ -x "${DISTRIBUTION}/emulator" ]] || fail "emulator artifact is missing"
[[ -f "${DISTRIBUTION}/lib64/libgfxstream_backend.dylib" ]] || fail "gfxstream artifact is missing"
[[ -f "${DISTRIBUTION}/lib64/vulkan/libMoltenVK.dylib" || -f "${DISTRIBUTION}/lib64/libMoltenVK.dylib" ]] \
  || fail "MoltenVK artifact is missing"
/usr/bin/ditto "${DISTRIBUTION}" "${INSTALL_ROOT}/emulator"

/usr/bin/jq -n \
  --arg state "CAUSAL_STOCK_BUILD_PASS_PENDING_FIRST_FRAME" \
  --arg source_receipt_sha256 "$(/usr/bin/shasum -a 256 "${RECEIPT_ROOT}/source-receipt.json" | /usr/bin/awk '{print $1}')" \
  --arg emulator_sha256 "$(/usr/bin/shasum -a 256 "${INSTALL_ROOT}/emulator/emulator" | /usr/bin/awk '{print $1}')" \
  --arg gfxstream_sha256 "$(/usr/bin/shasum -a 256 "${INSTALL_ROOT}/emulator/lib64/libgfxstream_backend.dylib" | /usr/bin/awk '{print $1}')" \
  '{schema:1,state:$state,source_receipt_sha256:$source_receipt_sha256,configuration:"Release",parallel_build_jobs:4,instrumentation:"OFF",artifacts:{emulator_sha256:$emulator_sha256,gfxstream_sha256:$gfxstream_sha256},control_touched:false}' \
  > "${RECEIPT_ROOT}/causal-stock-build.json"

print "TFTMAC causal stock build: PASS_PENDING_FIRST_FRAME (${INSTALL_ROOT})"
