#!/bin/bash
set -euo pipefail
export DEPOT_TOOLS_UPDATE=0
export PATH=/work/depot_tools:/work/depot_tools/.cipd_bin:$PATH
cd /work/angle
test "$(git rev-parse HEAD)" = 1166eec4c0b125e9e945196acfc549983ef72b18
test -s /exchange/reference.sha256
sha256sum -c /exchange/reference.sha256
if ! git apply --reverse --check /exchange/angle-buffer-view-reuse-complete.patch; then
    test -z "$(git diff --name-only)"
    git apply --check /exchange/angle-buffer-view-reuse-complete.patch
    git apply /exchange/angle-buffer-view-reuse-complete.patch
fi
# Generated feature files are part of the complete pinned patch. Regenerating
# identical files here changes their mtimes and needlessly rebuilds all tests.
git diff --check
git diff > /tmp/tftmac-current-driver.patch
cmp /tmp/tftmac-current-driver.patch /exchange/angle-buffer-view-reuse-complete.patch
# Reuse the reference build's object cache with identical GN arguments. The
# immutable reference binaries are already sealed separately in /exchange.
if ! cmp -s /exchange/reference/args.gn out/tftmac-reference/args.gn; then
    cp /exchange/reference/args.gn out/tftmac-reference/args.gn
    gn gen out/tftmac-reference
fi
autoninja -C out/tftmac-reference -j4 libEGL libGLESv2 angle_apks angle_end2end_tests
mkdir -p /exchange/reuse /exchange/reuse-symbols
cp out/tftmac-reference/args.gn /exchange/reuse/
cp out/tftmac-reference/libEGL_angle.so out/tftmac-reference/libGLESv2_angle.so out/tftmac-reference/libGLESv1_CM_angle.so out/tftmac-reference/libfeature_support_angle.so /exchange/reuse/
cp out/tftmac-reference/apks/AngleLibraries.apk /exchange/reuse/
cp out/tftmac-reference/angle_end2end_tests_apk/angle_end2end_tests-debug.apk /exchange/reuse/
cp out/tftmac-reference/lib.unstripped/*_angle.so /exchange/reuse-symbols/
sha256sum /exchange/reuse/* > /exchange/reuse.sha256
