#!/bin/bash
set -euo pipefail
export DEPOT_TOOLS_UPDATE=0
export PATH=/work/depot_tools:/work/depot_tools/.cipd_bin:$PATH
cd /work/angle
test "$(git rev-parse HEAD)" = 1166eec4c0b125e9e945196acfc549983ef72b18
test -z "$(git diff --name-only)"
mkdir -p out/tftmac-reference
cat > out/tftmac-reference/args.gn <<'EOF'
target_os = "android"
target_cpu = "arm64"
is_component_build = false
is_debug = false
symbol_level = 1
angle_assert_always_on = false
angle_with_capture_by_default = false
use_remoteexec = false
EOF
gn gen out/tftmac-reference
autoninja -C out/tftmac-reference -j4 libEGL libGLESv2 angle_apks
mkdir -p /exchange/reference
cp out/tftmac-reference/args.gn /exchange/reference/
cp out/tftmac-reference/libEGL_angle.so out/tftmac-reference/libGLESv2_angle.so out/tftmac-reference/libGLESv1_CM_angle.so out/tftmac-reference/libfeature_support_angle.so /exchange/reference/
cp out/tftmac-reference/apks/AngleLibraries.apk /exchange/reference/
mkdir -p /exchange/reference-symbols
cp out/tftmac-reference/lib.unstripped/*_angle.so /exchange/reference-symbols/
sha256sum /exchange/reference/* > /exchange/reference.sha256
