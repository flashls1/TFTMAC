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

for tool in codesign git jq node plutil rg security shasum xcodebuild zsh; do
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
  tftmac/Assets/TFTMAC-Official-Icon.png \
  Generated/EmulatorController/emulator_controller.pb.swift \
  Generated/EmulatorController/emulator_controller.grpc.swift \
  scripts/generate-emulator-proto.command \
  scripts/build-tftmac-app.command \
  scripts/build-native-app.command \
  scripts/install-trace-processor.command \
  scripts/ensure-local-signing-identity.command \
  scripts/test-native-app.command \
  ssot/STACK.lock.yaml \
  ssot/runtime-authority.json; do
  [[ -f "$required" ]] || fail "required file is missing: $required"
done

plutil -lint "$INFO" >/dev/null || fail "Info.plist is invalid"
[[ "$(plutil -extract CFBundleDisplayName raw "$INFO")" == "TFTMAC" ]] || fail "unexpected app display name"
[[ "$(plutil -extract CFBundleExecutable raw "$INFO")" == "TFTMAC" ]] || fail "unexpected app executable"
[[ "$(plutil -extract CFBundleIdentifier raw "$INFO")" == "com.flashls1.tftmac" ]] || fail "unexpected bundle identifier"
readonly INFO_VERSION="$(plutil -extract CFBundleShortVersionString raw "$INFO")"
readonly INFO_BUILD="$(plutil -extract CFBundleVersion raw "$INFO")"
readonly AUTHORITY_VERSION="$(jq -r '.finalInstalledRelease.version' ssot/runtime-authority.json)"
readonly AUTHORITY_BUILD="$(jq -r '.finalInstalledRelease.build' ssot/runtime-authority.json)"
[[ "$INFO_VERSION" == "$AUTHORITY_VERSION" ]] || fail "source and release-authority versions differ"
[[ "$INFO_BUILD" == "$AUTHORITY_BUILD" ]] || fail "source and release-authority builds differ"
[[ "$(plutil -extract NSRemovableVolumesUsageDescription raw "$INFO")" == *"Android emulator runtime"* ]] \
  || fail "removable-volume purpose string is missing"

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
  .runtimeProfile.display == "1920x1080" and
  .finalInstalledRelease.version == "2.2.0" and
  .finalInstalledRelease.build == "6" and
  .finalInstalledRelease.officialIconSourceSHA256 == "d6ba9ceb76c4b1e44e87f059f775a0ed629f9bea29b0dd73245853d7dca3a016" and
  .finalInstalledRelease.officialIcon1024SHA256 == "ed5fd83efa6e04599e82ca00f897b09813cdeac007850f6993efd601a730345f" and
  .finalInstalledRelease.embeddedIconICNSSHA256 == "010729a19f165b68edeb1fb44e8c31e450f79b3a988c95b8de090373378f6f06" and
  .finalInstalledRelease.signingIdentity == "TFTMAC Local Code Signing" and
  .finalInstalledRelease.adHocSigned == false and
  .finalInstalledRelease.removableVolumePermissionRetainedAcrossRelaunch == true and
  .finalInstalledRelease.nonErrorUnlockOverlayVisible == false and
  .finalInstalledRelease.unitTestsPassed == 36 and
  .finalInstalledRelease.primaryInputTransport == "EmulatorController.sendTouch" and
  .androidWebView.currentVersion == "151.0.7922.199"
' ssot/runtime-authority.json >/dev/null || fail "native runtime authority drifted"

for locked in \
  'mode: "released_native_runtime"' \
  'avd_name: "TFT_Ultra_Tablet"' \
  'emulator_console_port: 5582' \
  'adb_serial: "emulator-5582"' \
  'adb_server_port: 5038' \
  'ram_mb: 5120' \
  'selected: A' \
  'version: "2.2.0"' \
  'build: "6"' \
  'official_icon_source_sha256: "d6ba9ceb76c4b1e44e87f059f775a0ed629f9bea29b0dd73245853d7dca3a016"' \
  'official_icon_1024_sha256: "ed5fd83efa6e04599e82ca00f897b09813cdeac007850f6993efd601a730345f"' \
  'embedded_icon_icns_sha256: "010729a19f165b68edeb1fb44e8c31e450f79b3a988c95b8de090373378f6f06"' \
  'signing: "stable_local_identity_valid"' \
  'mac_icon_embedded: true' \
  'removable_volume_permission_relaunch: PASS' \
  'non_error_unlock_overlay: ABSENT' \
  'unit_tests_passed: 36' \
  'webview_version: "151.0.7922.199"'; do
  rg -q -F -- "$locked" ssot/STACK.lock.yaml || fail "active stack lock drifted: $locked"
done

readonly TEST_FUNCTION_COUNT="$(rg -n '^[[:space:]]*func test' Tests/TFTMACTests --glob '*.swift' | wc -l | tr -d '[:space:]')"
[[ "$TEST_FUNCTION_COUNT" == "36" ]] || fail "native test inventory drifted: expected 36, found $TEST_FUNCTION_COUNT"
[[ "$(shasum -a 256 tftmac/Assets/TFTMAC-Official-Icon.png | awk '{print $1}')" == "d6ba9ceb76c4b1e44e87f059f775a0ed629f9bea29b0dd73245853d7dca3a016" ]] \
  || fail "official TFTMAC icon source hash drifted"

readonly INSTALLED_APP="/Applications/TFTMAC.app"
[[ -d "$INSTALLED_APP" ]] || fail "released native app is not installed"
codesign --verify --deep --strict "$INSTALLED_APP" || fail "installed native app signature is invalid"
[[ "$(plutil -extract CFBundleShortVersionString raw "$INSTALLED_APP/Contents/Info.plist")" == "$INFO_VERSION" ]] \
  || fail "installed app version differs from source"
[[ "$(plutil -extract CFBundleVersion raw "$INSTALLED_APP/Contents/Info.plist")" == "$INFO_BUILD" ]] \
  || fail "installed app build differs from source"
readonly INSTALLED_EXECUTABLE_SHA="$(shasum -a 256 "$INSTALLED_APP/Contents/MacOS/TFTMAC" | awk '{print $1}')"
[[ "$INSTALLED_EXECUTABLE_SHA" == "$(jq -r '.finalInstalledRelease.executableSHA256' ssot/runtime-authority.json)" ]] \
  || fail "installed executable hash differs from release authority"
[[ "$(shasum -a 256 "$INSTALLED_APP/Contents/Resources/TFTMAC-1024.png" | awk '{print $1}')" == "$(jq -r '.finalInstalledRelease.officialIcon1024SHA256' ssot/runtime-authority.json)" ]] \
  || fail "installed 1024px icon differs from release authority"
[[ "$(shasum -a 256 "$INSTALLED_APP/Contents/Resources/TFTMAC.icns" | awk '{print $1}')" == "$(jq -r '.finalInstalledRelease.embeddedIconICNSSHA256' ssot/runtime-authority.json)" ]] \
  || fail "installed ICNS differs from release authority"

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
  [[ "$(shasum -a 256 dist/TFTMAC.app/Contents/Resources/trace_processor_shell | awk '{print $1}')" == "d29864d1ba3b36855527bb1b0ca3aa7f703cdce338b9680bb922c5c151b358fa" ]] \
    || fail "pinned Perfetto trace_processor is missing or invalid"
  /bin/zsh scripts/test-native-app.command
fi

print "TFTMAC validation: OK"
