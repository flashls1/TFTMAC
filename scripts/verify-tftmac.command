#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly ROOT="${0:A:h:h}"
cd "$ROOT"

fail() {
  print -u2 "TFTMAC validation failed: $*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable: $1"
}

for tool in git jq node plutil rg shasum xcodebuild zsh; do
  require_command "$tool"
done

readonly INFO="tftmac/Info.plist"
readonly PACKAGE_RESOLVED="TFTMAC.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
readonly PROTO="Vendor/AndroidEmulator/emulator_controller.proto"
readonly PROTO_SOURCE="Vendor/AndroidEmulator/SOURCE.json"

for required in \
  TFTMAC.xcodeproj/project.pbxproj \
  TFTMAC.xcodeproj/xcshareddata/xcschemes/TFTMAC.xcscheme \
  "$INFO" \
  "$PACKAGE_RESOLVED" \
  "$PROTO" \
  "$PROTO_SOURCE" \
  scripts/build-native-app.command \
  scripts/test-native-app.command; do
  [[ -f "$required" ]] || fail "required file is missing: $required"
done

plutil -lint "$INFO" >/dev/null || fail "Info.plist is invalid"
[[ "$(plutil -extract CFBundleDisplayName raw "$INFO")" == "TFTMAC" ]] || fail "unexpected app display name"
[[ "$(plutil -extract CFBundleExecutable raw "$INFO")" == "TFTMAC" ]] || fail "unexpected app executable"
[[ "$(plutil -extract CFBundleIdentifier raw "$INFO")" == "com.flashls1.tftmac" ]] || fail "unexpected bundle identifier"

readonly PROTO_SHA="$(shasum -a 256 "$PROTO" | awk '{print $1}')"
readonly RECORDED_PROTO_SHA="$(jq -r '.vendoredProtoSHA256' "$PROTO_SOURCE")"
readonly RECORDED_INSTALLED_SHA="$(jq -r '.installedProtoSHA256' "$PROTO_SOURCE")"
[[ "$PROTO_SHA" == "$RECORDED_PROTO_SHA" ]] || fail "vendored EmulatorController proto hash drift"
[[ "$PROTO_SHA" == "$RECORDED_INSTALLED_SHA" ]] || fail "vendored proto no longer matches frozen installed-runtime authority"
jq -e '.schema == 1 and .authority == "INSTALLED_ANDROID_EMULATOR" and .vendoredProtoPath == "Vendor/AndroidEmulator/emulator_controller.proto"' "$PROTO_SOURCE" >/dev/null \
  || fail "EmulatorController provenance is invalid"

jq -e '
  .version == 3 and
  any(.pins[]; .identity == "grpc-swift-2" and .state.version == "2.4.2") and
  any(.pins[]; .identity == "grpc-swift-nio-transport" and .state.version == "2.9.1") and
  any(.pins[]; .identity == "grpc-swift-protobuf" and .state.version == "2.4.1") and
  any(.pins[]; .identity == "swift-protobuf" and .state.version == "1.38.1")
' "$PACKAGE_RESOLVED" >/dev/null || fail "SwiftPM authority pins drifted"

while IFS= read -r script; do
  zsh -o NO_BG_NICE -n "$script" || fail "zsh syntax failed: $script"
done < <(find scripts -type f \( -name '*.command' -o -name '*.sh' \) | LC_ALL=C sort)

node --check tools/tftmac-direct-control.mjs >/dev/null
[[ ! -f tools/tftmac-v2.mjs ]] || node --check tools/tftmac-v2.mjs >/dev/null

node tools/tftmac-direct-control.mjs engineering-map-selftest >/dev/null
node tools/tftmac-direct-control.mjs lab-selftest >/dev/null

if [[ -n "${TFTMAC_FORBIDDEN_TOKEN:-}" ]]; then
  if git ls-files | rg -i -F -- "$TFTMAC_FORBIDDEN_TOKEN"; then
    fail "forbidden retired-product token remains in a tracked path"
  fi
  if git grep -n -i -F -- "$TFTMAC_FORBIDDEN_TOKEN"; then
    fail "forbidden retired-product token remains in tracked content"
  fi
fi

if git ls-files | rg -i '\.(apk|apks|xapk|aab|obb|qcow2|p12|pfx|jks|keystore|mobileprovision)$'; then
  fail "private/generated runtime artifact is tracked"
fi

git diff --check

if [[ "${TFTMAC_SKIP_NATIVE_BUILD:-0}" != "1" ]]; then
  /bin/zsh scripts/build-native-app.command
  /bin/zsh scripts/test-native-app.command
fi

print "TFTMAC validation: OK"
