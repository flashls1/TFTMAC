#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly LEGACY_SOURCE="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Sources/aemu"
readonly SOURCE_IMAGE_ROOT="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/SourceVolumes"
readonly SOURCE_IMAGE="${SOURCE_IMAGE_ROOT}/TFTMAC-Causal-Source.sparsebundle"
readonly SOURCE_VOLUME_NAME="TFTMAC Causal Source"
readonly SOURCE_MOUNT="/Volumes/${SOURCE_VOLUME_NAME}"
readonly SOURCE_ROOT="${SOURCE_MOUNT}/emu-main-dev-2692acc6"
readonly RECEIPT_ROOT="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Manifests/causal-source-20260902"
readonly REPO_LAUNCHER="${LEGACY_SOURCE}/.repo/repo/repo"
readonly MANIFEST_URL="https://android.googlesource.com/platform/manifest"
readonly MANIFEST_BRANCH="emu-main-dev"
readonly MANIFEST_COMMIT="2692acc620f6563b21995540656674faeb536cdc"

fail() { print -u2 "TFTMAC causal source preparation failed: $*"; exit 1; }

[[ -x "${REPO_LAUNCHER}" ]] || fail "Android repo launcher is unavailable"
[[ -d "${LEGACY_SOURCE}/.repo" ]] || fail "preserved reference checkout is unavailable"
if /bin/ps -axo command | /usr/bin/grep -E '/Applications/TFTMAC( DEV)?\.app/Contents/MacOS/' | /usr/bin/grep -v grep >/dev/null; then
  fail "Control or DEV is running; source synchronization is intentionally deferred"
fi

/bin/mkdir -p "${SOURCE_IMAGE_ROOT}" "${RECEIPT_ROOT}"
if [[ ! -e "${SOURCE_IMAGE}" ]]; then
  /usr/bin/hdiutil create \
    -quiet \
    -type SPARSEBUNDLE \
    -size 180g \
    -fs "Case-sensitive APFS" \
    -volname "${SOURCE_VOLUME_NAME}" \
    "${SOURCE_IMAGE}"
fi
if [[ ! -d "${SOURCE_MOUNT}" ]]; then
  /usr/bin/hdiutil attach -quiet -nobrowse -owners on "${SOURCE_IMAGE}"
fi
[[ -d "${SOURCE_MOUNT}" ]] || fail "case-sensitive source volume did not mount"
readonly CASE_PROBE_UPPER="${SOURCE_MOUNT}/.TFTMAC_CASE_PROBE"
readonly CASE_PROBE_LOWER="${SOURCE_MOUNT}/.tftmac_case_probe"
/usr/bin/touch "${CASE_PROBE_UPPER}"
if [[ -e "${CASE_PROBE_LOWER}" ]]; then
  /bin/rm -f "${CASE_PROBE_UPPER}"
  fail "source volume is not case-sensitive"
fi
/bin/rm -f "${CASE_PROBE_UPPER}"

/bin/mkdir -p "${SOURCE_ROOT}"
if [[ ! -d "${SOURCE_ROOT}/.repo" ]]; then
  (
    cd "${SOURCE_ROOT}"
    "${REPO_LAUNCHER}" init \
      -u "${MANIFEST_URL}" \
      -b "${MANIFEST_BRANCH}" \
      --reference="${LEGACY_SOURCE}" \
      --no-clone-bundle \
      --no-tags
  )
fi

/usr/bin/git -C "${SOURCE_ROOT}/.repo/manifests" fetch origin "${MANIFEST_COMMIT}"
/usr/bin/git -C "${SOURCE_ROOT}/.repo/manifests" checkout --detach "${MANIFEST_COMMIT}"
(
  cd "${SOURCE_ROOT}"
  "${REPO_LAUNCHER}" sync -c -j4 --no-clone-bundle --no-tags
  "${REPO_LAUNCHER}" manifest -r -o "${RECEIPT_ROOT}/source-lock.xml"
)

readonly MANIFEST_HEAD="$(/usr/bin/git -C "${SOURCE_ROOT}/.repo/manifests" rev-parse HEAD)"
[[ "${MANIFEST_HEAD}" == "${MANIFEST_COMMIT}" ]] || fail "manifest commit drifted"
for project in external/qemu hardware/google/gfxstream external/moltenvk; do
  [[ -d "${SOURCE_ROOT}/${project}/.git" || -f "${SOURCE_ROOT}/${project}/.git" ]] \
    || fail "required project is missing: ${project}"
done

/usr/bin/jq -n \
  --arg state "CAUSAL_SOURCE_LOCK_PASS" \
  --arg source_root "${SOURCE_ROOT}" \
  --arg source_image "${SOURCE_IMAGE}" \
  --arg source_mount "${SOURCE_MOUNT}" \
  --arg manifest_commit "${MANIFEST_COMMIT}" \
  --arg manifest_sha256 "$(/usr/bin/shasum -a 256 "${RECEIPT_ROOT}/source-lock.xml" | /usr/bin/awk '{print $1}')" \
  --arg qemu_commit "$(/usr/bin/git -C "${SOURCE_ROOT}/external/qemu" rev-parse HEAD)" \
  --arg gfxstream_commit "$(/usr/bin/git -C "${SOURCE_ROOT}/hardware/google/gfxstream" rev-parse HEAD)" \
  --arg moltenvk_commit "$(/usr/bin/git -C "${SOURCE_ROOT}/external/moltenvk" rev-parse HEAD)" \
  '{schema:1,state:$state,source_root:$source_root,source_storage:{image:$source_image,mount:$source_mount,filesystem:"case-sensitive APFS",sparse_maximum_bytes:193273528320},manifest_commit:$manifest_commit,revision_locked_manifest:{path:"source-lock.xml",sha256:$manifest_sha256},projects:{qemu:$qemu_commit,gfxstream:$gfxstream_commit,moltenvk:$moltenvk_commit},sync_jobs:4,control_touched:false,legacy_dirty_source_touched:false}' \
  > "${RECEIPT_ROOT}/source-receipt.json"

print "TFTMAC causal source: READY (${SOURCE_ROOT})"
