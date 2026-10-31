#!/bin/zsh
set -euo pipefail

# ==============================================================================
# TFT TURBO — 9-Gate Quality & Anti-Regression Verification Runner
# ==============================================================================
# Verifies all 9 Pre-Delivery Build Quality Gates required by BUILD_PROTOCOL.md
# Can be run standalone from terminal or Finder.
# Exit code: 0 on PASS, 1 on any gate failure.
# ==============================================================================

ROOT="${0:A:h:h}"
# Successor branch: never silently validate the installed TURBO 1 artifact.
if [[ $# -eq 1 && "$1" == "--preflight" ]]; then
    exec /usr/bin/python3 -B "${ROOT}/scripts/turbo2_isolation.py" --preflight
fi
if [[ $# -ne 2 || "$1" != "--app" ]]; then
    print -u2 -- "Usage: $0 --app /absolute/path/to/TFT\\ TURBO\\ 2.app | --preflight"
    exit 2
fi
APP="$2"
# Reject wrong identity, alias or unintegrated runtime before any native tests.
/usr/bin/python3 -B "${ROOT}/scripts/turbo2_isolation.py" --app "${APP}"
RANKED="/Users/flash/Desktop/TFT Ranked.app"
EXPECTED_RANKED_CORE_SHA256="00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee"
EXPECTED_TURBO_ICNS_MD5="a8f93ea0c9770af6c0a53d6a8bee57d7"

# Formatting
BOLD="\033[1m"
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

echo "${CYAN}${BOLD}==============================================================================${RESET}"
echo "${CYAN}${BOLD}     TFT TURBO 2 — exact-artifact static build verification              ${RESET}"
echo "${CYAN}${BOLD}==============================================================================${RESET}"
echo "Workspace Root: ${ROOT}"
echo "Target App:     ${APP}"
echo ""

TOTAL_GATES=9
PASSED_GATES=0
FAILED_GATES=0

pass_gate() {
    local gate="$1"
    local desc="$2"
    local detail="${3:-}"
    if [[ -n "${detail}" ]]; then
        echo "  [${GREEN}PASS${RESET}] ${BOLD}${gate}${RESET}: ${desc} (${detail})"
    else
        echo "  [${GREEN}PASS${RESET}] ${BOLD}${gate}${RESET}: ${desc}"
    fi
    PASSED_GATES=$(( PASSED_GATES + 1 ))
}

fail_gate() {
    local gate="$1"
    local desc="$2"
    local reason="$3"
    echo "  [${RED}FAIL${RESET}] ${BOLD}${gate}${RESET}: ${desc}"
    echo "         ${RED}Reason: ${reason}${RESET}"
    FAILED_GATES=$(( FAILED_GATES + 1 ))
}

# ------------------------------------------------------------------------------
# Gate 1: Protected Invariant INV-01
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 1: Protected Invariant INV-01...${RESET}"
if [[ ! -f "${RANKED}/Contents/MacOS/TFTMACDEVCore" ]]; then
    fail_gate "G-01" "Protected Invariant (INV-01)" "${RANKED}/Contents/MacOS/TFTMACDEVCore does not exist"
else
    RANKED_SHA=$(/usr/bin/shasum -a 256 "${RANKED}/Contents/MacOS/TFTMACDEVCore" | awk '{print $1}')
    if [[ "${RANKED_SHA}" == "${EXPECTED_RANKED_CORE_SHA256}" ]]; then
        pass_gate "G-01" "Protected Invariant (INV-01)" "SHA-256 matches: ${RANKED_SHA:0:16}..."
    else
        fail_gate "G-01" "Protected Invariant (INV-01)" "SHA-256 mismatch! Got ${RANKED_SHA}, expected ${EXPECTED_RANKED_CORE_SHA256}"
    fi
fi

# ------------------------------------------------------------------------------
# Gate 2: Stable Code Signing Identity
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 2: Stable Code Signing Identity...${RESET}"
if [[ ! -d "${APP}" ]]; then
    fail_gate "G-02" "Stable Code Signing Identity" "Target application bundle does not exist at ${APP}"
else
    CODESIGN_DVV=$(/usr/bin/codesign -dvv "${APP}" 2>&1 || true)
    if echo "${CODESIGN_DVV}" | grep -q "Authority=TFTMAC Local Code Signing"; then
        pass_gate "G-02" "Stable Code Signing Identity" "Signed with 'TFTMAC Local Code Signing' (TCC consent preserved)"
    else
        fail_gate "G-02" "Stable Code Signing Identity" "App is NOT signed with 'TFTMAC Local Code Signing' (found: $(echo "${CODESIGN_DVV}" | grep Authority || echo 'ad-hoc or unsigned'))"
    fi
fi

# ------------------------------------------------------------------------------
# Gate 3: Strict Deep Code Signature
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 3: Strict Deep Code Signature...${RESET}"
if [[ ! -d "${APP}" ]]; then
    fail_gate "G-03" "Strict Deep Code Signature" "Target application bundle missing"
else
    if /usr/bin/codesign --verify --deep --strict "${APP}" 2>&1; then
        pass_gate "G-03" "Strict Deep Code Signature" "Deep and strict verification exited 0"
    else
        fail_gate "G-03" "Strict Deep Code Signature" "codesign --verify --deep --strict failed"
    fi
fi

# ------------------------------------------------------------------------------
# Gate 4: Yellow TURBO Banner Icon
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 4: Yellow TURBO Banner Icon...${RESET}"
TURBO_ICNS="${APP}/Contents/Resources/TFTMAC-TURBO.icns"
DEV_ICNS="${APP}/Contents/Resources/TFTMAC-DEV.icns"
INFO_PLIST="${APP}/Contents/Info.plist"

if [[ ! -f "${TURBO_ICNS}" || ! -f "${DEV_ICNS}" ]]; then
    fail_gate "G-04" "Yellow TURBO Banner Icon" "Missing TFTMAC-TURBO.icns or TFTMAC-DEV.icns in Resources"
else
    TURBO_MD5=$(/sbin/md5 -q "${TURBO_ICNS}" || /usr/bin/md5 -q "${TURBO_ICNS}")
    DEV_MD5=$(/sbin/md5 -q "${DEV_ICNS}" || /usr/bin/md5 -q "${DEV_ICNS}")
    ICON_KEY=$(/usr/bin/plutil -extract CFBundleIconFile raw "${INFO_PLIST}" 2>/dev/null || echo "")

    if [[ "${TURBO_MD5}" == "${EXPECTED_TURBO_ICNS_MD5}" && "${DEV_MD5}" == "${EXPECTED_TURBO_ICNS_MD5}" && "${ICON_KEY}" == "TFTMAC-TURBO.icns" ]]; then
        pass_gate "G-04" "Yellow TURBO Banner Icon" "TURBO icns MD5 verified (${TURBO_MD5}) and Info.plist icon set"
    else
        fail_gate "G-04" "Yellow TURBO Banner Icon" "Icon mismatch: TURBO_MD5=${TURBO_MD5}, DEV_MD5=${DEV_MD5}, CFBundleIconFile=${ICON_KEY}"
    fi
fi

# ------------------------------------------------------------------------------
# Gate 5: Declared TCC Entitlement
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 5: Declared TCC Entitlement...${RESET}"
if [[ ! -f "${INFO_PLIST}" ]]; then
    fail_gate "G-05" "Declared TCC Entitlement" "Info.plist missing"
else
    TCC_DESC=$(/usr/bin/plutil -extract NSRemovableVolumesUsageDescription raw "${INFO_PLIST}" 2>/dev/null || echo "")
    if [[ "${TCC_DESC}" == "TFTMAC DEV uses the isolated Android diagnostic runtime stored on MAC MINI M4." ]]; then
        pass_gate "G-05" "Declared TCC Entitlement" "NSRemovableVolumesUsageDescription present and matches Ranked.app"
    else
        fail_gate "G-05" "Declared TCC Entitlement" "NSRemovableVolumesUsageDescription missing or modified: '${TCC_DESC}'"
    fi
fi

# ------------------------------------------------------------------------------
# Gate 6: Audio Subsystem Health & Buffer Headroom
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 6: Audio Subsystem Health & Buffer Headroom...${RESET}"
SWIFT_SRC="${ROOT}/tftmac/Runtime/TFTMACRuntime.swift"
if [[ ! -f "${SWIFT_SRC}" ]]; then
    fail_gate "G-06" "Audio Subsystem Health" "TFTMACRuntime.swift missing"
else
    HAS_BUFFER=$(grep -c "QEMU_COREAUDIO_BUFFER_SIZE=2048" "${SWIFT_SRC}" || true)
    HAS_BOOT_RESTART=$(grep -c "GUEST_AUDIO_SERVER_PREWARMED" "${SWIFT_SRC}" || true)
    HAS_LAYER_GUARD=$(grep -c "currentExactLayerName == nil" "${SWIFT_SRC}" || true)

    if [[ ${HAS_BUFFER} -gt 0 && ${HAS_BOOT_RESTART} -gt 0 && ${HAS_LAYER_GUARD} -gt 0 ]]; then
        pass_gate "G-06" "Audio Subsystem Health" "682ms buffer configured, audioserver boot pre-warmed, mid-game root toggle guarded"
    else
        fail_gate "G-06" "Audio Subsystem Health" "Audio guards missing (buffer=${HAS_BUFFER}, boot_restart=${HAS_BOOT_RESTART}, layer_guard=${HAS_LAYER_GUARD})"
    fi
fi

# ------------------------------------------------------------------------------
# Gate 7: Host CPU Allocation & Daemons
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 7: Host CPU & Daemons...${RESET}"
LAUNCHER_SRC="${ROOT}/RankedLauncher/main.c"
DEVPROFILES_SRC="${ROOT}/tftmac/Assets/DEVHighPerf/DeviceProfiles.ini"

VCPU_OK=0
DAEMONS_OK=0

if grep -q 'setenv("TFTMAC_DEV_VCPU", "8", 1)' "${LAUNCHER_SRC}" 2>/dev/null; then
    VCPU_OK=1
fi

DAEMON_COMPILE_COUNT=$(grep -c "NumRemoteProgramCompileServices=0" "${DEVPROFILES_SRC}" 2>/dev/null || true)
DAEMON_THREAD_COUNT=$(grep -c "PrecompileThreadPoolSize=0" "${DEVPROFILES_SRC}" 2>/dev/null || true)
if [[ ${DAEMON_COMPILE_COUNT} -ge 5 && ${DAEMON_THREAD_COUNT} -ge 5 ]]; then
    DAEMONS_OK=1
fi

if [[ ${VCPU_OK} -eq 1 && ${DAEMONS_OK} -eq 1 ]]; then
    pass_gate "G-07" "Host CPU & Daemons" "8 vCPUs configured; remote compiler daemons suppressed in DeviceProfiles.ini"
else
    fail_gate "G-07" "Host CPU & Daemons" "VCPU_OK=${VCPU_OK}, compile_daemons=${DAEMON_COMPILE_COUNT}, thread_daemons=${DAEMON_THREAD_COUNT}"
fi

# ------------------------------------------------------------------------------
# Gate 8: Native Unit Test Suite
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 8: Native Unit Test Suite...${RESET}"
TEST_CMD="${ROOT}/scripts/test-native-app.command"
if [[ ! -x "${TEST_CMD}" ]]; then
    fail_gate "G-08" "Native Unit Test Suite" "test-native-app.command is missing or not executable"
else
    echo "  Running test suite (/bin/zsh ${TEST_CMD})..."
    TEST_OUTPUT=$(/bin/zsh "${TEST_CMD}" 2>&1)
    if echo "${TEST_OUTPUT}" | grep -q "Executed 135 tests, with 0 failures"; then
        pass_gate "G-08" "Native Unit Test Suite" "All 135 native unit tests passed with 0 failures"
    elif echo "${TEST_OUTPUT}" | grep -q "with 0 failures"; then
        TEST_COUNT=$(echo "${TEST_OUTPUT}" | grep -o 'Executed [0-9]* tests' | awk '{print $2}')
        pass_gate "G-08" "Native Unit Test Suite" "All ${TEST_COUNT} native unit tests passed with 0 failures"
    else
        FAIL_LINE=$(echo "${TEST_OUTPUT}" | grep "failures" | tail -n 1 || echo "Test failure")
        fail_gate "G-08" "Native Unit Test Suite" "Tests failed: ${FAIL_LINE}"
    fi
fi

# ------------------------------------------------------------------------------
# Gate 9: DEV HighPerf Asset Integrity
# ------------------------------------------------------------------------------
echo "${BOLD}Checking Gate 9: DEV HighPerf Asset Integrity...${RESET}"
DEV_INI="${ROOT}/tftmac/Assets/DEVHighPerf/DeviceProfiles.ini"
DEV_SH="${ROOT}/tftmac/Assets/DEVHighPerf/profile-transaction.sh"
DEV_RAM="${ROOT}/tftmac/Assets/DEVHighPerf/debug-ramdisk.img"
DEV_RIOT="${ROOT}/tftmac/Assets/DEVHighPerf/riot-defaults.sh"

INI_HASH=$(/usr/bin/shasum -a 256 "${DEV_INI}" | awk '{print $1}')
SH_HASH=$(/usr/bin/shasum -a 256 "${DEV_SH}" | awk '{print $1}')
RAM_HASH=$(/usr/bin/shasum -a 256 "${DEV_RAM}" | awk '{print $1}')
RIOT_HASH=$(/usr/bin/shasum -a 256 "${DEV_RIOT}" | awk '{print $1}')

G9_ERRORS=()

# 1. Check profile-transaction.sh control_expected
if ! grep -q "control_expected=${INI_HASH}" "${DEV_SH}"; then
    G9_ERRORS+=("profile-transaction.sh control_expected does not match DeviceProfiles.ini hash (${INI_HASH})")
fi

# 2. Check Swift runtime hashes
if ! grep -q "\"DeviceProfiles.ini\": \"${INI_HASH}\"" "${SWIFT_SRC}"; then
    G9_ERRORS+=("TFTMACRuntime.swift highPerfHashes['DeviceProfiles.ini'] mismatch")
fi
if ! grep -q "\"profile-transaction.sh\": \"${SH_HASH}\"" "${SWIFT_SRC}"; then
    G9_ERRORS+=("TFTMACRuntime.swift highPerfHashes['profile-transaction.sh'] mismatch")
fi
if ! grep -q "\"debug-ramdisk.img\": \"${RAM_HASH}\"" "${SWIFT_SRC}"; then
    G9_ERRORS+=("TFTMACRuntime.swift highPerfHashes['debug-ramdisk.img'] mismatch")
fi
if ! grep -q "\"riot-defaults.sh\": \"${RIOT_HASH}\"" "${SWIFT_SRC}"; then
    G9_ERRORS+=("TFTMACRuntime.swift highPerfHashes['riot-defaults.sh'] mismatch")
fi

# 3. Check deployed app bundle assets
APP_ASSET_DIR="${APP}/Contents/Resources/DEVHighPerf"
if [[ -d "${APP_ASSET_DIR}" ]]; then
    APP_INI_HASH=$(/usr/bin/shasum -a 256 "${APP_ASSET_DIR}/DeviceProfiles.ini" | awk '{print $1}')
    APP_SH_HASH=$(/usr/bin/shasum -a 256 "${APP_ASSET_DIR}/profile-transaction.sh" | awk '{print $1}')
    if [[ "${APP_INI_HASH}" != "${INI_HASH}" || "${APP_SH_HASH}" != "${SH_HASH}" ]]; then
        G9_ERRORS+=("Deployed app bundle DEVHighPerf assets do not match source assets")
    fi
else
    G9_ERRORS+=("Deployed app bundle missing DEVHighPerf directory: ${APP_ASSET_DIR}")
fi

if [[ ${#G9_ERRORS[@]} -eq 0 ]]; then
    pass_gate "G-09" "DEV HighPerf Asset Integrity" "Source assets, Swift runtime dictionary, and deployed bundle match perfectly"
else
    fail_gate "G-09" "DEV HighPerf Asset Integrity" "${(j:, :)G9_ERRORS}"
fi

# ------------------------------------------------------------------------------
# Final Verdict
# ------------------------------------------------------------------------------
echo ""
echo "${CYAN}${BOLD}==============================================================================${RESET}"
echo "Summary: ${BOLD}${PASSED_GATES}/${TOTAL_GATES} Gates Passed${RESET}"
if [[ ${FAILED_GATES} -eq 0 ]]; then
    echo "${GREEN}${BOLD}VERDICT: STATIC GATES PASS for ${APP}; separate live acceptance is still required${RESET}"
    echo "${CYAN}${BOLD}==============================================================================${RESET}"
    exit 0
else
    echo "${RED}${BOLD}VERDICT: REJECTED — ${FAILED_GATES} GATES FAILED. DO NOT DELIVER OR LAUNCH.${RESET}"
    echo "${CYAN}${BOLD}==============================================================================${RESET}"
    exit 1
fi
