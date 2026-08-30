#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-26.6.0.app/Contents/Developer}"
DERIVED="${ROOT}/.build/native-release"
APP="${DERIVED}/Build/Products/Release/TFTMAC.app"
DIST="${ROOT}/dist/TFTMAC.app"

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
/usr/bin/codesign --force --deep --sign - --timestamp=none "${DIST}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${DIST}"

echo "Native TFTMAC built: ${DIST}"
