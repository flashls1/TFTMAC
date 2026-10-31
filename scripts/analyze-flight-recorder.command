#!/bin/zsh
set -euo pipefail

readonly ROOT="${0:A:h:h}"
readonly PYTHON="${TFTMAC_PYTHON:-/opt/homebrew/bin/python3}"
[[ -x "$PYTHON" ]] || { print -u2 "missing Python 3 runtime: $PYTHON"; exit 1; }

if (( $# == 0 )); then
  print -u2 "usage: $0 [--format json|markdown] [--output PATH] CAPTURE_DIR_OR_DATABASE [...]"
  exit 2
fi

exec "$PYTHON" "$ROOT/tools/analyze_native_flight_recorder.py" "$@"
