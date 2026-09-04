#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly ROOT="${0:A:h:h}"
readonly ICON_SOURCE="${ROOT}/tftmac/Assets/TFTMAC-DEV-Icon.png"
readonly ICON_SOURCE_SHA256="660d312767f6367d5e60d21ff9f05c8e17c29c0e258a45f5cb5e40ac0cb4c945"
readonly REGISTRY_SHA256="f92cfc78923814d8eb3d8f6f550a4763ba918fe5e1c20088e2863d89ce58eafe"
readonly TRACE_PROCESSOR_SHA256="d29864d1ba3b36855527bb1b0ca3aa7f703cdce338b9680bb922c5c151b358fa"
readonly SIGNING_IDENTITY_NAME="${TFTMAC_CODE_SIGN_IDENTITY_NAME:-TFTMAC Local Code Signing}"
readonly DERIVED="${ROOT}/.build/native-dev"
readonly BUILT_APP="${DERIVED}/Build/Products/Release/TFTMAC.app"
readonly DIST="${ROOT}/dist/TFTMAC DEV.app"
readonly ICON_WORK="$(/usr/bin/mktemp -d /private/tmp/tftmac-dev-icon.XXXXXX)"

cleanup() {
  /bin/rm -rf "${ICON_WORK}"
}
trap cleanup EXIT

fail() {
  print -u2 "TFTMAC DEV build failed: $*"
  exit 1
}

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d /Applications/Xcode-26.6.0.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer
  else
    export DEVELOPER_DIR="$(/usr/bin/xcode-select -p)"
  fi
fi

[[ -s "${ICON_SOURCE}" ]] || fail "DEV icon source is missing: ${ICON_SOURCE}"
[[ "$(/usr/bin/shasum -a 256 "${ICON_SOURCE}" | /usr/bin/awk '{print $1}')" == "${ICON_SOURCE_SHA256}" ]] \
  || fail "DEV icon source failed its SHA-256 receipt"
[[ "$(/usr/bin/shasum -a 256 "${ROOT}/ssot/runtime-modes.json" | /usr/bin/awk '{print $1}')" == "${REGISTRY_SHA256}" ]] \
  || fail "runtime-mode registry failed its DEV launcher receipt"

"${ROOT}/scripts/build-vulkan-probe.command" >/dev/null
readonly PROBE_APK="${ROOT}/.build/vulkan-probe/TFTMACVulkanProbe.apk"
readonly PROBE_RECEIPT="${ROOT}/.build/vulkan-probe/build-receipt.json"
[[ -s "${PROBE_APK}" && -s "${PROBE_RECEIPT}" ]] \
  || fail "owned Vulkan probe build did not produce its sealed artifacts"

readonly SIGNING_IDENTITY_HASH="$(/bin/zsh "${ROOT}/scripts/ensure-local-signing-identity.command")"
[[ -n "${SIGNING_IDENTITY_HASH}" ]] || fail "stable local signing identity is unavailable"

/usr/bin/xcodebuild \
  -quiet \
  -project "${ROOT}/TFTMAC.xcodeproj" \
  -scheme TFTMAC \
  -configuration Release \
  -derivedDataPath "${DERIVED}" \
  CODE_SIGNING_ALLOWED=NO \
  build

[[ -d "${BUILT_APP}" ]] || fail "Xcode did not produce ${BUILT_APP}"
/bin/mkdir -p "${ROOT}/dist"
/bin/rm -rf "${DIST}"
/usr/bin/ditto "${BUILT_APP}" "${DIST}"

readonly MACOS_DIR="${DIST}/Contents/MacOS"
readonly RESOURCES_DIR="${DIST}/Contents/Resources"
readonly INFO="${DIST}/Contents/Info.plist"
/bin/mv "${MACOS_DIR}/TFTMAC" "${MACOS_DIR}/TFTMACDEVCore"
/usr/bin/xcrun --sdk macosx clang \
  -Os -arch arm64 -mmacosx-version-min=15.0 \
  "${ROOT}/DevLauncher/main.c" \
  -o "${MACOS_DIR}/TFTMACDEVLauncher"

/usr/bin/plutil -replace CFBundleDisplayName -string "TFTMAC DEV" "${INFO}"
/usr/bin/plutil -replace CFBundleName -string "TFTMAC DEV" "${INFO}"
/usr/bin/plutil -replace CFBundleExecutable -string "TFTMACDEVLauncher" "${INFO}"
/usr/bin/plutil -replace CFBundleIdentifier -string "com.flashls1.tftmac.dev" "${INFO}"
/usr/bin/plutil -replace CFBundleIconFile -string "TFTMAC-DEV.icns" "${INFO}"
/usr/bin/plutil -replace NSRemovableVolumesUsageDescription -string \
  "TFTMAC DEV uses the isolated Android diagnostic runtime stored on MAC MINI M4." "${INFO}"
/usr/bin/plutil -insert TFTMACRuntimeMode -string "advanced_diagnostics" "${INFO}"
/usr/bin/plutil -lint "${INFO}" >/dev/null

/usr/bin/sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICON_WORK}/icon_1024x1024.png" >/dev/null
/bin/mkdir -p "${ICON_WORK}/TFTMAC-DEV.iconset" "${RESOURCES_DIR}"
for specification in \
  '16 icon_16x16.png' \
  '32 icon_16x16@2x.png' \
  '32 icon_32x32.png' \
  '64 icon_32x32@2x.png' \
  '128 icon_128x128.png' \
  '256 icon_128x128@2x.png' \
  '256 icon_256x256.png' \
  '512 icon_256x256@2x.png' \
  '512 icon_512x512.png' \
  '1024 icon_512x512@2x.png'; do
  pixels="${specification%% *}"
  filename="${specification#* }"
  /usr/bin/sips -z "${pixels}" "${pixels}" "${ICON_WORK}/icon_1024x1024.png" \
    --out "${ICON_WORK}/TFTMAC-DEV.iconset/${filename}" >/dev/null
done
/usr/bin/iconutil -c icns "${ICON_WORK}/TFTMAC-DEV.iconset" -o "${RESOURCES_DIR}/TFTMAC-DEV.icns"
/bin/cp "${ICON_WORK}/icon_1024x1024.png" "${RESOURCES_DIR}/TFTMAC-DEV-1024.png"
/bin/cp "${PROBE_APK}" "${RESOURCES_DIR}/TFTMACVulkanProbe.apk"
/bin/cp "${PROBE_RECEIPT}" "${RESOURCES_DIR}/TFTMACVulkanProbe-build-receipt.json"
/bin/cp "${ROOT}/Probes/TFTMACVulkanProbe/workload-manifest.json" "${RESOURCES_DIR}/workload-manifest.json"

trace_processor="/Applications/TFTMAC.app/Contents/Resources/trace_processor_shell"
if [[ ! -x "${trace_processor}" ]] || \
   [[ "$(/usr/bin/shasum -a 256 "${trace_processor}" | /usr/bin/awk '{print $1}')" != "${TRACE_PROCESSOR_SHA256}" ]]; then
  trace_processor="$(/bin/zsh "${ROOT}/scripts/install-trace-processor.command")"
fi
[[ "$(/usr/bin/shasum -a 256 "${trace_processor}" | /usr/bin/awk '{print $1}')" == "${TRACE_PROCESSOR_SHA256}" ]] \
  || fail "Perfetto trace_processor failed its pinned SHA-256 receipt"
/bin/cp "${trace_processor}" "${RESOURCES_DIR}/trace_processor_shell"
/bin/chmod 755 "${RESOURCES_DIR}/trace_processor_shell"

/usr/bin/codesign --force --sign "${SIGNING_IDENTITY_HASH}" --timestamp=none "${MACOS_DIR}/TFTMACDEVCore"
/usr/bin/codesign --force --sign "${SIGNING_IDENTITY_HASH}" --timestamp=none "${MACOS_DIR}/TFTMACDEVLauncher"
/usr/bin/codesign --force --sign "${SIGNING_IDENTITY_HASH}" --timestamp=none "${DIST}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${DIST}"

[[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "${INFO}")" == "com.flashls1.tftmac.dev" ]] \
  || fail "DEV bundle identity drifted"
[[ "$(/usr/bin/plutil -extract CFBundleExecutable raw "${INFO}")" == "TFTMACDEVLauncher" ]] \
  || fail "DEV launcher executable drifted"
/usr/bin/strings "${MACOS_DIR}/TFTMACDEVLauncher" | /usr/bin/grep -Fx "advanced_diagnostics" >/dev/null \
  || fail "DEV launcher does not contain the enforced diagnostic runtime selection"

print "TFTMAC DEV built without modifying Control: ${DIST}"
