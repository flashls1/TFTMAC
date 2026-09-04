#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly DEV_APP="/Applications/TFTMAC DEV.app"
readonly KEYCHAIN_SERVICE="com.flashls1.tftmac.android-unlock.v2"
readonly KEYCHAIN_ACCOUNT="android-user-0"

fail() { print -u2 "TFTMAC unlock setup failed: $*"; exit 1; }
[[ -d "${DEV_APP}" ]] || fail "TFTMAC DEV is not installed"
if /usr/bin/pgrep -f '/Applications/TFTMAC( DEV)?\.app/Contents/MacOS/|@TFTMAC(_Diagnostic)?' >/dev/null; then
  fail "Control or DEV is already running"
fi

/usr/bin/open -n -W --env "TFTMAC_UNLOCK_SETUP_ONLY=1" "${DEV_APP}"
/usr/bin/security find-generic-password \
  -s "${KEYCHAIN_SERVICE}" \
  -a "${KEYCHAIN_ACCOUNT}" \
  "${HOME}/Library/Keychains/login.keychain-db" >/dev/null \
  || fail "the secure Keychain item was not created"
print "TFTMAC Android unlock setup: PASS"
