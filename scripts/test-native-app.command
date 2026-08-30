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
