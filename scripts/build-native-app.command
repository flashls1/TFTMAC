#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d /Applications/Xcode-26.6.0.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer
  else
    export DEVELOPER_DIR="$(xcode-select -p)"
  fi
fi
DERIVED="${ROOT}/.build/native-release"
APP="${DERIVED}/Build/Products/Release/TFTMAC.app"
DIST="${ROOT}/dist/TFTMAC.app"
ICON_WORK="$(mktemp -d /private/tmp/tftmac-native-icon.XXXXXX)"

cleanup() {
  /bin/rm -rf "${ICON_WORK}"
}
trap cleanup EXIT

/usr/bin/xcodebuild \
  -quiet \
  -project "${ROOT}/TFTMAC.xcodeproj" \
  -scheme TFTMAC \
  -configuration Release \
  -derivedDataPath "${DERIVED}" \
  CODE_SIGNING_ALLOWED=NO \
  build

[[ -d "${APP}" ]] || { echo "Native build did not produce ${APP}" >&2; exit 1; }
/bin/rm -rf "${DIST}"
/bin/mkdir -p "${ROOT}/dist"
/usr/bin/ditto "${APP}" "${DIST}"

# The Info.plist declares TFTMAC.icns. Generate and embed every required Mac
# representation before signing so Finder and the Dock never show a generic app.
/usr/bin/xcrun swift "${ROOT}/tftmac/GenerateIcon.swift" "${ICON_WORK}/icon_1024x1024.png"
/bin/mkdir -p "${ICON_WORK}/TFTMAC.iconset" "${DIST}/Contents/Resources"
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
    --out "${ICON_WORK}/TFTMAC.iconset/${filename}" >/dev/null
done
/usr/bin/iconutil -c icns "${ICON_WORK}/TFTMAC.iconset" -o "${DIST}/Contents/Resources/TFTMAC.icns"
/bin/cp "${ICON_WORK}/icon_1024x1024.png" "${DIST}/Contents/Resources/TFTMAC-1024.png"

# Package a TFTMAC-owned Mac application host for Android Emulator. Launching
# this nested app with /usr/bin/open keeps the emulator and ADB identity inside
# the logged-in user's macOS session, matching the proven donor architecture.
HOST_APP="${DIST}/Contents/Resources/TFTMAC Emulator Host.app"
HOST_MACOS="${HOST_APP}/Contents/MacOS"
/bin/mkdir -p "${HOST_MACOS}"
/usr/bin/xcrun --sdk macosx clang \
  -Os -arch arm64 -mmacosx-version-min=15.0 \
  "${ROOT}/RuntimeHost/main.c" \
  -o "${HOST_MACOS}/TFTMACEmulatorHost"
/bin/cp "${ROOT}/RuntimeHost/Info.plist" "${HOST_APP}/Contents/Info.plist"
/usr/bin/plutil -lint "${HOST_APP}/Contents/Info.plist" >/dev/null
/usr/bin/codesign --force --sign - --timestamp=none "${HOST_APP}"

/usr/bin/codesign --force --deep --sign - --timestamp=none "${DIST}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${DIST}"

echo "Native TFTMAC built: ${DIST}"
