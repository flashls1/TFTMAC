#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly ROOT="${0:A:h:h}"
readonly DEV_APP="/Applications/TFTMAC DEV.app"
readonly CONTROL_APP="/Applications/TFTMAC.app"
readonly CAPTURE_ROOT="${HOME}/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures"
readonly EXPERIMENT_ROOT="${HOME}/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Experiments"
readonly RUNNER_LOCK="${HOME}/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/State/vulkan-campaign-runner.lock"
readonly CONTROL_EXECUTABLE="${CONTROL_APP}/Contents/MacOS/TFTMAC"
readonly CONTROL_EMULATOR="/Volumes/MAC MINI M4/TFTMAC/Runtime/SDK/emulator/emulator"
readonly CONTROL_AVD="/Volumes/MAC MINI M4/TFTMAC/Runtime/AVD/TFT_Ultra_Tablet.avd"
readonly KEYCHAIN_SERVICE="com.flashls1.tftmac.android-unlock.v2"
readonly KEYCHAIN_ACCOUNT="android-user-0"
readonly RUN_TIMEOUT_SECONDS=900

fail() { print -u2 -- "TFTMAC Vulkan campaign failed: $*"; exit 1; }
[[ -d "${DEV_APP}" ]] || fail "${DEV_APP} is not installed"
[[ -x "${CONTROL_EXECUTABLE}" && -x "${CONTROL_EMULATOR}" ]] || fail "Control authority is unavailable"
[[ -f "${DEV_APP}/Contents/Resources/TFTMACVulkanProbe.apk" ]] || fail "installed DEV app has no owned Vulkan probe"
[[ -f "${DEV_APP}/Contents/Resources/workload-manifest.json" ]] || fail "installed DEV app has no workload manifest"
/usr/bin/security find-generic-password \
  -s "${KEYCHAIN_SERVICE}" \
  -a "${KEYCHAIN_ACCOUNT}" \
  "${HOME}/Library/Keychains/login.keychain-db" >/dev/null 2>&1 \
  || fail "secure unlock is not initialized; run scripts/setup-android-unlock.command once"

if /usr/bin/pgrep -f '/Applications/TFTMAC.app/Contents/MacOS/TFTMAC|@TFTMAC[^ ]*.*-port 5582' >/dev/null; then
  fail "Control is running; it will not be disturbed"
fi
if /usr/bin/pgrep -f '/Applications/TFTMAC DEV.app/Contents/MacOS|@TFTMAC_Diagnostic_StockShadow_R1' >/dev/null; then
  fail "TFTMAC DEV or its diagnostic emulator is already running"
fi

/bin/mkdir -p "${RUNNER_LOCK:h}" "${EXPERIMENT_ROOT}"
/bin/mkdir "${RUNNER_LOCK}" 2>/dev/null || fail "another DEV campaign owns the runner lease"
cleanup() { /bin/rmdir "${RUNNER_LOCK}" 2>/dev/null || true }
trap cleanup EXIT INT TERM

tree_hash() {
  local target="$1"
  /usr/bin/find "${target}" -type f -print0 \
    | /usr/bin/sort -z \
    | /usr/bin/xargs -0 /usr/bin/shasum -a 256 \
    | /usr/bin/shasum -a 256 \
    | /usr/bin/awk '{print $1}'
}

readonly CAMPAIGN_ID="$(/bin/date -u +%Y-%m-%dT%H-%M-%SZ)-$(/usr/bin/uuidgen | /usr/bin/tr '[:upper:]' '[:lower:]')"
readonly CAMPAIGN="${EXPERIMENT_ROOT}/${CAMPAIGN_ID}"
/bin/mkdir -m 700 "${CAMPAIGN}" "${CAMPAIGN}/runs" "${CAMPAIGN}/profiles"
readonly CONTROL_EXECUTABLE_BEFORE="$(/usr/bin/shasum -a 256 "${CONTROL_EXECUTABLE}" | /usr/bin/awk '{print $1}')"
readonly CONTROL_EMULATOR_BEFORE="$(/usr/bin/shasum -a 256 "${CONTROL_EMULATOR}" | /usr/bin/awk '{print $1}')"
readonly CONTROL_AVD_BEFORE="$(tree_hash "${CONTROL_AVD}")"
readonly WORKLOAD_MANIFEST_SHA="$(/usr/bin/shasum -a 256 "${DEV_APP}/Contents/Resources/workload-manifest.json" | /usr/bin/awk '{print $1}')"

profiles=(control queue_submit_inline control virtual_queue_off control fence_contexts_off control)
for index in {1..7}; do
  profile="${profiles[$index]}"
  print -- "TFTMAC Vulkan campaign ${index}/7: ${profile}"
  /usr/bin/open -n -W \
    --env "TFTMAC_DEV_WORKLOAD=owned_vulkan_probe" \
    --env "TFTMAC_DEV_EXPERIMENT_PROFILE=${profile}" \
    "${DEV_APP}" &
  open_pid=$!
  deadline=$(( EPOCHSECONDS + RUN_TIMEOUT_SECONDS ))
  while /bin/kill -0 "${open_pid}" 2>/dev/null; do
    if (( EPOCHSECONDS >= deadline )); then
      dev_pid="$(/usr/bin/pgrep -f '^/Applications/TFTMAC DEV\.app/Contents/MacOS/TFTMACDEVCore$' || true)"
      [[ -z "${dev_pid}" ]] || /bin/kill -TERM "${dev_pid}"
      /bin/kill -TERM "${open_pid}" 2>/dev/null || true
      wait "${open_pid}" 2>/dev/null || true
      fail "run ${index} exceeded the ${RUN_TIMEOUT_SECONDS}-second bounded runtime"
    fi
    /bin/sleep 1
  done
  wait "${open_pid}"
  capture="$(/bin/ls -1dt "${CAPTURE_ROOT}"/* 2>/dev/null | /usr/bin/head -n 1)"
  [[ -n "${capture}" && -f "${capture}/TFTMAC_NATIVE_RUNTIME.sqlite" ]] \
    || fail "run ${index} did not produce a capture database"
  database="${capture}/TFTMAC_NATIVE_RUNTIME.sqlite"
  session_id="$(/usr/bin/sqlite3 "${database}" "SELECT session_id FROM sessions LIMIT 1")"
  observed_profile="$(/usr/bin/sqlite3 "${database}" "SELECT experiment_profile_id FROM pipeline_experiment_runs LIMIT 1")"
  observed_state="$(/usr/bin/sqlite3 "${database}" "SELECT state FROM pipeline_experiment_runs LIMIT 1")"
  [[ "${observed_profile}" == "${profile}" ]] || fail "run ${index} profile receipt drifted"
  [[ "${observed_state}" == "PASS" ]] || fail "run ${index} did not pass"
  configuration_sha="$(/usr/bin/sqlite3 "${database}" "SELECT configuration_sha256 FROM pipeline_experiment_runs LIMIT 1")"
  database_sha="$(/usr/bin/shasum -a 256 "${database}" | /usr/bin/awk '{print $1}')"
  window_count="$(/usr/bin/sqlite3 "${database}" "SELECT COUNT(*) FROM events WHERE kind='OWNED_VULKAN_PROBE_WINDOW'")"
  [[ "${window_count}" -ge 295 ]] || fail "run ${index} has only ${window_count} probe windows"
  /usr/bin/jq -n \
    --argjson sequence "${index}" \
    --arg profile "${profile}" \
    --arg session_id "${session_id}" \
    --arg capture_path "${capture}" \
    --arg database "${database}" \
    --arg database_sha256 "${database_sha}" \
    --arg configuration_sha256 "${configuration_sha}" \
    --arg workload_manifest_sha256 "${WORKLOAD_MANIFEST_SHA}" \
    --argjson window_count "${window_count}" \
    '{schema:1,sequence:$sequence,profile:$profile,session_id:$session_id,capture_path:$capture_path,database:$database,database_sha256:$database_sha256,configuration_sha256:$configuration_sha256,workload_manifest_sha256:$workload_manifest_sha256,probe_window_count:$window_count,state:"PASS",privacy:"LOCAL_SENSITIVE_NOT_FOR_GIT"}' \
    > "${CAMPAIGN}/runs/$(/usr/bin/printf '%02d' "${index}")-${profile}.json"
  /usr/bin/jq -n \
    --arg id "${profile}" --arg base_runtime_variant stock_shadow \
    --arg effective_configuration_sha256 "${configuration_sha}" \
    --arg workload_manifest_sha256 "${WORKLOAD_MANIFEST_SHA}" \
    --argjson duration_seconds 330 --argjson warmup_seconds 30 \
    '{schema:1,contract:"DevExperimentProfile",id:$id,base_runtime_variant:$base_runtime_variant,effective_configuration_sha256:$effective_configuration_sha256,workload_manifest_sha256:$workload_manifest_sha256,duration_seconds:$duration_seconds,warmup_seconds:$warmup_seconds,correctness_requirements:["image","input","audio","crash","leak","cleanup","event_loss"]}' \
    > "${CAMPAIGN}/profiles/$(/usr/bin/printf '%02d' "${index}")-${profile}.json"
done

readonly CONTROL_EXECUTABLE_AFTER="$(/usr/bin/shasum -a 256 "${CONTROL_EXECUTABLE}" | /usr/bin/awk '{print $1}')"
readonly CONTROL_EMULATOR_AFTER="$(/usr/bin/shasum -a 256 "${CONTROL_EMULATOR}" | /usr/bin/awk '{print $1}')"
readonly CONTROL_AVD_AFTER="$(tree_hash "${CONTROL_AVD}")"
[[ "${CONTROL_EXECUTABLE_AFTER}" == "${CONTROL_EXECUTABLE_BEFORE}" ]] || fail "Control executable changed"
[[ "${CONTROL_EMULATOR_AFTER}" == "${CONTROL_EMULATOR_BEFORE}" ]] || fail "Control emulator changed"
[[ "${CONTROL_AVD_AFTER}" == "${CONTROL_AVD_BEFORE}" ]] || fail "Control AVD changed"

readonly NODE="$(command -v node)"
"${NODE}" "${ROOT}/scripts/analyze-vulkan-experiment-campaign.mjs" "${CAMPAIGN}"
/usr/bin/jq -n \
  --arg state TFTMAC_VULKAN_CAMPAIGN_PASS \
  --arg campaign_id "${CAMPAIGN_ID}" \
  --arg control_executable_before "${CONTROL_EXECUTABLE_BEFORE}" \
  --arg control_executable_after "${CONTROL_EXECUTABLE_AFTER}" \
  --arg control_emulator_before "${CONTROL_EMULATOR_BEFORE}" \
  --arg control_emulator_after "${CONTROL_EMULATOR_AFTER}" \
  --arg control_avd_before "${CONTROL_AVD_BEFORE}" \
  --arg control_avd_after "${CONTROL_AVD_AFTER}" \
  '{schema:1,state:$state,campaign_id:$campaign_id,control_unchanged:($control_executable_before==$control_executable_after and $control_emulator_before==$control_emulator_after and $control_avd_before==$control_avd_after),control_executable_sha256:$control_executable_after,control_emulator_sha256:$control_emulator_after,control_avd_tree_sha256:$control_avd_after}' \
  > "${CAMPAIGN}/control-integrity-receipt.json"
print -- "${CAMPAIGN}"
