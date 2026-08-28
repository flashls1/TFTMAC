#!/bin/zsh
set -euo pipefail

console_user="$(/usr/bin/stat -f '%Su' /dev/console)"
if [[ -z "$console_user" || "$console_user" == "root" || "$console_user" == "loginwindow" ]]; then
  print -u2 "TFTMAC: could not resolve the logged-in macOS user."
  exit 1
fi

user_home="$(/usr/bin/dscl . -read "/Users/$console_user" NFSHomeDirectory | /usr/bin/awk '{print $2}')"
if [[ -z "$user_home" ]]; then
  print -u2 "TFTMAC: could not resolve the logged-in user's home directory."
  exit 1
fi

sdk_root="$user_home/Library/Application Support/TFTMAC/Runtime/SDK"
sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"

if [[ ! -x "$sdkmanager" ]]; then
  print -u2 "TFTMAC: isolated sdkmanager is not installed at:"
  print -u2 "  $sdkmanager"
  print -u2 "Run Phase 0 Android bootstrap first."
  exit 1
fi

export ANDROID_SDK_ROOT="$sdk_root"
export ANDROID_HOME="$sdk_root"

cat <<'EOF'
TFTMAC Android SDK license gate

This command is intentionally interactive. Review Google's license text yourself.
Nothing in TFTMAC auto-accepts Android SDK terms on your behalf.

Accept only terms you agree to. When complete, TFTMAC Phase 0 will detect the
license files in its isolated SDK and continue package installation.
EOF

exec "$sdkmanager" --sdk_root="$sdk_root" --licenses
