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
  Generated/EmulatorController/emulator_controller.pb.swift \
  Generated/EmulatorController/emulator_controller.grpc.swift \
  scripts/generate-emulator-proto.command \
  scripts/build-tftmac-app.command \
  scripts/build-native-app.command \
  scripts/test-native-app.command \
  ssot/STACK.lock.yaml \
  ssot/runtime-authority.json; do
  [[ -f "$required" ]] || fail "required file is missing: $required"
done

plutil -lint "$INFO" >/dev/null || fail "Info.plist is invalid"
[[ "$(plutil -extract CFBundleDisplayName raw "$INFO")" == "TFTMAC" ]] || fail "unexpected app display name"
[[ "$(plutil -extract CFBundleExecutable raw "$INFO")" == "TFTMAC" ]] || fail "unexpected app executable"
[[ "$(plutil -extract CFBundleIdentifier raw "$INFO")" == "com.flashls1.tftmac" ]] || fail "unexpected bundle identifier"

# There is one executable build authority. The compatibility entrypoint may
# delegate to it, but it may never rebuild or install the retired Node shell.
rg -q -F 'scripts/build-native-app.command' scripts/build-tftmac-app.command \
  || fail "compatibility build entrypoint does not delegate to the native build"
if rg -n 'tftmac/Sources|tftmac-direct-control|5040|5592|swiftc' scripts/build-tftmac-app.command; then
  fail "compatibility build entrypoint still contains a retired build/runtime path"
fi
if rg -n 'TFTMACRuntimeBridge|TFTMACViews|TFTMACWindowCoordinator' TFTMAC.xcodeproj/project.pbxproj; then
  fail "native Xcode target references the retired Node shell"
fi

jq -e '
  .schema == 2 and .result == "PASS" and
  .emulator.avd == "TFT_Ultra_Tablet" and
  .emulator.adbSerial == "emulator-5582" and
  .emulator.adbServerPort == 5038 and
  .emulator.consolePort == 5582 and
  .emulator.adbVendorKeysInjected == false and
  .runtimeProfile.vcpu == 6 and
  .runtimeProfile.ramMiB == 5120 and
  .runtimeProfile.display == "1920x1080"
' ssot/runtime-authority.json >/dev/null || fail "native runtime authority drifted"

for locked in \
  'mode: "released_native_runtime"' \
  'avd_name: "TFT_Ultra_Tablet"' \
  'emulator_console_port: 5582' \
  'adb_serial: "emulator-5582"' \
  'adb_server_port: 5038' \
  'ram_mb: 5120' \
  'selected: A' \
  'mac_icon_embedded: true' \
  'unit_tests_passed: 14'; do
  rg -q -F -- "$locked" ssot/STACK.lock.yaml || fail "active stack lock drifted: $locked"
done

readonly PROTO_SHA="$(shasum -a 256 "$PROTO" | awk '{print $1}')"
readonly RECORDED_PROTO_SHA="$(jq -r '.vendoredProtoSHA256' "$PROTO_SOURCE")"
readonly RECORDED_INSTALLED_SHA="$(jq -r '.installedProtoSHA256' "$PROTO_SOURCE")"
[[ "$PROTO_SHA" == "$RECORDED_PROTO_SHA" ]] || fail "vendored EmulatorController proto hash drift"
[[ "$PROTO_SHA" == "$RECORDED_INSTALLED_SHA" ]] || fail "vendored proto no longer matches frozen installed-runtime authority"
jq -e '.schema == 1 and .authority == "INSTALLED_ANDROID_EMULATOR" and .vendoredProtoPath == "Vendor/AndroidEmulator/emulator_controller.proto" and .generator.protocVersion == "36.0" and .generator.swiftProtobufVersion == "1.38.1" and .generator.grpcSwiftProtobufVersion == "2.4.1"' "$PROTO_SOURCE" >/dev/null \
  || fail "EmulatorController provenance is invalid"

readonly GENERATED_PB_SHA="$(shasum -a 256 Generated/EmulatorController/emulator_controller.pb.swift | awk '{print $1}')"
readonly GENERATED_GRPC_SHA="$(shasum -a 256 Generated/EmulatorController/emulator_controller.grpc.swift | awk '{print $1}')"
[[ "$GENERATED_PB_SHA" == "$(jq -r '.generatedSources["Generated/EmulatorController/emulator_controller.pb.swift"]' "$PROTO_SOURCE")" ]] || fail "generated Swift protobuf source drift"
[[ "$GENERATED_GRPC_SHA" == "$(jq -r '.generatedSources["Generated/EmulatorController/emulator_controller.grpc.swift"]' "$PROTO_SOURCE")" ]] || fail "generated Swift gRPC source drift"

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
  [[ -s dist/TFTMAC.app/Contents/Resources/TFTMAC.icns ]] || fail "native app icon is missing"
  [[ -s dist/TFTMAC.app/Contents/Resources/TFTMAC-1024.png ]] || fail "native app icon source is missing"
  /bin/zsh scripts/test-native-app.command
fi

print "TFTMAC validation: OK"
