#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly ROOT="${0:A:h:h}"
readonly OUTPUT="${ROOT}/.build/causal-runtime/PipelineEventV1_test"
/bin/mkdir -p "${OUTPUT:h}"
/usr/bin/xcrun --sdk macosx clang++ \
  -std=c++20 -O2 -Wall -Wextra -Werror \
  -I "${ROOT}/CausalRuntime" \
  "${ROOT}/CausalRuntime/PipelineEventV1.cpp" \
  "${ROOT}/CausalRuntime/PipelineEventV1_test.cpp" \
  -o "${OUTPUT}"
"${OUTPUT}"
print "TFTMAC causal runtime ABI: PASS (96-byte event; strict owned-probe label parser)"
