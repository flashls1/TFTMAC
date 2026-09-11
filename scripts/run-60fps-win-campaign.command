#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE
zmodload zsh/datetime

# This runner is intentionally small: it exercises one frozen DEV candidate,
# records the nearest real-game evidence, and rejects it before advancing when
# any delivered frame window is below 60 FPS. It does not alter Control.
readonly ROOT="${0:A:h:h}"
readonly DEV_APP="${ROOT}/dist/TFTMAC DEV.app"
readonly CAPTURE_ROOT="${HOME}/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures"
readonly CAMPAIGN_ROOT="${HOME}/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Campaigns/60fps-win"
readonly ADB="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK/platform-tools/adb"
readonly SERIAL="emulator-5586"
readonly ADB_PORT=5041
readonly CLASSIFIER="${ROOT}/runtime/tft-screen-classifier"
readonly PYTHON="/opt/homebrew/bin/python3"
readonly MAX_CANDIDATES="${TFT_60FPS_MAX_CANDIDATES:-8}"
readonly COMBAT_HOLD_SECONDS="${TFT_60FPS_COMBAT_HOLD_SECONDS:-35}"
readonly NAVIGATION_TIMEOUT="${TFT_60FPS_NAVIGATION_TIMEOUT:-240}"
readonly LOCK_DIR="${CAMPAIGN_ROOT}/.runner-lock"
readonly MIN_INTERNAL_FREE_BYTES=$((8 * 1024 * 1024 * 1024))
readonly MIN_EXTERNAL_FREE_BYTES=$((20 * 1024 * 1024 * 1024))

typeset CAMPAIGN_DIR="${TFT_60FPS_CAMPAIGN_DIR:-}"
typeset OPEN_PID=""
typeset ACTIVE_RUN=""
typeset ACTIVE_CAPTURE=""
typeset CLEANING_UP=0

fail() { print -u2 -- "TFTMAC 60 FPS campaign: $*"; exit 1; }
[[ -d "${DEV_APP}" && -x "${DEV_APP}/Contents/MacOS/TFTMACDEVCore" ]] || fail "current DEV app is unavailable"
[[ -x "${ADB}" && -x "${CLASSIFIER}" && -x "${PYTHON}" ]] || fail "required local runtime tools are unavailable"
[[ -x "$(command -v jq 2>/dev/null || true)" ]] || fail "jq is unavailable"

free_bytes() {
  local path="$1"
  /bin/df -Pk "${path}" | /usr/bin/awk 'NR==2 {print $4 * 1024}'
}

ensure_storage_budget() {
  local internal_free external_free
  internal_free="$(free_bytes /)"
  external_free="$(free_bytes "/Volumes/MAC MINI M4")"
  [[ "${internal_free}" == <-> && "${external_free}" == <-> ]] \
    || fail "storage budget could not be measured"
  (( internal_free >= MIN_INTERNAL_FREE_BYTES )) \
    || fail "internal free space ${internal_free} bytes is below the required 8 GiB"
  (( external_free >= MIN_EXTERNAL_FREE_BYTES )) \
    || fail "external free space ${external_free} bytes is below the required 20 GiB"
}

ensure_storage_budget

/bin/mkdir -p "${CAMPAIGN_ROOT}"
if [[ -n "${CAMPAIGN_DIR}" ]]; then
  [[ "${CAMPAIGN_DIR:A:h}" == "${CAMPAIGN_ROOT:A}" && -d "${CAMPAIGN_DIR}/runs" ]] \
    || fail "resume campaign is outside the private 60 FPS campaign root"
else
  CAMPAIGN_DIR="${CAMPAIGN_ROOT}/$(/bin/date -u +%Y-%m-%dT%H-%M-%SZ)-$(/usr/bin/uuidgen | tr '[:upper:]' '[:lower:]')"
  /bin/mkdir -m 700 "${CAMPAIGN_DIR}" "${CAMPAIGN_DIR}/runs"
fi
readonly CAMPAIGN="${CAMPAIGN_DIR:A}"
/bin/mkdir "${LOCK_DIR}" 2>/dev/null || fail "another 60 FPS campaign already owns the runner"

latest_capture() {
  /usr/bin/find "${CAPTURE_ROOT}" -mindepth 1 -maxdepth 1 -type d -name '20*-*' -print 2>/dev/null | /usr/bin/sort | /usr/bin/tail -n 1
}

stop_dev() {
  local pid
  for pid in $(/usr/bin/pgrep -f '^/Applications/TFTMAC DEV[.]app/Contents/MacOS/TFTMACDEVLauncher$' 2>/dev/null || true) \
              $(/usr/bin/pgrep -f "^${ROOT}/dist/TFTMAC DEV[.]app/Contents/MacOS/TFTMACDEVLauncher$" 2>/dev/null || true); do
    /bin/kill -TERM "${pid}" 2>/dev/null || true
  done
  for pid in $(/usr/bin/pgrep -f '^/Applications/TFTMAC DEV[.]app/Contents/MacOS/TFTMACDEVCore$' 2>/dev/null || true) \
              $(/usr/bin/pgrep -f "^${ROOT}/dist/TFTMAC DEV[.]app/Contents/MacOS/TFTMACDEVCore$" 2>/dev/null || true); do
    /bin/kill -TERM "${pid}" 2>/dev/null || true
  done
}

stop_owned_emulator() {
  local pid
  for pid in $(/usr/bin/pgrep -f '@TFTMAC_Diagnostic_StockShadow_R1' 2>/dev/null || true); do
    /bin/kill -TERM "${pid}" 2>/dev/null || true
  done
  /bin/sleep 1
  for pid in $(/usr/bin/pgrep -f '@TFTMAC_Diagnostic_StockShadow_R1' 2>/dev/null || true); do
    /bin/kill -KILL "${pid}" 2>/dev/null || true
  done
}

stop_adb() {
  "${ADB}" -P "${ADB_PORT}" kill-server >/dev/null 2>&1 || true
}

cleanup() {
  local exit_status=$?
  [[ "${CLEANING_UP}" == 1 ]] && return
  CLEANING_UP=1
  trap - EXIT INT TERM HUP
  set +e
  stop_dev
  stop_owned_emulator
  stop_adb
  if [[ -n "${OPEN_PID}" ]] && /bin/kill -0 "${OPEN_PID}" 2>/dev/null; then
    /bin/kill -TERM "${OPEN_PID}" 2>/dev/null || true
  fi
  /bin/sleep 2
  "${ADB}" -P "${ADB_PORT}" kill-server >/dev/null 2>&1 || true
  /bin/rmdir "${LOCK_DIR}" 2>/dev/null || true
  exit "${exit_status}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

# Close only stale DEV copies. Control is an explicit hard boundary.
if /usr/bin/pgrep -f '/Applications/TFTMAC[.]app/Contents/MacOS/TFTMAC$' >/dev/null 2>&1; then
  fail "Control is running; it will not be disturbed"
fi
stop_dev
stop_owned_emulator
stop_adb
/bin/sleep 2

write_receipt() {
  local index="$1" id="$2" run_dir="$3" capture="$4" outcome="$5" reason="$6" db="${capture}/TFTMAC_NATIVE_RUNTIME.sqlite"
  local manifest="${run_dir}/manifest.json" metrics="${run_dir}/metrics.json" boot="${run_dir}/boot.json"
  local sha="" session_status="" event_count=0
  [[ -f "${manifest}" ]] || /usr/bin/jq -n '{}' > "${manifest}"
  [[ -f "${boot}" ]] || /usr/bin/jq -n '{state:"unknown",red_error:true}' > "${boot}"
  [[ -f "${metrics}" ]] || /usr/bin/jq -n '{window_count:0,mechanism_events:0,ready_events:0,red_failure_events:1}' > "${metrics}"
  [[ -f "${db}" ]] && sha="$(/usr/bin/shasum -a 256 "${db}" | /usr/bin/awk '{print $1}')"
  [[ -f "${db}" ]] && session_status="$(/usr/bin/sqlite3 "${db}" "SELECT status FROM sessions LIMIT 1" 2>/dev/null || true)"
  [[ -f "${db}" ]] && event_count="$(/usr/bin/sqlite3 "${db}" "SELECT COUNT(*) FROM events" 2>/dev/null || print 0)"
  /usr/bin/jq -n \
    --argjson sequence "${index}" --arg candidate "${id}" --arg outcome "${outcome}" \
    --arg reason "${reason}" --arg run_dir "${run_dir}" --arg capture "${capture}" \
    --arg database_sha256 "${sha}" --arg session_status "${session_status}" \
    --argjson event_count "${event_count:-0}" \
    --slurpfile manifest "${manifest}" --slurpfile boot "${boot}" --slurpfile metrics "${metrics}" \
    '{schema:1,sequence:$sequence,candidate:$candidate,outcome:$outcome,reason:(if $reason=="" then null else $reason end),run_dir:$run_dir,capture:$capture,database_sha256:(if $database_sha256=="" then null else $database_sha256 end),session_status:(if $session_status=="" then null else $session_status end),event_count:$event_count,manifest:($manifest[0]//null),boot:($boot[0]//null),metrics:($metrics[0]//null),privacy:"LOCAL_SENSITIVE_NOT_FOR_GIT"}' \
    > "${run_dir}/receipt.json"
  /usr/bin/jq -c . "${run_dir}/receipt.json" >> "${CAMPAIGN}/ledger.jsonl"
  /bin/chmod 600 "${run_dir}/receipt.json" "${CAMPAIGN}/ledger.jsonl"
}

capture_state() {
  local image="$1" json="$2" upscaled="$3"
  "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" exec-out screencap -p > "${image}" 2>/dev/null || return 1
  /usr/bin/sips -z 1440 2560 "${image}" --out "${upscaled}" >/dev/null 2>&1 || return 1
  "${CLASSIFIER}" "${upscaled}" > "${json}" 2> "${json}.stderr" || return 1
  return 0
}

metrics_for() {
  local db="$1"
  "${PYTHON}" - "${db}" <<'PY'
import json, sqlite3, sys
db = sys.argv[1]
out = {"window_count": 0, "min_effective_fps": None, "max_p95_interval_ms": None,
       "min_source_fps": None, "total_jank": 0, "total_severe": 0,
       "mechanism_events": 0, "ready_events": 0, "red_failure_events": 0}
try:
    c = sqlite3.connect(db)
    rows = c.execute("SELECT effective_fps,p95_interval_ms,jank_count,severe_count FROM game_frame_windows WHERE status='AVAILABLE'").fetchall()
    if rows:
        out["window_count"] = len(rows)
        out["min_effective_fps"] = min(r[0] for r in rows if r[0] is not None)
        out["max_p95_interval_ms"] = max(r[1] for r in rows if r[1] is not None)
        out["total_jank"] = sum(r[2] or 0 for r in rows)
        out["total_severe"] = sum(r[3] or 0 for r in rows)
    source = [r[0] for r in c.execute("SELECT source_fps FROM presentation_samples WHERE source_fps IS NOT NULL AND source_fps > 0").fetchall()]
    if source: out["min_source_fps"] = min(source)
    out["mechanism_events"] = c.execute("SELECT COUNT(*) FROM events WHERE kind IN ('ANGLE_DRIVER_LOADED_VERIFIED','DEV_EXPERIMENT_PROFILE_SEALED')").fetchone()[0]
    out["ready_events"] = c.execute("SELECT COUNT(*) FROM events WHERE kind='TFT_READY_FOR_USER'").fetchone()[0]
    out["red_failure_events"] = c.execute("SELECT COUNT(*) FROM events WHERE kind IN ('RUNTIME_FAILED','STARTUP_FAILURE_PRESERVED')").fetchone()[0]
    c.close()
except Exception as e:
    out["error"] = str(e)
print(json.dumps(out, separators=(',',':')))
PY
}

run_candidate() {
  local index="$1" id="$2" manifest="$3" profile="$4"
  local run_dir="${CAMPAIGN}/runs/$(printf '%02d' "${index}")-${id}"
  local previous_capture capture="" boot_state="" failure_reason="" outcome="REJECTED"
  local deadline now state phase stage combat_started=0 combat_seen=0 last_state="" navigation_seconds=0 login_tapped=0
  /bin/mkdir -m 700 "${run_dir}"
  previous_capture="$(latest_capture)"
  /usr/bin/jq -n --arg candidate "${id}" --arg manifest "${manifest}" --arg profile "${profile}" \
    --arg app "${DEV_APP}" --arg serial "${SERIAL}" --argjson adb_port "${ADB_PORT}" \
    --arg workload official_tft --arg quality "1920x1080@60" \
    --arg silent_env "TFTMAC_AUTONOMOUS_SILENT=1" \
    '{schema:1,candidate:$candidate,angle_manifest:(if $manifest=="" then null else $manifest end),profile:(if $profile=="" then null else $profile end),app:$app,serial:$serial,adb_server_port:$adb_port,workload:$workload,quality:$quality,auto_perfetto:true,launch_policy:{environment:$silent_env,expected_activation_policy:"prohibited",expected_visible_window_count:0}}' \
    > "${run_dir}/manifest.json"
  typeset -a launch_env
  launch_env=("TFTMAC_ENABLE_AUTO_PERFETTO=1" "TFTMAC_AUTONOMOUS_SILENT=1")
  [[ -n "${manifest}" ]] && launch_env+=("TFTMAC_ANGLE_DRIVER_MANIFEST=${manifest}")
  [[ -n "${profile}" ]] && launch_env+=("TFTMAC_DEV_EXPERIMENT_PROFILE=${profile}")
  /usr/bin/env "${launch_env[@]}" "${DEV_APP}/Contents/MacOS/TFTMACDEVLauncher" > "${run_dir}/open.log" 2>&1 &
  OPEN_PID=$!
  ACTIVE_RUN="${run_dir}"
  deadline=$(( EPOCHSECONDS + 180 ))
  while (( EPOCHSECONDS < deadline )); do
    [[ -n "${capture}" ]] || {
      local newest="$(latest_capture)"
      [[ -n "${newest}" && "${newest}" != "${previous_capture}" ]] && capture="${newest}"
    }
    ACTIVE_CAPTURE="${capture}"
    if [[ -n "${capture}" && -f "${capture}/TFTMAC_NATIVE_RUNTIME.sqlite" ]]; then
      local db="${capture}/TFTMAC_NATIVE_RUNTIME.sqlite"
      if /usr/bin/sqlite3 "${db}" "SELECT COUNT(*) FROM events WHERE kind IN ('RUNTIME_FAILED','STARTUP_FAILURE_PRESERVED')" 2>/dev/null | grep -q '^0$' || true; then :; fi
      if [[ -z "${boot_state}" ]] && "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" get-state >/dev/null 2>&1; then
        if capture_state "${run_dir}/boot.png" "${run_dir}/boot.json" "${run_dir}/boot-upscaled.png"; then
          local observed_boot_state="$(/usr/bin/jq -r '.state // "unknown"' "${run_dir}/boot.json")"
          if [[ "${observed_boot_state}" != unknown ]]; then
            boot_state="${observed_boot_state}"
            /usr/bin/jq --argjson red "$([[ "${boot_state}" == error ]] && print true || print false)" '. + {red_error:$red}' "${run_dir}/boot.json" > "${run_dir}/boot.json.tmp" \
              && /bin/mv "${run_dir}/boot.json.tmp" "${run_dir}/boot.json"
            if [[ "${boot_state}" == error ]]; then failure_reason="BOOT_RED_ERROR"; break; fi
          fi
        fi
      fi
      if /usr/bin/grep -Eq '^FATAL[[:space:]]*\||RUNTIME_FAILED|STARTUP_FAILURE_PRESERVED' "${capture}/emulator.stdout.log" 2>/dev/null; then
        failure_reason="BOOT_OR_RUNTIME_FAILURE"; break
      fi
      if /usr/bin/sqlite3 "${db}" "SELECT COUNT(*) FROM events WHERE kind='TFT_READY_FOR_USER'" 2>/dev/null | grep -q '^1$'; then
        break
      fi
    fi
    /bin/sleep 1
  done
  if [[ -z "${failure_reason}" && -z "${capture}" ]]; then failure_reason="NO_CAPTURE"; fi
  if [[ -z "${failure_reason}" && -n "${capture}" ]]; then
    if ! /usr/bin/sqlite3 "${capture}/TFTMAC_NATIVE_RUNTIME.sqlite" "SELECT COUNT(*) FROM events WHERE kind='TFT_READY_FOR_USER'" 2>/dev/null | grep -q '^1$'; then
      failure_reason="READY_TIMEOUT"
    fi
  fi
  if [[ -n "${failure_reason}" ]]; then
    stop_dev
    stop_owned_emulator
    stop_adb
    /bin/sleep 3
    [[ -n "${capture}" ]] || capture="$(latest_capture)"
    : > "${run_dir}/metrics.json"
    /usr/bin/jq -n '{window_count:0,mechanism_events:0,ready_events:0,red_failure_events:1}' > "${run_dir}/metrics.json"
    write_receipt "${index}" "${id}" "${run_dir}" "${capture}" "BOOT_FAILED" "${failure_reason}"
    return 1
  fi

  deadline=$(( EPOCHSECONDS + NAVIGATION_TIMEOUT ))
  while (( EPOCHSECONDS < deadline )); do
    if [[ -n "${capture}" && -f "${capture}/TFTMAC_NATIVE_RUNTIME.sqlite" ]]; then
      if /usr/bin/sqlite3 "${capture}/TFTMAC_NATIVE_RUNTIME.sqlite" "SELECT COUNT(*) FROM events WHERE kind IN ('RUNTIME_FAILED','STARTUP_FAILURE_PRESERVED')" 2>/dev/null | grep -q -v '^0$'; then
        failure_reason="RUNTIME_FAILURE"; break
      fi
    fi
    if ! capture_state "${run_dir}/screen.png" "${run_dir}/screen.json" "${run_dir}/screen-upscaled.png"; then
      failure_reason="CLASSIFIER_FAILURE"; break
    fi
    state="$(/usr/bin/jq -r '.state // "unknown"' "${run_dir}/screen.json")"
    phase="$(/usr/bin/jq -r '.phase // ""' "${run_dir}/screen.json")"
    stage="$(/usr/bin/jq -r '.stage // ""' "${run_dir}/screen.json")"
    /usr/bin/jq -n -c --arg utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg state "${state}" --arg phase "${phase}" --arg stage "${stage}" \
      '{utc:$utc,state:$state,phase:$phase,stage:$stage}' >> "${run_dir}/navigation.jsonl"
    if [[ "${state}" != "${last_state}" ]]; then
      /bin/cp "${run_dir}/screen.png" "${run_dir}/state-${navigation_seconds}-${state}.png" 2>/dev/null || true
      last_state="${state}"
    fi
    case "${state}" in
      error|disconnected|login_service_error)
        failure_reason="SCREEN_${state}"; break ;;
      login)
        # Saved sessions should bypass this. The splash has one recognized
        # Sign In action; no credential is typed into an unidentified form.
        if [[ "$(/usr/bin/jq -r '.reason // ""' "${run_dir}/screen.json")" == sign_in_splash && "${login_tapped}" == 0 ]]; then
          "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 960 710 >/dev/null
          login_tapped=1
        fi
        ;;
      lobby)
        "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 1500 950 >/dev/null ;;
      mode_select)
        "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 1150 800 >/dev/null ;;
      trials_lobby)
        "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 1500 950 >/dev/null ;;
      match_found)
        "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 1200 900 >/dev/null ;;
      battle)
        if [[ "${phase}" == combat ]]; then
          combat_seen=1
          (( combat_started == 0 )) && combat_started=${EPOCHSECONDS}
        elif [[ "$(/usr/bin/jq -r 'if .shop_open then "1" else "0" end' "${run_dir}/screen.json")" == 1 ]]; then
          "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 1840 1010 >/dev/null
        elif [[ "$(/usr/bin/jq -r 'if .fight_button_visible then "1" else "0" end' "${run_dir}/screen.json")" == 1 ]]; then
          "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 1780 730 >/dev/null
        elif [[ "${stage}" == "1-1" ]]; then
          "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 430 220 >/dev/null
          "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input swipe 520 900 1050 650 350 >/dev/null
          "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 1840 1010 >/dev/null
          "${ADB}" -P "${ADB_PORT}" -s "${SERIAL}" shell input tap 1780 730 >/dev/null
        fi ;;
    esac
    if (( combat_seen == 1 && EPOCHSECONDS - combat_started >= COMBAT_HOLD_SECONDS )); then break; fi
    (( navigation_seconds += 1 ))
    /bin/sleep 1
  done
  if [[ -z "${failure_reason}" && "${combat_seen}" != 1 ]]; then failure_reason="COMBAT_NOT_REACHED"; fi
  stop_dev
  stop_owned_emulator
  stop_adb
  /bin/sleep 5
  [[ -n "${capture}" ]] || capture="$(latest_capture)"
  if [[ -n "${capture}" && -f "${capture}/TFTMAC_NATIVE_RUNTIME.sqlite" ]]; then
    metrics_for "${capture}/TFTMAC_NATIVE_RUNTIME.sqlite" > "${run_dir}/metrics.json"
  else
    /usr/bin/jq -n '{window_count:0}' > "${run_dir}/metrics.json"
  fi
  local minfps p95 source mechanism ready red
  minfps="$(/usr/bin/jq -r '.min_effective_fps // -1' "${run_dir}/metrics.json")"
  p95="$(/usr/bin/jq -r '.max_p95_interval_ms // 999999' "${run_dir}/metrics.json")"
  source="$(/usr/bin/jq -r '.min_source_fps // -1' "${run_dir}/metrics.json")"
  mechanism="$(/usr/bin/jq -r '.mechanism_events // 0' "${run_dir}/metrics.json")"
  ready="$(/usr/bin/jq -r '.ready_events // 0' "${run_dir}/metrics.json")"
  red="$(/usr/bin/jq -r '.red_failure_events // 0' "${run_dir}/metrics.json")"
  if [[ -z "${failure_reason}" && "${combat_seen}" == 1 && "${mechanism}" -gt 0 && "${ready}" -gt 0 && "${red}" == 0 ]] \
      && awk -v fps="${minfps}" -v p95="${p95}" -v source="${source}" 'BEGIN { exit !(fps >= 60 && p95 <= 16.667 && source >= 60) }'; then
    outcome="WIN_60FPS"
  elif [[ -z "${failure_reason}" ]]; then
    outcome="REJECTED_BELOW_60"
    failure_reason="FPS_COUNTER_BELOW_60_OR_PRESENTATION_NOT_UNIQUE"
  else
    outcome="REJECTED"
  fi
  write_receipt "${index}" "${id}" "${run_dir}" "${capture}" "${outcome}" "${failure_reason}"
  [[ "${outcome}" == WIN_60FPS ]]
}

typeset -a IDS MANIFESTS PROFILES
IDS=(angle-reference angle-no-reuse-r13 angle-reuse-r13 angle-reuse-r14 queue-submit-inline virtual-queue-off fence-contexts-off reuse-r14-queue-submit-inline)
MANIFESTS=(
  "/Volumes/MAC MINI M4/TFTMAC/DriverBuildExchange/dev-reference-r5/driver-manifest.json"
  "/Volumes/MAC MINI M4/TFTMAC/DriverBuildExchange/dev-observed-no-reuse-r13/driver-manifest.json"
  "/Volumes/MAC MINI M4/TFTMAC/DriverBuildExchange/dev-observed-reuse-r13/driver-manifest.json"
  "/Volumes/MAC MINI M4/TFTMAC/DriverBuildExchange/dev-observed-reuse-cache-r14/driver-manifest.json"
  "" "" "" "/Volumes/MAC MINI M4/TFTMAC/DriverBuildExchange/dev-observed-reuse-cache-r14/driver-manifest.json"
)
PROFILES=("" "" "" "" queue_submit_inline virtual_queue_off fence_contexts_off queue_submit_inline)

integer index=1 ran=0
for id in "${IDS[@]}"; do
  (( ran >= MAX_CANDIDATES )) && break
  local_receipt="${CAMPAIGN}/runs/$(printf '%02d' "${index}")-${id}/receipt.json"
  if [[ -f "${local_receipt}" ]]; then
    outcome="$(/usr/bin/jq -r '.outcome' "${local_receipt}")"
    [[ "${outcome}" == WIN_60FPS ]] && { print -r -- "${CAMPAIGN}"; exit 0; }
    (( index += 1 )); continue
  fi
  # The combined transport candidate is only eligible if both individual
  # transport profiles already produced a proven 60 FPS receipt.
  if [[ "${id}" == reuse-r14-queue-submit-inline ]]; then
    /usr/bin/jq -e 'select(.candidate=="angle-reuse-r14" and .outcome=="WIN_60FPS")' "${CAMPAIGN}/ledger.jsonl" >/dev/null 2>&1 \
      && /usr/bin/jq -e 'select(.candidate=="queue-submit-inline" and .outcome=="WIN_60FPS")' "${CAMPAIGN}/ledger.jsonl" >/dev/null 2>&1 \
      || { (( index += 1 )); continue; }
  fi
  print -r -- "candidate=${id}" >> "${CAMPAIGN}/campaign.log"
  if run_candidate "${index}" "${id}" "${MANIFESTS[$index]}" "${PROFILES[$index]}"; then
    print -r -- "WIN_60FPS candidate=${id}" >> "${CAMPAIGN}/campaign.log"
    print -r -- "${CAMPAIGN}"; exit 0
  fi
  (( ran += 1 ))
  (( index += 1 ))
done
print -r -- "EXHAUSTED_NO_60FPS_WIN" >> "${CAMPAIGN}/campaign.log"
print -r -- "${CAMPAIGN}"
exit 0
