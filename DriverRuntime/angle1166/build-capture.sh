#!/bin/bash
set -euo pipefail
export DEPOT_TOOLS_UPDATE=0
export PATH=/work/depot_tools:/work/depot_tools/.cipd_bin:$PATH
cd /work/angle
test "$(git rev-parse HEAD)" = 1166eec4c0b125e9e945196acfc549983ef72b18
git diff --check
git diff > /tmp/tftmac-current-driver.patch
cmp /tmp/tftmac-current-driver.patch /exchange/angle-buffer-view-reuse-complete.patch
# Reuse objects only after the non-capture variants have been exported.
sha256sum -c /exchange/reuse.sha256
sed -i 's/angle_with_capture_by_default = false/angle_with_capture_by_default = true/' out/tftmac-reference/args.gn
gn gen out/tftmac-reference
autoninja -C out/tftmac-reference -j4 libEGL libGLESv2 angle_apks angle_end2end_tests
mkdir -p /exchange/capture /exchange/capture-symbols
cp out/tftmac-reference/args.gn /exchange/capture/
cp out/tftmac-reference/libEGL_angle.so out/tftmac-reference/libGLESv2_angle.so out/tftmac-reference/libGLESv1_CM_angle.so out/tftmac-reference/libfeature_support_angle.so /exchange/capture/
cp out/tftmac-reference/apks/AngleLibraries.apk /exchange/capture/
cp out/tftmac-reference/angle_end2end_tests_apk/angle_end2end_tests-debug.apk /exchange/capture/
cp out/tftmac-reference/lib.unstripped/*_angle.so /exchange/capture-symbols/
sha256sum /exchange/capture/* > /exchange/capture.sha256
