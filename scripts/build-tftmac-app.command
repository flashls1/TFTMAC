#!/bin/zsh
set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly APP="$PROJECT_DIR/dist/TFTMAC.app"
readonly CONTENTS="$APP/Contents"
readonly MACOS="$CONTENTS/MacOS"
readonly RESOURCES="$CONTENTS/Resources"
readonly SOURCES_DIR="$PROJECT_DIR/tftmac/Sources"
readonly INFO_PLIST="$PROJECT_DIR/tftmac/Info.plist"
readonly ICON_SOURCE="$PROJECT_DIR/tftmac/GenerateIcon.swift"
readonly ICON_WORK="$(mktemp -d /private/tmp/tftmac-icon.XXXXXX)"
readonly INSTALL_ROOT="${TFTMAC_INSTALL_ROOT:-/Applications}"
readonly DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-26.6.0.app/Contents/Developer}"
export DEVELOPER_DIR
readonly INSTALLED_APP="$INSTALL_ROOT/TFTMAC.app"

cleanup() {
    rm -rf "$ICON_WORK"
}
trap cleanup EXIT

[[ -x "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" ]] || { print -u2 "Required Xcode 26.6 toolchain is missing: $DEVELOPER_DIR"; exit 1; }
[[ "$(xcodebuild -version | head -n 1)" == "Xcode 26.6" ]] || { print -u2 "TFTMAC requires Xcode 26.6"; exit 1; }

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES/Tools" "$RESOURCES/ssot" "$PROJECT_DIR/dist"

plutil -lint "$INFO_PLIST" >/dev/null

# Generate a native TFTMAC launcher icon locally. No Android/Emulator branding is used.
xcrun swift "$ICON_SOURCE" "$ICON_WORK/icon_1024x1024.png"
mkdir -p "$ICON_WORK/TFTMAC.iconset"
for spec in \
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
    pixels="${spec%% *}"
    name="${spec#* }"
    sips -z "$pixels" "$pixels" "$ICON_WORK/icon_1024x1024.png" --out "$ICON_WORK/TFTMAC.iconset/$name" >/dev/null
 done
iconutil -c icns "$ICON_WORK/TFTMAC.iconset" -o "$RESOURCES/TFTMAC.icns"
cp -f "$ICON_WORK/icon_1024x1024.png" "$RESOURCES/TFTMAC-1024.png"

# Compile only the new stock-runtime TFTMAC shell. The retired donor/PBE launcher is not linked.
typeset -a SWIFT_SOURCES
SWIFT_SOURCES=("$SOURCES_DIR"/*.swift)
xcrun swiftc \
    -O \
    -swift-version 5 \
    -parse-as-library \
    -target arm64-apple-macosx14.0 \
    "${SWIFT_SOURCES[@]}" \
    -framework AppKit \
    -framework SwiftUI \
    -framework ApplicationServices \
    -o "$MACOS/TFTMAC"

cp -f "$INFO_PLIST" "$CONTENTS/Info.plist"
cp -f "$PROJECT_DIR/tools/tftmac-direct-control.mjs" "$RESOURCES/Tools/tftmac-direct-control.mjs"
chmod 755 "$RESOURCES/Tools/tftmac-direct-control.mjs"
cp -f "$PROJECT_DIR/ssot/TFTMAC_PERFORMANCE_LAB.sql" "$RESOURCES/ssot/TFTMAC_PERFORMANCE_LAB.sql"
cp -f "$PROJECT_DIR/ssot/TFTMAC_ENGINEERING_MAP.sql" "$RESOURCES/ssot/TFTMAC_ENGINEERING_MAP.sql"
cp -f "$PROJECT_DIR/ssot/STACK.lock.yaml" "$RESOURCES/ssot/STACK.lock.yaml"
git -C "$PROJECT_DIR" rev-parse HEAD > "$RESOURCES/Tools/build-commit.txt"

plutil -lint "$CONTENTS/Info.plist" >/dev/null
if rg -n 'CFBundle(DisplayName|Name).*Emulator|<string>Emulator</string>' "$CONTENTS/Info.plist"; then
    print -u2 "TFTMAC app metadata contains legacy Emulator branding."
    exit 1
fi

codesign --force --sign - --timestamp=none --options runtime "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$INSTALL_ROOT"
rm -rf "$INSTALLED_APP"
ditto "$APP" "$INSTALLED_APP"
codesign --verify --deep --strict --verbose=2 "$INSTALLED_APP"

# Launcher smoke: the installed Finder/Dock icon must start the native shell.
pkill -f '/Applications/TFTMAC.app/Contents/MacOS/TFTMAC' 2>/dev/null || true
sleep 0.4
# Remove only TFTMAC's stale private ADB server before app launch. A stale 5040
# listener is not a valid runtime and must never prevent the launcher from booting.
/opt/homebrew/bin/node "$PROJECT_DIR/tools/tftmac-direct-control.mjs" cleanup-tftmac-adb-residue >/dev/null
open -na "$INSTALLED_APP"
sleep 1.5
pgrep -f '/Applications/TFTMAC.app/Contents/MacOS/TFTMAC' >/dev/null || { print -u2 "Installed TFTMAC launcher did not stay running."; exit 1; }

# End-to-end launcher gate: after opening the installed app, the app itself must
# establish exactly one owned emulator/logger/ADB runtime. TFT launch may pause
# at Android secure unlock, which is intentionally a manual security boundary.
typeset runtime_ready=0 runtime_audit=""
for _ in {1..45}; do
    runtime_audit="$(/opt/homebrew/bin/node "$PROJECT_DIR/tools/tftmac-direct-control.mjs" runtime-process-audit 2>/dev/null || true)"
    if [[ -n "$runtime_audit" ]] \
        && print -r -- "$runtime_audit" | jq -e '
            .duplicateRisk.tftmacApps == 1
            and .duplicateRisk.emulators == 1
            and .duplicateRisk.samplers == 1
            and .duplicateRisk.adbServers == 1
        ' >/dev/null 2>&1; then
        runtime_ready=1
        break
    fi
    sleep 1
done
(( runtime_ready == 1 )) || { print -u2 "TFTMAC launcher did not establish its emulator/logger/ADB runtime. Last audit: $runtime_audit"; exit 1; }

print "Built: $APP"
print "Installed: $INSTALLED_APP"
print "Launched: $INSTALLED_APP"
