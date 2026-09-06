#!/bin/zsh
set -euo pipefail
readonly ROOT="${0:A:h:h}"
readonly OUTPUT="${ROOT}/.build/native-clock/NativeClock"
readonly NDK="${TFTMAC_ANDROID_NDK_ROOT:-/Volumes/MAC MINI M4/TFTMAC-RUNTIME-DATA/SDK/ndk/29.0.14206865}"
readonly TOOLCHAIN="${NDK}/toolchains/llvm/prebuilt/darwin-x86_64"
readonly PYTHON="${TFTMAC_TEST_PYTHON:-/opt/homebrew/bin/python3}"
[[ -x "${TOOLCHAIN}/bin/clang" && -x "${PYTHON}" ]]
/bin/mkdir -p "${OUTPUT}"
/usr/bin/xcrun --sdk macosx clang -std=c11 -O2 -Wall -Wextra -Werror \
  "${ROOT}/CausalRuntime/ClockHandshake.c" -o "${OUTPUT}/tftmac-clock-host"
"${TOOLCHAIN}/bin/clang" --target=aarch64-linux-android26 \
  --sysroot="${TOOLCHAIN}/sysroot" -std=c11 -O2 -Wall -Wextra -Werror \
  "${ROOT}/CausalRuntime/ClockHandshake.c" -o "${OUTPUT}/tftmac-clock-android"
if [[ -n "${TFTMAC_CLOCK_SIGN_IDENTITY:-}" ]]; then
  /usr/bin/codesign --force --sign "${TFTMAC_CLOCK_SIGN_IDENTITY}" --timestamp=none \
    "${OUTPUT}/tftmac-clock-host"
fi
"${TOOLCHAIN}/bin/clang" --version > "${OUTPUT}/android-toolchain.txt"
"${PYTHON}" - "${OUTPUT}" <<'PY'
import hashlib, json, sys
from pathlib import Path
p = Path(sys.argv[1])
names = ['tftmac-clock-host', 'tftmac-clock-android']
(p / 'manifest.json').write_text(json.dumps({n: hashlib.sha256((p / n).read_bytes()).hexdigest()
                                            for n in names}, indent=2) + '\n')
PY
print "Native clock helpers built: ${OUTPUT}"
