#!/bin/zsh
set -euo pipefail

readonly BUILD_ID="stock-shadow-r1-20260902"
readonly CONTROL_ROOT="/Volumes/MAC MINI M4/TFTMAC/Runtime"
readonly CONTROL_SDK="${CONTROL_ROOT}/SDK"
readonly CONTROL_AVD_HOME="${CONTROL_ROOT}/AVD"
readonly CONTROL_AVD_NAME="TFT_Ultra_Tablet"
readonly DIAGNOSTIC_ROOT="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow"
readonly DIAGNOSTIC_SDK="${DIAGNOSTIC_ROOT}/SDK"
readonly DIAGNOSTIC_AVD_HOME="${DIAGNOSTIC_ROOT}/AVD"
readonly DIAGNOSTIC_AVD_NAME="TFTMAC_Diagnostic_StockShadow_R1"
readonly DIAGNOSTIC_AVD="${DIAGNOSTIC_AVD_HOME}/${DIAGNOSTIC_AVD_NAME}.avd"
readonly DIAGNOSTIC_INI="${DIAGNOSTIC_AVD_HOME}/${DIAGNOSTIC_AVD_NAME}.ini"
readonly MANIFEST_ROOT="${DIAGNOSTIC_ROOT}/Manifests/${BUILD_ID}"
readonly MANIFEST="${MANIFEST_ROOT}/stock-shadow-runtime.json"
readonly CONTROL_EXECUTABLE="/Applications/TFTMAC.app/Contents/MacOS/TFTMAC"
readonly CONTROL_HOST="/Applications/TFTMAC.app/Contents/Resources/TFTMAC Emulator Host.app/Contents/MacOS/TFTMACEmulatorHost"
readonly EXPECTED_CONTROL_EXECUTABLE_SHA256="d3bf7c249a3e5f11b81f778b063e1a8cfe2e7fdeec0537ee6bd8447b1c2268d2"
readonly EXPECTED_CONTROL_HOST_SHA256="ea028ec1d74cc025638c2a0e5f8c783748803c1b0ba9012962c038251fb3eb63"

fail() {
  print -u2 "Stock-shadow build failed: $*"
  exit 1
}

sha256() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

tree_sha256() {
  local root="$1"
  /usr/bin/find "$root" -type f -print0 \
    | /usr/bin/sort -z \
    | /usr/bin/xargs -0 /usr/bin/shasum -a 256 \
    | /usr/bin/shasum -a 256 \
    | /usr/bin/awk '{print $1}'
}

uuid_receipt() {
  /usr/bin/dwarfdump --uuid "$1" | /usr/bin/awk '{print $2 ":" $3}' | /usr/bin/tr -d '()'
}

[[ "$(sha256 "${CONTROL_EXECUTABLE}")" == "${EXPECTED_CONTROL_EXECUTABLE_SHA256}" ]] \
  || fail "protected Control executable identity changed"
[[ "$(sha256 "${CONTROL_HOST}")" == "${EXPECTED_CONTROL_HOST_SHA256}" ]] \
  || fail "protected Control host identity changed"

for port in 5582 8554 5586 8556; do
  if /usr/sbin/lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | /usr/bin/grep -q LISTEN; then
    fail "runtime port ${port} is active; close TFTMAC before cloning"
  fi
done

[[ -d "${CONTROL_SDK}/emulator" ]] || fail "Control emulator is missing"
[[ -d "${CONTROL_SDK}/platform-tools" ]] || fail "Control platform-tools are missing"
[[ -d "${CONTROL_SDK}/system-images/android-36/google_apis_playstore/arm64-v8a" ]] \
  || fail "Control API 36 Play image is missing"
[[ -d "${CONTROL_AVD_HOME}/${CONTROL_AVD_NAME}.avd" ]] || fail "Control AVD is missing"
[[ -f "${CONTROL_AVD_HOME}/${CONTROL_AVD_NAME}.ini" ]] || fail "Control AVD ini is missing"

if [[ -e "${DIAGNOSTIC_SDK}" || -e "${DIAGNOSTIC_AVD}" || -e "${DIAGNOSTIC_INI}" ]]; then
  fail "stock-shadow target already exists; refusing to overwrite"
fi

readonly CONTROL_AVD_TREE_BEFORE="$(tree_sha256 "${CONTROL_AVD_HOME}/${CONTROL_AVD_NAME}.avd")"
/bin/mkdir -p "${DIAGNOSTIC_SDK}/system-images/android-36/google_apis_playstore" \
  "${DIAGNOSTIC_AVD_HOME}" "${MANIFEST_ROOT}"
/usr/bin/ditto --clone --noqtn "${CONTROL_SDK}/emulator" "${DIAGNOSTIC_SDK}/emulator"
/usr/bin/ditto --clone --noqtn "${CONTROL_SDK}/platform-tools" "${DIAGNOSTIC_SDK}/platform-tools"
/usr/bin/ditto --clone --noqtn \
  "${CONTROL_SDK}/system-images/android-36/google_apis_playstore/arm64-v8a" \
  "${DIAGNOSTIC_SDK}/system-images/android-36/google_apis_playstore/arm64-v8a"
/usr/bin/ditto --clone --noqtn \
  "${CONTROL_AVD_HOME}/${CONTROL_AVD_NAME}.avd" "${DIAGNOSTIC_AVD}"
/bin/cp "${CONTROL_AVD_HOME}/${CONTROL_AVD_NAME}.ini" "${DIAGNOSTIC_INI}"

for mutable in multiinstance.lock hardware-qemu.ini emu-launch-params.txt read-snapshot.txt bootcompleted.ini; do
  /bin/rm -f "${DIAGNOSTIC_AVD}/${mutable}"
done

/usr/bin/sed -i '' \
  -e "s|^path=.*|path=${DIAGNOSTIC_AVD}|" \
  -e "s|^target=.*|target=android-36|" \
  "${DIAGNOSTIC_INI}"
/usr/bin/sed -i '' \
  -e "s|^avd.id=.*|avd.id=${DIAGNOSTIC_AVD_NAME}|" \
  -e "s|^avd.name=.*|avd.name=${DIAGNOSTIC_AVD_NAME}|" \
  -e "s|^AvdId=.*|AvdId=${DIAGNOSTIC_AVD_NAME}|" \
  -e "s|^avd.ini.displayname=.*|avd.ini.displayname=TFTMAC DEV Stock Shadow|" \
  -e "s|^hw.ramSize=.*|hw.ramSize=5120|" \
  -e "s|^fastboot.forceColdBoot=.*|fastboot.forceColdBoot=yes|" \
  "${DIAGNOSTIC_AVD}/config.ini"

readonly CONTROL_AVD_TREE_AFTER="$(tree_sha256 "${CONTROL_AVD_HOME}/${CONTROL_AVD_NAME}.avd")"
[[ "${CONTROL_AVD_TREE_BEFORE}" == "${CONTROL_AVD_TREE_AFTER}" ]] \
  || fail "Control AVD changed while creating the stock shadow"

readonly EMULATOR="${DIAGNOSTIC_SDK}/emulator/emulator"
readonly QEMU="${DIAGNOSTIC_SDK}/emulator/qemu/darwin-aarch64/qemu-system-aarch64"
readonly GFXSTREAM="${DIAGNOSTIC_SDK}/emulator/lib64/libgfxstream_backend.dylib"
readonly ADB="${DIAGNOSTIC_SDK}/platform-tools/adb"
readonly CONFIG="${DIAGNOSTIC_AVD}/config.ini"

/usr/bin/jq -n \
  --arg build_id "${BUILD_ID}" \
  --arg emulator_path "${EMULATOR}" \
  --arg emulator_sha256 "$(sha256 "${EMULATOR}")" \
  --arg emulator_uuid "$(uuid_receipt "${EMULATOR}")" \
  --arg qemu_path "${QEMU}" \
  --arg qemu_sha256 "$(sha256 "${QEMU}")" \
  --arg qemu_uuid "$(uuid_receipt "${QEMU}")" \
  --arg gfxstream_path "${GFXSTREAM}" \
  --arg gfxstream_sha256 "$(sha256 "${GFXSTREAM}")" \
  --arg gfxstream_uuid "$(uuid_receipt "${GFXSTREAM}")" \
  --arg adb_path "${ADB}" \
  --arg adb_sha256 "$(sha256 "${ADB}")" \
  --arg avd_name "${DIAGNOSTIC_AVD_NAME}" \
  --arg avd_path "${DIAGNOSTIC_AVD}" \
  --arg avd_ini_path "${DIAGNOSTIC_INI}" \
  --arg avd_config_sha256 "$(sha256 "${CONFIG}")" \
  --arg avd_ini_sha256 "$(sha256 "${DIAGNOSTIC_INI}")" \
  --arg avd_tree_sha256 "$(tree_sha256 "${DIAGNOSTIC_AVD}")" \
  --arg control_avd_tree_sha256 "${CONTROL_AVD_TREE_AFTER}" \
  --arg control_executable_sha256 "${EXPECTED_CONTROL_EXECUTABLE_SHA256}" \
  --arg control_host_sha256 "${EXPECTED_CONTROL_HOST_SHA256}" \
  '{
    schema: 1,
    state: "STOCK_SHADOW_RUNTIME_IDENTITY_PASS",
    build_id: $build_id,
    runtime_variant: "stock_shadow",
    comparison_class: "STOCK_BUILD8_CONTROL_SHADOW",
    first_boot_attempted: false,
    control_runtime_touched: false,
    control_avd_touched: false,
    control_noninterference: {
      matched: true,
      avd_tree_sha256: $control_avd_tree_sha256,
      executable_sha256: $control_executable_sha256,
      host_sha256: $control_host_sha256
    },
    runtime: {
      emulator: {path: $emulator_path, sha256: $emulator_sha256, uuid: $emulator_uuid},
      qemu: {path: $qemu_path, sha256: $qemu_sha256, uuid: $qemu_uuid},
      gfxstream: {path: $gfxstream_path, sha256: $gfxstream_sha256, uuid: $gfxstream_uuid},
      adb: {path: $adb_path, sha256: $adb_sha256},
      expected_emulator_version_contains: "37.1.11"
    },
    avd: {
      name: $avd_name,
      path: $avd_path,
      ini_path: $avd_ini_path,
      config_sha256: $avd_config_sha256,
      ini_sha256: $avd_ini_sha256,
      tree_sha256: $avd_tree_sha256,
      target: "android-36",
      installer_authority: "com.android.vending"
    },
    lease: {adb_server_port: 5041, console_port: 5586, controller_port: 8556, serial: "emulator-5586"},
    locked_profile: {
      width: 1920, height: 1080, density_dpi: 320, refresh_hz: 60,
      vcpu: 6, ram_mib: 5120, gpu_mode: "host", audio_backend: "coreaudio",
      graphics_transport: "virtio-gpu-asg", asg_write_buffer_size: 1048576,
      asg_write_step_size: 16384, asg_data_ring_size: 32768,
      asg_draw_flush_interval: 800
    }
  }' > "${MANIFEST}"

readonly MANIFEST_SHA256="$(sha256 "${MANIFEST}")"
print -r -- "${MANIFEST_SHA256}  ${MANIFEST:t}" > "${MANIFEST}.sha256"
print "Stock shadow created: ${MANIFEST}"
print "Manifest SHA-256: ${MANIFEST_SHA256}"
