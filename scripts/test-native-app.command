#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-26.6.0.app/Contents/Developer}"
DERIVED="${ROOT}/.build/native-tests"

/usr/bin/xcodebuild \
  -quiet \
  -project "${ROOT}/TFTMAC.xcodeproj" \
  -scheme TFTMAC \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "${DERIVED}" \
  CODE_SIGNING_ALLOWED=NO \
  test
