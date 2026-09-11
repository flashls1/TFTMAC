#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export DEPOT_TOOLS_UPDATE=0
export PATH=/work/depot_tools:/work/depot_tools/.cipd_bin:$PATH
ANGLE_REVISION=1166eec4c0b125e9e945196acfc549983ef72b18
DEPOT_REVISION=81577f19a8497ba7e41afac322e8f03553a863ec
apt-get update
apt-get install -y --no-install-recommends ca-certificates git python3 python3-pip curl xz-utils unzip bzip2 build-essential pkg-config libglib2.0-dev libnss3-dev libx11-dev libxext-dev libxi-dev libxrandr-dev libxcomposite-dev libxcursor-dev libxdamage-dev libxfixes-dev libxrender-dev libxtst-dev libdrm-dev libgbm-dev libegl1-mesa-dev libasound2-dev libpulse-dev libudev-dev zlib1g-dev libatomic1 file sudo lsb-release
mkdir -p /work/depot_tools /work/angle
if [ ! -d /work/depot_tools/.git ]; then
  git -C /work/depot_tools init
  git -C /work/depot_tools remote add origin https://chromium.googlesource.com/chromium/tools/depot_tools.git
  git -C /work/depot_tools fetch --depth=1 origin "$DEPOT_REVISION"
  git -C /work/depot_tools checkout --detach FETCH_HEAD
fi
test "$(git -C /work/depot_tools rev-parse HEAD)" = "$DEPOT_REVISION"
/work/depot_tools/ensure_bootstrap
if [ ! -d /work/angle/.git ]; then
  git -C /work/angle init
  git -C /work/angle remote add origin https://chromium.googlesource.com/angle/angle.git
  git -C /work/angle fetch --depth=1 origin "$ANGLE_REVISION"
  git -C /work/angle checkout --detach FETCH_HEAD
fi
test "$(git -C /work/angle rev-parse HEAD)" = "$ANGLE_REVISION"
cd /work
cat > .gclient <<'EOF'
solutions = [{'name': 'angle', 'url': 'https://chromium.googlesource.com/angle/angle.git', 'managed': False, 'custom_deps': {}, 'custom_vars': {}}]
target_os = ['android']
EOF
gclient sync --no-history --jobs=4 --revision "angle@$ANGLE_REVISION"
gclient revinfo -a > /exchange/angle-dependencies.txt
dpkg-query -W > /exchange/build-packages.txt
git -C /work/depot_tools rev-parse HEAD > /exchange/depot-tools-revision.txt
git -C /work/angle rev-parse HEAD > /exchange/angle-revision.txt
