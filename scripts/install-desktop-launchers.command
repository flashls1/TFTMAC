#!/bin/zsh
set -euo pipefail

readonly ROOT="${0:A:h:h}"
readonly CONTROL_APP="/Applications/TFTMAC.app"
readonly CONTROL_LAUNCHER_SOURCE="${ROOT}/dist/TFTMAC Control Launcher.app"
readonly CONTROL_LAUNCHER_APP="/Applications/TFTMAC Control Launcher.app"
readonly DEV_SOURCE="${ROOT}/dist/TFTMAC DEV.app"
readonly DEV_APP="/Applications/TFTMAC DEV.app"
readonly CONTROL_DESKTOP="${HOME}/Desktop/TFTMAC.app"
readonly DEV_DESKTOP="${HOME}/Desktop/TFTMAC DEV.app"
readonly CONTROL_EXECUTABLE_SHA256="d3bf7c249a3e5f11b81f778b063e1a8cfe2e7fdeec0537ee6bd8447b1c2268d2"
readonly CONTROL_HOST_SHA256="ea028ec1d74cc025638c2a0e5f8c783748803c1b0ba9012962c038251fb3eb63"

fail() {
  print -u2 "TFTMAC launcher install failed: $*"
  exit 1
}

[[ -d "${CONTROL_APP}" ]] || fail "protected Control app is missing"
[[ -d "${CONTROL_LAUNCHER_SOURCE}" ]] || fail "build the TFTMAC Control launcher first"
[[ -d "${DEV_SOURCE}" ]] || fail "build TFTMAC DEV first"
[[ "$(/usr/bin/shasum -a 256 "${CONTROL_APP}/Contents/MacOS/TFTMAC" | /usr/bin/awk '{print $1}')" == "${CONTROL_EXECUTABLE_SHA256}" ]] \
  || fail "protected Control executable identity changed"
[[ "$(/usr/bin/shasum -a 256 "${CONTROL_APP}/Contents/Resources/TFTMAC Emulator Host.app/Contents/MacOS/TFTMACEmulatorHost" | /usr/bin/awk '{print $1}')" == "${CONTROL_HOST_SHA256}" ]] \
  || fail "protected Control emulator-host identity changed"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${DEV_SOURCE}"
/usr/bin/codesign --verify --strict --verbose=2 "${CONTROL_LAUNCHER_SOURCE}"
[[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "${DEV_SOURCE}/Contents/Info.plist")" == "com.flashls1.tftmac.dev" ]] \
  || fail "DEV source bundle identity is not isolated"

/bin/rm -rf "${DEV_APP}"
/usr/bin/ditto "${DEV_SOURCE}" "${DEV_APP}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${DEV_APP}"
/bin/rm -rf "${CONTROL_LAUNCHER_APP}"
/usr/bin/ditto "${CONTROL_LAUNCHER_SOURCE}" "${CONTROL_LAUNCHER_APP}"
/usr/bin/codesign --verify --strict --verbose=2 "${CONTROL_LAUNCHER_APP}"

if [[ -L "${CONTROL_DESKTOP}" ]]; then
  /bin/rm "${CONTROL_DESKTOP}"
elif [[ -e "${CONTROL_DESKTOP}" ]]; then
  fail "Desktop TFTMAC.app exists but is not the protected Control launcher"
fi
/bin/ln -s "${CONTROL_LAUNCHER_APP}" "${CONTROL_DESKTOP}"

if [[ -L "${DEV_DESKTOP}" ]]; then
  [[ "$(/usr/bin/readlink "${DEV_DESKTOP}")" == "${DEV_APP}" ]] \
    || fail "existing Desktop TFTMAC DEV launcher points somewhere unexpected"
elif [[ -e "${DEV_DESKTOP}" ]]; then
  fail "Desktop TFTMAC DEV.app exists and was not replaced"
else
  /bin/ln -s "${DEV_APP}" "${DEV_DESKTOP}"
fi

[[ "$(/usr/bin/shasum -a 256 "${CONTROL_APP}/Contents/MacOS/TFTMAC" | /usr/bin/awk '{print $1}')" == "${CONTROL_EXECUTABLE_SHA256}" ]] \
  || fail "Control executable changed during DEV installation"
[[ "$(/usr/bin/shasum -a 256 "${CONTROL_APP}/Contents/Resources/TFTMAC Emulator Host.app/Contents/MacOS/TFTMACEmulatorHost" | /usr/bin/awk '{print $1}')" == "${CONTROL_HOST_SHA256}" ]] \
  || fail "Control emulator host changed during DEV installation"

print "Control launcher: ${CONTROL_DESKTOP} -> ${CONTROL_LAUNCHER_APP} -> ${CONTROL_APP}"
print "Developer launcher: ${DEV_DESKTOP} -> ${DEV_APP}"
