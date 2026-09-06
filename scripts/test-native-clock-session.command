#!/bin/zsh
set -euo pipefail
readonly ROOT="${0:A:h:h}"
[[ $# == 5 ]] || { print -u2 'Usage: test-native-clock-session.command resources adb 5041 emulator-5586 new-output-directory'; exit 2; }
/bin/mkdir -p "${ROOT}/.build/native-clock-tests"
/usr/bin/xcrun swiftc -parse-as-library -O \
  "${ROOT}/tftmac/Runtime/NativeClockSample.swift" \
  "${ROOT}/CausalRuntime/NativeClockSession_integration_test.swift" \
  -o "${ROOT}/.build/native-clock-tests/clock-session-integration-test"
exec "${ROOT}/.build/native-clock-tests/clock-session-integration-test" "$@"
