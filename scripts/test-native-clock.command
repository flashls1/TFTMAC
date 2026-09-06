#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE
readonly ROOT="${0:A:h:h}"
readonly OUTPUT="${ROOT}/.build/clock-handshake"
readonly PYTHON="${TFTMAC_TEST_PYTHON:-/opt/homebrew/bin/python3}"
[[ -x "${PYTHON}" ]] || { print -u2 "Set TFTMAC_TEST_PYTHON to an installed Python 3 runtime"; exit 1; }
/bin/mkdir -p "${OUTPUT}"
/usr/bin/xcrun --sdk macosx clang -std=c11 -O2 -Wall -Wextra -Werror \
  "${ROOT}/CausalRuntime/ClockHandshake.c" -o "${OUTPUT}/tftmac-clock-handshake"
/usr/bin/xcrun --sdk macosx clang -std=c11 -O2 -Wall -Wextra -Werror \
  -DTFTMAC_CLOCK_LIBRARY "${ROOT}/CausalRuntime/ClockHandshake.c" \
  "${ROOT}/CausalRuntime/ClockHandshake_test.c" -o "${OUTPUT}/clock-handshake-tests"
"${OUTPUT}/clock-handshake-tests"
"${PYTHON}" "${ROOT}/CausalRuntime/ClockHandshake_integration_test.py" "${OUTPUT}/tftmac-clock-handshake"
