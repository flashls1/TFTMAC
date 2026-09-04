#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly ROOT="${0:A:h:h}"
readonly CONTROL_APP="/Applications/TFTMAC.app"
readonly CONTROL_EXECUTABLE_SHA256="d3bf7c249a3e5f11b81f778b063e1a8cfe2e7fdeec0537ee6bd8447b1c2268d2"
readonly CONTROL_HOST_SHA256="ea028ec1d74cc025638c2a0e5f8c783748803c1b0ba9012962c038251fb3eb63"
readonly ICON_SOURCE="${ROOT}/tftmac/Assets/TFTMAC-Official-Icon.png"
readonly DIST="${ROOT}/dist/TFTMAC Control Launcher.app"
readonly MACOS_DIR="${DIST}/Contents/MacOS"
readonly RESOURCES_DIR="${DIST}/Contents/Resources"
readonly ICON_WORK="$(/usr/bin/mktemp -d /private/tmp/tftmac-control-icon.XXXXXX)"
readonly SIGNING_IDENTITY_NAME="${TFTMAC_CODE_SIGN_IDENTITY_NAME:-TFTMAC Local Code Signing}"

cleanup() { /bin/rm -rf "${ICON_WORK}"; }
trap cleanup EXIT
fail() { print -u2 "TFTMAC Control launcher build failed: $*"; exit 1; }

[[ -x "${CONTROL_APP}/Contents/MacOS/TFTMAC" ]] || fail "protected Control app is missing"
[[ "$(/usr/bin/shasum -a 256 "${CONTROL_APP}/Contents/MacOS/TFTMAC" | /usr/bin/awk '{print $1}')" == "${CONTROL_EXECUTABLE_SHA256}" ]] \
  || fail "protected Control executable identity changed"
[[ "$(/usr/bin/shasum -a 256 "${CONTROL_APP}/Contents/Resources/TFTMAC Emulator Host.app/Contents/MacOS/TFTMACEmulatorHost" | /usr/bin/awk '{print $1}')" == "${CONTROL_HOST_SHA256}" ]] \
  || fail "protected Control emulator-host identity changed"

/bin/rm -rf "${DIST}"
/bin/mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
/bin/cp "${ROOT}/ControlLauncher/Info.plist" "${DIST}/Contents/Info.plist"
/usr/bin/xcrun --sdk macosx swiftc \
  -O -whole-module-optimization -swift-version 5 -parse-as-library \
  -target arm64-apple-macos15.0 \
  -framework AppKit -framework LocalAuthentication -framework Security \
  "${ROOT}/ControlLauncher/main.swift" \
  "${ROOT}/tftmac/Runtime/GuestUnlockSecret.swift" \
  -o "${MACOS_DIR}/TFTMACControlLauncher"

/usr/bin/sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICON_WORK}/icon_1024x1024.png" >/dev/null
/bin/mkdir -p "${ICON_WORK}/TFTMAC-Official.iconset"
for specification in \
  '16 icon_16x16.png' '32 icon_16x16@2x.png' '32 icon_32x32.png' '64 icon_32x32@2x.png' \
  '128 icon_128x128.png' '256 icon_128x128@2x.png' '256 icon_256x256.png' \
  '512 icon_256x256@2x.png' '512 icon_512x512.png' '1024 icon_512x512@2x.png'; do
  pixels="${specification%% *}"
  filename="${specification#* }"
  /usr/bin/sips -z "${pixels}" "${pixels}" "${ICON_WORK}/icon_1024x1024.png" \
    --out "${ICON_WORK}/TFTMAC-Official.iconset/${filename}" >/dev/null
done
/usr/bin/iconutil -c icns "${ICON_WORK}/TFTMAC-Official.iconset" -o "${RESOURCES_DIR}/TFTMAC-Official.icns"

readonly SIGNING_IDENTITY_HASH="$(/bin/zsh "${ROOT}/scripts/ensure-local-signing-identity.command")"
[[ -n "${SIGNING_IDENTITY_HASH}" ]] || fail "stable local signing identity is unavailable"
/usr/bin/codesign --force --sign "${SIGNING_IDENTITY_HASH}" --timestamp=none "${DIST}"
/usr/bin/codesign --verify --strict --verbose=2 "${DIST}"

[[ "$(/usr/bin/shasum -a 256 "${CONTROL_APP}/Contents/MacOS/TFTMAC" | /usr/bin/awk '{print $1}')" == "${CONTROL_EXECUTABLE_SHA256}" ]] \
  || fail "Control executable changed during wrapper build"
[[ "$(/usr/bin/shasum -a 256 "${CONTROL_APP}/Contents/Resources/TFTMAC Emulator Host.app/Contents/MacOS/TFTMACEmulatorHost" | /usr/bin/awk '{print $1}')" == "${CONTROL_HOST_SHA256}" ]] \
  || fail "Control emulator host changed during wrapper build"

print "TFTMAC Control launcher built without modifying Control: ${DIST}"
