#!/bin/bash
set -euo pipefail
cd /work/angle
test "$(git rev-parse HEAD)" = 1166eec4c0b125e9e945196acfc549983ef72b18
compiler=/work/angle/third_party/llvm-build/Release+Asserts/bin/clang
sysroot=/work/angle/third_party/android_toolchain/ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot
flags=(--target=aarch64-linux-android26 --sysroot="$sysroot" -fuse-ld=lld --unwindlib=none -std=c11 -Wall -Wextra -Werror -O2)
"$compiler" "${flags[@]}" /exchange/clock/ClockHandshake.c -o /exchange/clock/tftmac-clock-handshake-android
"$compiler" "${flags[@]}" -DTFTMAC_CLOCK_LIBRARY /exchange/clock/ClockHandshake.c /exchange/clock/ClockHandshake_test.c -o /exchange/clock/clock-handshake-tests-android
"$compiler" --version > /exchange/clock/toolchain.txt
/work/angle/third_party/llvm-build/Release+Asserts/bin/llvm-readelf -h -l -d /exchange/clock/tftmac-clock-handshake-android > /exchange/clock/android-elf.txt
sha256sum /exchange/clock/ClockHandshake.c /exchange/clock/ClockHandshake.h /exchange/clock/ClockHandshake_test.c /exchange/clock/tftmac-clock-handshake-android /exchange/clock/clock-handshake-tests-android > /exchange/clock/build.sha256
