#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly ROOT="${0:A:h:h}"
readonly SOURCE="${ROOT}/Probes/TFTMACVulkanProbe"
readonly SDK="/Volumes/MAC MINI M4/TFTMAC-RUNTIME-DATA/SDK"
readonly NDK="${SDK}/ndk/29.0.14206865"
readonly TOOLCHAIN="${NDK}/toolchains/llvm/prebuilt/darwin-x86_64"
readonly BUILD_TOOLS="${SDK}/build-tools/36.0.0"
readonly ANDROID_JAR="${SDK}/platforms/android-37.0/android.jar"
readonly BUILD="${ROOT}/.build/vulkan-probe"
readonly PACKAGE_ROOT="${BUILD}/package"
readonly OUTPUT="${BUILD}/TFTMACVulkanProbe.apk"
readonly SIGNING_ROOT="${BUILD}/v1-signing"

fail() { print -u2 -- "TFTMAC Vulkan probe build failed: $*"; exit 1; }
for file in \
  "${SOURCE}/AndroidManifest.xml" \
  "${SOURCE}/workload-manifest.json" \
  "${SOURCE}/src/main.cpp" \
  "${SOURCE}/shaders/probe.vert" \
  "${SOURCE}/shaders/probe.frag" \
  "${ANDROID_JAR}" \
  "${NDK}/sources/android/native_app_glue/android_native_app_glue.c"; do
  [[ -f "${file}" ]] || fail "required input is missing: ${file}"
done

/bin/rm -rf "${BUILD}"
/bin/mkdir -p "${BUILD}/obj" "${PACKAGE_ROOT}/lib/arm64-v8a" "${PACKAGE_ROOT}/assets"

"${NDK}/shader-tools/darwin-x86_64/glslc" -O "${SOURCE}/shaders/probe.vert" -o "${PACKAGE_ROOT}/assets/probe.vert.spv"
"${NDK}/shader-tools/darwin-x86_64/glslc" -O "${SOURCE}/shaders/probe.frag" -o "${PACKAGE_ROOT}/assets/probe.frag.spv"
/bin/cp "${SOURCE}/workload-manifest.json" "${PACKAGE_ROOT}/assets/workload-manifest.json"

"${TOOLCHAIN}/bin/aarch64-linux-android28-clang" \
  -O2 -fPIC \
  -I"${NDK}/sources/android/native_app_glue" \
  -c "${NDK}/sources/android/native_app_glue/android_native_app_glue.c" \
  -o "${BUILD}/obj/android_native_app_glue.o"

"${TOOLCHAIN}/bin/aarch64-linux-android28-clang++" \
  -std=c++20 -O2 -fPIC -fvisibility=hidden -DVK_USE_PLATFORM_ANDROID_KHR \
  -I"${NDK}/sources/android/native_app_glue" \
  -shared \
  "${SOURCE}/src/main.cpp" \
  "${BUILD}/obj/android_native_app_glue.o" \
  -static-libstdc++ -Wl,--gc-sections -Wl,-soname,libtftmac_vulkan_probe.so \
  -landroid -llog -lvulkan \
  -o "${PACKAGE_ROOT}/lib/arm64-v8a/libtftmac_vulkan_probe.so"
"${TOOLCHAIN}/bin/llvm-strip" "${PACKAGE_ROOT}/lib/arm64-v8a/libtftmac_vulkan_probe.so"

"${BUILD_TOOLS}/aapt" package -f -M "${SOURCE}/AndroidManifest.xml" -I "${ANDROID_JAR}" -F "${BUILD}/unsigned.apk"
(
  cd "${PACKAGE_ROOT}"
  "${BUILD_TOOLS}/aapt" add "${BUILD}/unsigned.apk" \
    lib/arm64-v8a/libtftmac_vulkan_probe.so \
    assets/probe.vert.spv \
    assets/probe.frag.spv \
    assets/workload-manifest.json >/dev/null
)
"${BUILD_TOOLS}/zipalign" -f 4 "${BUILD}/unsigned.apk" "${BUILD}/aligned.apk"

# The host intentionally does not require a Java runtime. Produce a standards-
# compliant JAR/APK v1 signature with the system OpenSSL implementation. This
# key signs only the local, owned probe and is regenerated for every build.
/bin/mkdir -p "${SIGNING_ROOT}/META-INF"
/usr/bin/openssl req -new -x509 -newkey rsa:2048 -nodes -sha256 -days 30 \
  -subj "/CN=TFTMAC Vulkan Probe/O=flashls1/C=US" \
  -keyout "${SIGNING_ROOT}/probe-key.pem" \
  -out "${SIGNING_ROOT}/probe-cert.pem" >/dev/null 2>&1

readonly MANIFEST_MF="${SIGNING_ROOT}/META-INF/MANIFEST.MF"
readonly CERT_SF="${SIGNING_ROOT}/META-INF/CERT.SF"
readonly CERT_RSA="${SIGNING_ROOT}/META-INF/CERT.RSA"
readonly MANIFEST_SECTION="${SIGNING_ROOT}/manifest-section.bin"
/usr/bin/printf 'Manifest-Version: 1.0\r\nCreated-By: TFTMAC Vulkan Probe\r\n\r\n' > "${MANIFEST_MF}"
while IFS= read -r entry; do
  [[ -n "${entry}" && "${entry}" != META-INF/* && "${entry}" != */ ]] || continue
  ENTRY_DIGEST="$(/usr/bin/unzip -p "${BUILD}/aligned.apk" "${entry}" | /usr/bin/openssl dgst -sha256 -binary | /usr/bin/base64)"
  /usr/bin/printf 'Name: %s\r\nSHA-256-Digest: %s\r\n\r\n' "${entry}" "${ENTRY_DIGEST}" > "${MANIFEST_SECTION}"
  /bin/cat "${MANIFEST_SECTION}" >> "${MANIFEST_MF}"
done < <(/usr/bin/unzip -Z1 "${BUILD}/aligned.apk")
readonly MANIFEST_DIGEST="$(/usr/bin/openssl dgst -sha256 -binary "${MANIFEST_MF}" | /usr/bin/base64)"
/usr/bin/printf 'Signature-Version: 1.0\r\nCreated-By: TFTMAC Vulkan Probe\r\nSHA-256-Digest-Manifest: %s\r\n\r\n' \
  "${MANIFEST_DIGEST}" > "${CERT_SF}"
while IFS= read -r entry; do
  [[ -n "${entry}" && "${entry}" != META-INF/* && "${entry}" != */ ]] || continue
  ENTRY_DIGEST="$(/usr/bin/unzip -p "${BUILD}/aligned.apk" "${entry}" | /usr/bin/openssl dgst -sha256 -binary | /usr/bin/base64)"
  /usr/bin/printf 'Name: %s\r\nSHA-256-Digest: %s\r\n\r\n' "${entry}" "${ENTRY_DIGEST}" > "${MANIFEST_SECTION}"
  SECTION_DIGEST="$(/usr/bin/openssl dgst -sha256 -binary "${MANIFEST_SECTION}" | /usr/bin/base64)"
  /usr/bin/printf 'Name: %s\r\nSHA-256-Digest: %s\r\n\r\n' "${entry}" "${SECTION_DIGEST}" >> "${CERT_SF}"
done < <(/usr/bin/unzip -Z1 "${BUILD}/aligned.apk")
/usr/bin/openssl cms -sign -binary -md sha256 -nosmimecap \
  -in "${CERT_SF}" \
  -signer "${SIGNING_ROOT}/probe-cert.pem" \
  -inkey "${SIGNING_ROOT}/probe-key.pem" \
  -outform DER -out "${CERT_RSA}"
/bin/cp "${BUILD}/aligned.apk" "${OUTPUT}"
(
  cd "${SIGNING_ROOT}"
  /usr/bin/zip -q -0 "${OUTPUT}" META-INF/MANIFEST.MF META-INF/CERT.SF META-INF/CERT.RSA
)
/usr/bin/unzip -p "${OUTPUT}" META-INF/CERT.SF > "${BUILD}/verify-cert.sf"
/usr/bin/unzip -p "${OUTPUT}" META-INF/CERT.RSA > "${BUILD}/verify-cert.rsa"
/usr/bin/openssl cms -verify -binary -inform DER -noverify \
  -in "${BUILD}/verify-cert.rsa" \
  -content "${BUILD}/verify-cert.sf" \
  -out /dev/null >/dev/null 2>&1
readonly NODE="$(command -v node)"
[[ -x "${NODE}" ]] || fail "Node.js is required for the local APK v2 signing block"
"${NODE}" "${ROOT}/scripts/sign-apk-v2.mjs" \
  --input "${OUTPUT}" \
  --key "${SIGNING_ROOT}/probe-key.pem" \
  --cert "${SIGNING_ROOT}/probe-cert.pem" \
  --output "${BUILD}/v2-signed.apk"
/bin/mv "${BUILD}/v2-signed.apk" "${OUTPUT}"

readonly APK_SHA="$(/usr/bin/shasum -a 256 "${OUTPUT}" | /usr/bin/awk '{print $1}')"
readonly MANIFEST_SHA="$(/usr/bin/shasum -a 256 "${SOURCE}/workload-manifest.json" | /usr/bin/awk '{print $1}')"
readonly LIB_SHA="$(/usr/bin/shasum -a 256 "${PACKAGE_ROOT}/lib/arm64-v8a/libtftmac_vulkan_probe.so" | /usr/bin/awk '{print $1}')"

/usr/bin/jq -n \
  --arg apk "${OUTPUT}" --arg apk_sha256 "${APK_SHA}" \
  --arg workload_manifest "${SOURCE}/workload-manifest.json" --arg workload_manifest_sha256 "${MANIFEST_SHA}" \
  --arg native_library_sha256 "${LIB_SHA}" \
  '{schema:1,state:"TFTMAC_VULKAN_PROBE_BUILD_PASS",package:"com.flashls1.tftmac.vulkanprobe",abi:"arm64-v8a",min_sdk:28,target_sdk:36,apk:$apk,apk_sha256:$apk_sha256,workload_manifest:$workload_manifest,workload_manifest_sha256:$workload_manifest_sha256,native_library_sha256:$native_library_sha256,signing:"APK_V1_AND_V2_SHA256_RSA_LOCAL_EPHEMERAL",network_access:false,riot_interaction:false}' \
  > "${BUILD}/build-receipt.json"

print -- "${OUTPUT}"
print -- "TFTMAC Vulkan probe build receipt: ${BUILD}/build-receipt.json"
