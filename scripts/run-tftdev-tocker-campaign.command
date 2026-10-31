#!/bin/zsh
set -euo pipefail

# Current-route, full-session, fail-closed Tocker's Trial campaign runner.
# This script never receives credentials or an Android PIN.  It uses the
# existing saved-login path inside TFTMAC DEV and pauses on external auth.

readonly ROOT="${0:A:h:h}"
readonly MANIFEST="${TFTDEV_TOCKER_MANIFEST:-$ROOT/scripts/tftdev-tocker-candidates.json}"
readonly APP="${TFTDEV_DEV_APP:-/Applications/TFTMAC DEV.app}"
readonly APP_ID="com.flashls1.tftmac.dev"
readonly PACKAGE="com.riotgames.league.teamfighttactics"
readonly VERSION_NAME="18.3-5530794"
readonly VERSION_CODE="8530794"
readonly INSTALLER="com.android.vending"
readonly ADB_PORT=5041
readonly SERIAL="emulator-5586"
readonly CONTROLLER_PORT=8556
readonly RUNTIME="/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow"
readonly SSOT="/Volumes/MAC MINI M4/TFTDEV-SSOT"
readonly CAMPAIGN_ROOT="${TFTDEV_TOCKER_ROOT:-$HOME/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Campaigns/tocker-autonomous}"
readonly CHECKPOINT="$CAMPAIGN_ROOT/checkpoint.json"
readonly EVENTS="$CAMPAIGN_ROOT/events.jsonl"
readonly LOCK="$CAMPAIGN_ROOT/campaign.lock"
readonly JQ="${TFTMAC_JQ:-$(command -v jq 2>/dev/null || true)}"
readonly ADB="${TFT_ADB:-$RUNTIME/SDK/platform-tools/adb}"
readonly CLASSIFIER="${TFT_SCREEN_CLASSIFIER_BINARY:-$ROOT/runtime/tft-screen-classifier}"
readonly CLASSIFIER_TIMEOUT_SEC="${TFT_SCREEN_CLASSIFIER_TIMEOUT_SEC:-20}"
readonly CLASSIFIER_BUILD="$ROOT/scripts/build-tft-screen-classifier.command"
readonly CAPTURE_DIR_ROOT="$HOME/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures"
readonly WORKLOAD_ANALYZER="$ROOT/tools/analyze_workload_window.py"
readonly PYTHON3="${TFTMAC_PYTHON3:-$(command -v python3 2>/dev/null || true)}"
readonly MEASURE_SECONDS=300
readonly SCREEN_POLL_INTERVAL_SEC="${TFT_SCREEN_POLL_INTERVAL_SEC:-1}"
readonly VCPU10_CAPABILITY_RECEIPT="$SSOT/receipts/tocker-campaign/vcpu10-runtime-capability-20261002.json"

typeset MODE="run" RESUME=0 MAX_RUNS=24 PIPELINE_EVENTS=0 FULL_MATCH=0
usage() {
  print "Usage: ${0:t} [--dry-run|--self-test|--resume|--stop] [--pipeline-events] [--full-match] [--max-runs N]"
}
while (( $# )); do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --self-test) MODE="self-test" ;;
    --resume) RESUME=1 ;;
    --stop) MODE="stop" ;;
    --max-runs) shift; [[ $# -gt 0 && "$1" == <-> ]] || { print -u2 "--max-runs requires an integer"; exit 2; }; MAX_RUNS="$1" ;;
    --pipeline-events) PIPELINE_EVENTS=1 ;;
    --full-match) FULL_MATCH=1 ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

die() { print -u2 "ERROR: $*"; exit 1; }
event() {
  mkdir -p "$CAMPAIGN_ROOT"
  "$JQ" -cn --arg event "$1" --arg detail "${2:-}" --arg utc "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    '{utc:$utc,event:$event,detail:$detail}' >> "$EVENTS"
}
hash_file() { shasum -a 256 "$1" | awk '{print $1}'; }
redact() { print -r -- "$1" | sed -E 's/(password|secret|token|pin|credential)[^=]*=[^[:space:]]+/\1=[REDACTED]/Ig'; }

validate_manifest() {
  [[ -x "$JQ" ]] || die "jq is required for manifest validation"
  [[ -f "$MANIFEST" ]] || die "candidate manifest is missing: $MANIFEST"
  "$JQ" -e '
    .schemaVersion == 1 and
    .authorityStatus == "CURRENT_18_3_ONLY" and
    .campaign.package == "com.riotgames.league.teamfighttactics" and
    .campaign.versionName == "18.3-5530794" and
    .campaign.versionCode == "8530794" and
    .campaign.installer == "com.android.vending" and
    .campaign.runtimeMode == "advanced_diagnostics" and
    .campaign.serial == "emulator-5586" and
    .campaign.adbServerPort == 5041 and
    .campaign.controllerPort == 8556 and
    (.candidates | length == 8) and
    (all(.candidates[]; (.id | test("^(control-1440p|guest-1080p|pso-wait-all|pso-priority-escalate|program-lru-20|defer-texture-1|vcpu-10|ram-5120)$")))) and
    (all(.candidates[]; (.display | test("^(2560x1440|1920x1080)$")))) and
    (all(.candidates[]; (.density == 416 and (.vcpu == 8 or .vcpu == 10) and (.ramMiB == 5120 or .ramMiB == 6144))))
  ' "$MANIFEST" >/dev/null || die "manifest failed current-route authority validation"
}

checkpoint_read() {
  if [[ -f "$CHECKPOINT" ]]; then
    "$JQ" -e . "$CHECKPOINT" >/dev/null || die "checkpoint is not valid JSON"
    cat "$CHECKPOINT"
  else
    print '{"schemaVersion":1,"status":"NEW","attempts":0,"nextCandidate":"control-1440p","runs":[]}'
  fi
}
checkpoint_write() {
  local json="$1" tmp="$CHECKPOINT.tmp.$$"
  print -r -- "$json" > "$tmp"
  "$JQ" -e . "$tmp" >/dev/null || { rm -f "$tmp"; die "refusing to write invalid checkpoint"; }
  mv -f "$tmp" "$CHECKPOINT"
}

active_owner() { [[ -f "$LOCK" ]] && awk -F= '$1=="pid" {print $2}' "$LOCK"; }
active_app() { /usr/bin/pgrep -f '/Applications/TFTMAC DEV\.app/Contents/MacOS/TFTMACDEVCore' >/dev/null 2>&1; }
active_runtime() {
  # The app window can exist while runtime startup has failed. Only the owned
  # QEMU process counts as an active emulator for launch, recovery, and cleanup
  # gates; this prevents an app-only splash from becoming an infinite wait.
  /usr/bin/pgrep -f 'qemu-system-aarch64.*-port 5586' >/dev/null 2>&1
}
reset_adb_server() {
  # The protected diagnostic port is dedicated to StockShadow. Remove only a
  # stale listener on that port, then start one mDNS-disabled daemon so the
  # runtime cannot strand a launch on an inherited/offline ADB server.
  ADB_MDNS=0 ADB_MDNS_AUTO_CONNECT= "$ADB" -P "$ADB_PORT" kill-server >/dev/null 2>&1 || true
  local listener
  for listener in $(lsof -tiTCP:"$ADB_PORT" -sTCP:LISTEN 2>/dev/null || true); do
    kill "$listener" >/dev/null 2>&1 || true
  done
  sleep 1
  ADB_MDNS=0 ADB_MDNS_AUTO_CONNECT= "$ADB" -P "$ADB_PORT" start-server >/dev/null
}
recover_adb_connection() {
  # Recover only the dedicated daemon, and only while the owned emulator is
  # still alive. A dead runtime remains a hard failure.
  active_runtime || return 1
  event "ADB_RECOVERY_ATTEMPT" "serial=$SERIAL port=$ADB_PORT"
  ADB_MDNS=0 ADB_MDNS_AUTO_CONNECT= "$ADB" -P "$ADB_PORT" kill-server >/dev/null 2>&1 || true
  sleep 1
  ADB_MDNS=0 ADB_MDNS_AUTO_CONNECT= "$ADB" -P "$ADB_PORT" start-server >/dev/null 2>&1 || return 1
  integer recovery_wait=0
  until "$ADB" -P "$ADB_PORT" -s "$SERIAL" get-state >/dev/null 2>&1; do
    (( recovery_wait += 1 ))
    if (( recovery_wait >= 15 )); then
      event "ADB_RECOVERY_FAILED" "serial=$SERIAL wait_seconds=$recovery_wait"
      return 1
    fi
    sleep 1
  done
  event "ADB_RECOVERY_READY" "serial=$SERIAL wait_seconds=$recovery_wait"
  return 0
}
stop_adb_server() {
  # Leave the protected route idle after each sealed run. The next run starts
  # its own dedicated daemon through reset_adb_server().
  ADB_MDNS=0 ADB_MDNS_AUTO_CONNECT= "$ADB" -P "$ADB_PORT" kill-server >/dev/null 2>&1 || true
  local listener
  for listener in $(lsof -tiTCP:"$ADB_PORT" -sTCP:LISTEN 2>/dev/null || true); do
    kill "$listener" >/dev/null 2>&1 || true
  done
}
acquire_lock() {
  mkdir -p "$CAMPAIGN_ROOT"
  if [[ -f "$LOCK" ]]; then
    local owner="$(active_owner)"
    if [[ "$owner" == <-> ]] && kill -0 "$owner" >/dev/null 2>&1; then die "campaign already owned by PID $owner"; fi
    (active_app || active_runtime) && die "stale campaign lock cannot be recovered while current DEV app or emulator is active"
    rm -f "$LOCK"
  fi
  { print "pid=$$"; print "started_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; } > "$LOCK"
  trap 'rm -f "$LOCK"' EXIT
}

preflight() {
  [[ -d "$APP" ]] || die "protected DEV app missing: $APP"
  [[ -x "$ADB" ]] || die "StockShadow ADB missing: $ADB"
  [[ -d "$RUNTIME" ]] || die "StockShadow runtime missing: $RUNTIME"
  [[ -d "$SSOT" ]] || die "TFTDEV SSOT missing: $SSOT"
  [[ -x "$PYTHON3" ]] || die "python3 is required for workload-window analysis"
  [[ -x "$WORKLOAD_ANALYZER" ]] || die "workload analyzer is missing: $WORKLOAD_ANALYZER"
  [[ "$SCREEN_POLL_INTERVAL_SEC" == <-> && "$SCREEN_POLL_INTERVAL_SEC" -ge 1 && "$SCREEN_POLL_INTERVAL_SEC" -le 5 ]] || die "TFT_SCREEN_POLL_INTERVAL_SEC must be an integer from 1 through 5"
  [[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist")" == "$APP_ID" ]] || die "unexpected DEV bundle identity"
  [[ "$(/usr/bin/pgrep -f 'TFTMAC.*(Control|APPLETFT)' || true)" == "" ]] || die "another TFTMAC route is active"
  local free="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
  (( free > 5 * 1024 * 1024 )) || die "less than 5 GiB is free for a capture"
  if active_app || active_runtime; then die "ACTIVE_CURRENT_RUNTIME: $SERIAL or TFTMAC DEV is already running"; fi
  [[ -f "$SSOT/receipts/m6-host-preflight-2026-09-30.txt" ]] || die "M6 host receipt missing"
  if (( PIPELINE_EVENTS == 1 )); then
    # The protected current route is StockShadow. An opt-in environment flag
    # cannot turn it into a source-instrumented causal runtime. Refuse before
    # launching a game unless the authority registry names a real source
    # runtime and its host artifact exists. This prevents a full match from
    # being spent on a guaranteed zero-segment admission attempt.
    local runtime_modes="$ROOT/ssot/runtime-modes.json"
    local runtime_variant="$("$JQ" -r '.modes.advanced_diagnostics.runtime_variant // ""' "$runtime_modes")"
    local source_path="$("$JQ" -r '.modes.advanced_diagnostics.host_application.source_path // ""' "$runtime_modes")"
    [[ "$runtime_variant" != "stock_shadow" && -n "$source_path" && -e "$source_path" ]] || \
      die "PIPELINE_SOURCE_HOOK_UNAVAILABLE: current advanced_diagnostics authority is StockShadow without a source runtime"
  fi
}

candidate_json() { "$JQ" -c --arg id "$1" '.candidates[] | select(.id==$id)' "$MANIFEST"; }
candidate_supported() {
  local c="$1"
  local id="$(print -r -- "$c" | "$JQ" -r .id)"
  # Current disposition outranks an older successful admission receipt.
  print -r -- "$c" | "$JQ" -e '.enabled == true and ((.decision // "") | test("REJECTED|NO_ADMISSIBLE_GAIN|NOT_ADMITTED") | not)' >/dev/null || return 2
  [[ "$id" == "control-1440p" || "$id" == "guest-1080p" ]] && return 0
  if [[ "$id" == "ram-5120" ]]; then
    local admission="$SSOT/receipts/tocker-campaign/ram5120-admission-20261002.json"
    [[ -f "$admission" ]] || return 2
    "$JQ" -e '
      .decision == "ADMIT_RAM5120_MATCHED_COMPARISON" and
      .promotion == "ONLY_AFTER_THREE_VALID_MATCHED_RUNS" and
      .candidate.id == "ram-5120" and
      .candidate.display == "1920x1080" and
      .candidate.vcpu == 8 and
      .candidate.ramMiB == 5120 and
      .control.id == "guest-1080p" and
      .control.validRuns >= 3 and
      (.evidence.hostSwapUsedKiBMax | max) > 0 and
      (.evidence.hostAvailableKiBP05 | min) > 0
    ' "$admission" >/dev/null || return 2
    return 0
  fi
  if [[ "$id" == "pso-wait-all" ]]; then
    local admission="$SSOT/receipts/tocker-campaign/pso-wait-all-admission-20261002.json"
    [[ -f "$admission" ]] || return 2
    print -r -- "$c" | "$JQ" -e '.enabled == true and .decision == "PSO_WAIT_POLICY_COMPARISON"' >/dev/null || return 2
    "$JQ" -e '
      .decision == "ADMIT_PSO_WAIT_ALL_MATCHED_COMPARISON" and
      .promotion == "ONLY_AFTER_THREE_VALID_MATCHED_RUNS" and
      .candidate.id == "pso-wait-all" and
      .candidate.cvar == "r.PSOPrecaching.WaitForHighPriorityRequestsOnly" and
      .candidate.value == 0 and
      .control.value == 1 and
      .control.display == "1920x1080" and
      .authority.causalOwnership == "UNKNOWN_PRESENT_LINEAGE_GAP"
    ' "$admission" >/dev/null || return 2
    return 0
  fi
  if [[ "$id" == "pso-priority-escalate" ]]; then
    local admission="$SSOT/receipts/tocker-campaign/pso-priority-escalate-admission-20261002.json"
    [[ -f "$admission" ]] || return 2
    print -r -- "$c" | "$JQ" -e '.enabled == true and .decision == "PSO_PRIORITY_ESCALATION_COMPARISON"' >/dev/null || return 2
    "$JQ" -e '
      .decision == "ADMIT_PSO_PRIORITY_ESCALATION_MATCHED_COMPARISON" and
      .promotion == "ONLY_AFTER_THREE_VALID_MATCHED_RUNS" and
      .candidate.id == "pso-priority-escalate" and
      .candidate.cvar == "r.PSOPrecaching.PermitPriorityEscalation" and
      .candidate.value == 1 and
      .control.value == 0 and
      .authority.causalOwnership == "UNKNOWN_PRESENT_LINEAGE_GAP"
    ' "$admission" >/dev/null || return 2
    return 0
  fi
  if [[ "$id" == "program-lru-20" ]]; then
    local admission="$SSOT/receipts/tocker-campaign/program-lru20-plan-gate-20261002.json"
    [[ -f "$admission" ]] || return 2
    print -r -- "$c" | "$JQ" -e '.enabled == true and .decision == "PROGRAM_LRU_EVICTION_COMPARISON"' >/dev/null || return 2
    "$JQ" -e '
      .decision == "ADMIT_ONE_FACTOR_MATCHED_COMPARISON" and
      .hypothesis.setting == "r.OpenGL.ProgramLRUEvictTimeSeconds" and
      .hypothesis.control == 0 and
      .hypothesis.candidate == 20 and
      .authority.package == "com.riotgames.league.teamfighttactics" and
      .authority.versionName == "18.3-5530794" and
      .authority.guestDisplay == "1920x1080" and
      .authority.vcpu == 8 and
      .authority.ramMiB == 6144 and
      .zoemc.verdict == "PLAN_MODEL_PASS" and
      .zenGate.verdict == "PASS"
    ' "$admission" >/dev/null || return 2
    return 0
  fi
  if [[ "$id" == "defer-texture-1" ]]; then
    local admission="$SSOT/receipts/tocker-campaign/defer-texture1-plan-gate-20261002.json"
    [[ -f "$admission" ]] || return 2
    print -r -- "$c" | "$JQ" -e '.enabled == true and .decision == "DEFER_TEXTURE_CREATION_COMPARISON"' >/dev/null || return 2
    "$JQ" -e '
      .decision == "ADMIT_ONE_FACTOR_MATCHED_COMPARISON" and
      .hypothesis.setting == "r.OpenGL.DeferTextureCreation" and
      .hypothesis.control == 0 and
      .hypothesis.candidate == 1 and
      .authority.package == "com.riotgames.league.teamfighttactics" and
      .authority.versionName == "18.3-5530794" and
      .authority.guestDisplay == "1920x1080" and
      .authority.vcpu == 8 and
      .authority.ramMiB == 6144 and
      .zoemc.verdict == "PLAN_MODEL_PASS" and
      .zenGate.verdict == "PASS"
    ' "$admission" >/dev/null || return 2
    return 0
  fi
  if [[ "$id" == "vcpu-10" ]]; then
    # StockShadow's sealed QEMU machine currently proves a hard max of eight
    # CPUs. Refuse this candidate before launch once that fact is recorded;
    # otherwise every attempt spends a startup timeout on an impossible
    # -cores 10 invocation and obscures the real blocker.
    if [[ -f "$VCPU10_CAPABILITY_RECEIPT" ]] && "$JQ" -e '
      .decision == "REJECT_VCPU10_RUNTIME_CAPABILITY" and
      .runtime.variant == "stock_shadow" and
      .requested.vcpu == 10 and
      .observed.maxVCPU == 8 and
      (.evidence.stderr | contains("Number of SMP CPUs requested (10) exceeds max CPUs supported by machine")) and
      (.evidence.stderr | contains("mach-virt")) and
      (.evidence.stderr | contains("(8)"))
    ' "$VCPU10_CAPABILITY_RECEIPT" >/dev/null; then
      return 2
    fi
    # This candidate is admitted only by a current, immutable evidence receipt
    # produced from matched 1440p control runs and the M6 host receipt. The
    # receipt admits comparison, never promotion or causal ownership.
    local admission="$SSOT/receipts/tocker-campaign/vcpu10-admission-20261002.json"
    [[ -f "$admission" ]] || return 2
    "$JQ" -e '
      .decision == "ADMIT_VCPU10_MATCHED_COMPARISON" and
      .promotion == "NOT_ALLOWED_FROM_ADMISSION" and
      .causalOwnership == "UNKNOWN_PRESENT_LINEAGE_GAP" and
      .candidate.id == "vcpu-10" and
      .candidate.display == "2560x1440" and
      .candidate.vcpu == 10 and
      .evidence.gate.allControlCpuP95AtLeast400 == true and
      .evidence.gate.allThermalNominal == true
    ' "$admission" >/dev/null || return 2
    return 0
  fi
  return 2
}

typeset CURRENT_CANDIDATE_ID="control-1440p"
typeset CURRENT_DISPLAY="2560x1440"
typeset CURRENT_VCPU="8"
typeset CURRENT_RAM="6144"
typeset CURRENT_RUNS_REQUIRED="3"
load_candidate() {
  local candidate="$1"
  local json="$(candidate_json "$candidate")"
  [[ -n "$json" ]] || die "candidate is not in the current manifest: $candidate"
  candidate_supported "$json" || die "candidate $candidate is not admitted by current evidence gates"
  CURRENT_CANDIDATE_ID="$candidate"
  CURRENT_DISPLAY="$(print -r -- "$json" | "$JQ" -r .display)"
  CURRENT_VCPU="$(print -r -- "$json" | "$JQ" -r .vcpu)"
  CURRENT_RAM="$(print -r -- "$json" | "$JQ" -r .ramMiB)"
  CURRENT_RUNS_REQUIRED="$(print -r -- "$json" | "$JQ" -r '.runsRequired // 3')"
}

write_dry_receipt() {
  local candidate="$1" run_id="dry-run-$(date -u '+%Y%m%dT%H%M%SZ')"
  mkdir -p "$CAMPAIGN_ROOT/receipts"
  "$JQ" -n --arg run "$run_id" --arg candidate "$candidate" --arg manifest "$MANIFEST" \
    --arg package "$PACKAGE" --arg version "$VERSION_NAME" --arg installer "$INSTALLER" \
    --arg route "UNREAL_OPENGL_ES_THROUGH_ANGLE" \
    '{schemaVersion:1,mode:"DRY_RUN",runId:$run,candidateId:$candidate,valid:false,status:"NOT_STARTED",authority:{package:$package,versionName:$version,installer:$installer,route:$route},capture:{status:"NOT_STARTED",reason:"dry_run"},decision:"NOT_RUN"}' \
    > "$CAMPAIGN_ROOT/receipts/$run_id.json"
}

self_test() {
  mkdir -p "$CAMPAIGN_ROOT"
  validate_manifest
  [[ "$MAX_RUNS" -ge 1 && "$MAX_RUNS" -le 24 ]] || die "max runs must be 1..24"
  local c id display vcpu
  while IFS= read -r c; do
    id="$(print -r -- "$c" | "$JQ" -r .id)"; display="$(print -r -- "$c" | "$JQ" -r .display)"; vcpu="$(print -r -- "$c" | "$JQ" -r .vcpu)"
    [[ "$display" == 2560x1440 || "$display" == 1920x1080 ]] || die "bad display for $id"
    [[ "$vcpu" == 8 || "$vcpu" == 10 ]] || die "bad vCPU for $id"
    [[ "$c" != *password* && "$c" != *secret* && "$c" != *pin* ]] || die "credential material in manifest"
  done < <("$JQ" -c '.candidates[]' "$MANIFEST")
  "$JQ" -e '
    any(.candidates[]; .id == "vcpu-10" and
      .enabled == false and
      .decision == "REJECTED_CURRENT_RUNTIME_CAPABILITY" and
      .blockedBy == "VCPU10_UNSUPPORTED_BY_STOCKSHADOW_QEMU_MAX_8")
  ' "$MANIFEST" >/dev/null || die "manifest did not preserve the vcpu-10 runtime-capability closure"
  local redacted="$(redact 'password=do-not-log pin=1111 token=hidden')"
  [[ "$redacted" == *REDACTED* ]] || die "redaction self-test failed"
  local cp="$(checkpoint_read)"
  checkpoint_write "$cp"
  "$JQ" -e '.schemaVersion == 1 and (.status | IN("NEW","RUNNING","BASELINE_VALID","PAUSED","QUEUE_EXHAUSTED","BUDGET_EXHAUSTED"))' "$CHECKPOINT" >/dev/null || die "checkpoint self-test failed"
  candidate_supported "$(candidate_json control-1440p)" || die "control candidate was not admitted"
  candidate_supported "$(candidate_json guest-1080p)" || die "1080p candidate was not admitted"
  ! candidate_supported "$(candidate_json ram-5120)" || die "rejected ram-5120 candidate was re-admitted"
  ! candidate_supported "$(candidate_json pso-wait-all)" || die "rejected pso-wait-all candidate was re-admitted"
  "$JQ" -e 'any(.candidates[]; .id == "pso-wait-all" and .enabled == false and .decision == "REJECTED_NO_ADMISSIBLE_GAIN" and .blockedBy == "NO_ADMISSIBLE_GAIN")' "$MANIFEST" >/dev/null || die "pso-wait-all rejection closure missing"
  ! candidate_supported "$(candidate_json pso-priority-escalate)" || die "rejected pso-priority-escalate candidate was re-admitted"
  "$JQ" -e 'any(.candidates[]; .id == "pso-priority-escalate" and .enabled == false and .decision == "REJECTED_NO_ADMISSIBLE_GAIN" and .blockedBy == "NO_ADMISSIBLE_GAIN")' "$MANIFEST" >/dev/null || die "pso-priority-escalate rejection closure missing"
  ! candidate_supported "$(candidate_json program-lru-20)" || die "rejected program-lru-20 candidate was re-admitted"
  "$JQ" -e 'any(.candidates[]; .id == "program-lru-20" and .enabled == false and .decision == "REJECTED_NO_ADMISSIBLE_GAIN" and .blockedBy == "NO_ADMISSIBLE_GAIN")' "$MANIFEST" >/dev/null || die "program-lru-20 rejection closure missing"
  ! candidate_supported "$(candidate_json defer-texture-1)" || die "rejected defer-texture-1 candidate was re-admitted"
  "$JQ" -e 'any(.candidates[]; .id == "defer-texture-1" and .enabled == false and .decision == "REJECTED_NO_ADMISSIBLE_GAIN" and .blockedBy == "PRIOR_REJECTION_INTERRUPTED_RETEST_INCOMPLETE")' "$MANIFEST" >/dev/null || die "defer-texture-1 rejection closure missing"
  ! candidate_supported "$(candidate_json vcpu-10)" || die "vcpu-10 runtime-capability rejection was not enforced"
  load_candidate control-1440p
  [[ "$CURRENT_DISPLAY" == "2560x1440" && "$CURRENT_VCPU" == "8" && "$CURRENT_RAM" == "6144" ]] || die "control candidate load mismatch"
  load_candidate guest-1080p
  [[ "$CURRENT_DISPLAY" == "1920x1080" && "$CURRENT_VCPU" == "8" && "$CURRENT_RAM" == "6144" ]] || die "guest-1080p candidate load mismatch"
  print "SELF_TEST_PASS manifest=1 checkpoint=1 redaction=1 current_route=1 credentials=0"
}

stop_campaign() {
  if [[ -f "$LOCK" ]]; then
    local owner="$(active_owner)"
    if [[ "$owner" == <-> ]] && kill -0 "$owner" >/dev/null 2>&1; then kill -TERM "$owner"; print "stop_requested pid=$owner"; return 0; fi
    rm -f "$LOCK"
  fi
  print "stop_no_active_campaign"
}

run_control_smoke() {
  local run_id="$(date -u '+%Y%m%dT%H%M%SZ')-$CURRENT_CANDIDATE_ID-$$"
  local run_dir="$CAMPAIGN_ROOT/runs/$run_id"
  mkdir -p "$run_dir"
  event "RUN_START" "$run_id $CURRENT_CANDIDATE_ID"
  event "OBSERVER_CONFIG" "classifier_poll_interval_sec=$SCREEN_POLL_INTERVAL_SEC"
  touch "$run_dir/launch-start"
  /usr/bin/caffeinate -dimsu -w $$ >/dev/null 2>&1 & local caf="$!"
  trap 'if [[ -n "${caf:-}" ]]; then kill "$caf" >/dev/null 2>&1 || true; fi; rm -f "$LOCK"' EXIT
  print "Launching protected DEV route for $CURRENT_CANDIDATE_ID: $run_id"
  reset_adb_server || { print -u2 "ADB server could not be prepared on port $ADB_PORT"; return 1; }
  local -a pipeline_env=()
 if (( PIPELINE_EVENTS == 1 )); then
   pipeline_env=(--env TFTMAC_PIPELINE_EVENT_V1=1)
   event "PIPELINE_EVENTS_REQUESTED" "diagnostic source instrumentation requested for isolated current-route run"
 fi
 local -a flush_env=()
  if [[ "${TFTMAC_DEV_ASG_FLUSH:-}" == <-> ]]; then
    flush_env=(--env "TFTMAC_DEV_ASG_FLUSH=$TFTMAC_DEV_ASG_FLUSH")
    event "ASG_FLUSH_OVERRIDE" "requested_us=$TFTMAC_DEV_ASG_FLUSH"
  fi
 local -a direct_launch_env=(
   TFTMAC_AUTONOMOUS_SILENT=1
   TFTMAC_RUNTIME_MODE=advanced_diagnostics
   "TFTMAC_DEV_DISPLAY=$CURRENT_DISPLAY"
   "TFTMAC_DEV_VCPU=$CURRENT_VCPU"
   "TFTMAC_DEV_RAM_MIB=$CURRENT_RAM"
 )
 if [[ "$CURRENT_CANDIDATE_ID" == "pso-wait-all" || "$CURRENT_CANDIDATE_ID" == "pso-priority-escalate" || "$CURRENT_CANDIDATE_ID" == "program-lru-20" || "$CURRENT_CANDIDATE_ID" == "defer-texture-1" ]]; then
   if [[ "$CURRENT_CANDIDATE_ID" == "pso-wait-all" ]]; then
     direct_launch_env+=(TFTMAC_DEV_EXPERIMENT_PROFILE=pso_wait_all)
     event "EXPERIMENT_PROFILE_REQUESTED" "profile=pso_wait_all cvar=r.PSOPrecaching.WaitForHighPriorityRequestsOnly value=0"
   elif [[ "$CURRENT_CANDIDATE_ID" == "pso-priority-escalate" ]]; then
     direct_launch_env+=(TFTMAC_DEV_EXPERIMENT_PROFILE=pso_priority_escalate)
     event "EXPERIMENT_PROFILE_REQUESTED" "profile=pso_priority_escalate cvar=r.PSOPrecaching.PermitPriorityEscalation value=1"
   elif [[ "$CURRENT_CANDIDATE_ID" == "program-lru-20" ]]; then
     direct_launch_env+=(TFTMAC_DEV_EXPERIMENT_PROFILE=program_lru_evict20)
     event "EXPERIMENT_PROFILE_REQUESTED" "profile=program_lru_evict20 cvar=r.OpenGL.ProgramLRUEvictTimeSeconds value=20"
   else
     direct_launch_env+=(TFTMAC_DEV_EXPERIMENT_PROFILE=defer_texture_creation1)
     event "EXPERIMENT_PROFILE_REQUESTED" "profile=defer_texture_creation1 cvar=r.OpenGL.DeferTextureCreation value=1"
   fi
 fi
 if (( PIPELINE_EVENTS == 1 )); then direct_launch_env+=(TFTMAC_PIPELINE_EVENT_V1=1); fi
 if [[ "${TFTMAC_DEV_ASG_FLUSH:-}" == <-> ]]; then direct_launch_env+=("TFTMAC_DEV_ASG_FLUSH=$TFTMAC_DEV_ASG_FLUSH"); fi
 local -a experiment_open_env=()
 if [[ "$CURRENT_CANDIDATE_ID" == "pso-wait-all" ]]; then
   experiment_open_env=(--env TFTMAC_DEV_EXPERIMENT_PROFILE=pso_wait_all)
 elif [[ "$CURRENT_CANDIDATE_ID" == "pso-priority-escalate" ]]; then
   experiment_open_env=(--env TFTMAC_DEV_EXPERIMENT_PROFILE=pso_priority_escalate)
 elif [[ "$CURRENT_CANDIDATE_ID" == "program-lru-20" ]]; then
   experiment_open_env=(--env TFTMAC_DEV_EXPERIMENT_PROFILE=program_lru_evict20)
 elif [[ "$CURRENT_CANDIDATE_ID" == "defer-texture-1" ]]; then
   experiment_open_env=(--env TFTMAC_DEV_EXPERIMENT_PROFILE=defer_texture_creation1)
 fi
 if [[ -x "$APP/Contents/MacOS/TFTMACDEVLauncher" ]]; then
   # Launch the diagnostic app executable directly.  LaunchServices can leave
   # the external StockShadow emulator in dyld before controller publication;
   # autonomous runs must have a deterministic process boundary.
   env "${direct_launch_env[@]}" "$APP/Contents/MacOS/TFTMACDEVLauncher" > "$run_dir/launcher.log" 2>&1 &
 else
   /usr/bin/open -n -W \
     "${pipeline_env[@]}" \
     --env TFTMAC_AUTONOMOUS_SILENT=1 \
     --env TFTMAC_RUNTIME_MODE=advanced_diagnostics \
     --env TFTMAC_DEV_DISPLAY="$CURRENT_DISPLAY" \
     --env TFTMAC_DEV_VCPU="$CURRENT_VCPU" \
     --env TFTMAC_DEV_RAM_MIB="$CURRENT_RAM" \
     "${experiment_open_env[@]}" \
     "${flush_env[@]}" \
     "$APP" > "$run_dir/launcher.log" 2>&1 &
 fi
  local open_pid="$!"
  integer waited=0
  until active_runtime; do
    (( waited += 1 ))
    (( waited < 180 )) || { print -u2 "launch did not create the current runtime"; return 1; }
    sleep 1
  done
  export TFT_ADB_SERVER_PORT="$ADB_PORT"
  export ANDROID_ADB_SERVER_PORT="$ADB_PORT"
  ADB_MDNS=0 ADB_MDNS_AUTO_CONNECT= ANDROID_ADB_SERVER_PORT="$ADB_PORT" "$ADB" -P "$ADB_PORT" start-server >/dev/null
  waited=0
  until "$ADB" -P "$ADB_PORT" -s "$SERIAL" get-state >/dev/null 2>&1; do
    (( waited += 1 ))
    (( waited < 180 )) || { print -u2 "ADB did not become ready"; return 1; }
    sleep 1
  done
  local ready_capture=""
  waited=0
  while (( waited < 240 )); do
    for candidate in "$CAPTURE_DIR_ROOT"/*/native-events.jsonl; do
      [[ -f "$candidate" && "$candidate" -nt "$run_dir/launch-start" ]] || continue
      if grep -Fq '"kind":"TFT_READY_FOR_USER"' "$candidate"; then ready_capture="$candidate"; break; fi
    done
    [[ -n "$ready_capture" ]] && break
    sleep 2
    (( waited += 2 ))
  done
  [[ -n "$ready_capture" ]] || { print -u2 "CONTROL_SMOKE_BLOCKED: TFT_READY_FOR_USER was not observed"; return 2; }
  print "CONTROL_SMOKE_READY: native automatic capture and saved-login path reached readiness"
  local package_report="$( "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell dumpsys package "$PACKAGE" 2>/dev/null | tr -d '\r')"
  [[ "$package_report" == *"versionName=$VERSION_NAME"* ]] || { print -u2 "wrong TFT version observed"; return 3; }
  [[ "$package_report" == *"versionCode=$VERSION_CODE"* ]] || { print -u2 "wrong TFT version code observed"; return 3; }
  [[ "$package_report" == *"installerPackageName=$INSTALLER"* || "$package_report" == *"installer=$INSTALLER"* ]] || { print -u2 "TFT installer authority was not Google Play"; return 3; }
  local observed_size="$( "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell wm size 2>/dev/null | tr -d '\r')"
  local observed_density="$( "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell wm density 2>/dev/null | tr -d '\r')"
  [[ "$observed_size" == *"$CURRENT_DISPLAY"* ]] || { print -u2 "requested display $CURRENT_DISPLAY was not observed: $observed_size"; return 3; }
  [[ "$observed_density" == *"416"* ]] || { print -u2 "density 416 was not observed: $observed_density"; return 3; }
  local qemu_line="$(ps -axo command | grep 'qemu-system-aarch64.*-port 5586' | grep -v grep | head -1 || true)"
  [[ "$qemu_line" == *"-cores $CURRENT_VCPU"* && "$qemu_line" == *"-memory $CURRENT_RAM"* ]] || { print -u2 "requested resources were not observed"; return 3; }
  local observed_vcpu="$(print -r -- "$qemu_line" | sed -n 's/.*-cores \([0-9][0-9]*\).*/\1/p')"
  local observed_ram="$(print -r -- "$qemu_line" | sed -n 's/.*-memory \([0-9][0-9]*\).*/\1/p')"
  print "CONTROL_SMOKE_AUTHORITY_PASS package=$PACKAGE version=$VERSION_NAME"
  local display_width="$(print -r -- "$CURRENT_DISPLAY" | cut -d x -f1)" display_height="$(print -r -- "$CURRENT_DISPLAY" | cut -d x -f2)" measurement_started=0 measurement_valid=0 unknown_since=0 resetting_stale=0 reconnect_attempts=0 ready_retry_count=0
  typeset WORKLOAD_START_NS="" WORKLOAD_END_NS=""
  typeset CURRENT_SCREEN_HASH=""
  typeset ACTION_ACK=0
  typeset LAST_ACTION_STAGE=""
  typeset LAST_PHASE=""
  typeset -A action_counts shop_buy_attempted shop_close_attempted reward_sweep_attempted planning_prepared
  integer trial_choice_serial=0
  scale_x() { awk -v value="$1" -v width="$display_width" 'BEGIN { printf "%d", value * width / 2560 + 0.5 }'; }
  scale_y() { awk -v value="$1" -v height="$display_height" 'BEGIN { printf "%d", value * height / 1440 + 0.5 }'; }
  local input_width=$(( display_width * 5 / 4 )) input_height=$(( display_height * 5 / 4 ))
  game_scale_x() { awk -v value="$1" -v width="$input_width" 'BEGIN { printf "%d", value * width / 2560 + 0.5 }'; }
  game_scale_y() { awk -v value="$1" -v height="$input_height" 'BEGIN { printf "%d", value * height / 1440 + 0.5 }'; }
  snapshot() {
    local screen_tmp="$run_dir/current.png.tmp" screen_stderr="$run_dir/screencap.stderr.log" png_signature="" screenshot_ok=0
    integer screenshot_attempt=0 screenshot_recovery_attempt=0
    while (( screenshot_attempt < 5 )); do
      (( screenshot_attempt += 1 ))
      rm -f "$screen_tmp"
      if "$ADB" -P "$ADB_PORT" -s "$SERIAL" exec-out screencap -p > "$screen_tmp" 2>> "$screen_stderr"; then
        png_signature="$(dd if="$screen_tmp" bs=1 count=8 2>/dev/null | od -An -tx1 | tr -d ' \\n')"
        if [[ "$png_signature" == "89504e470d0a1a0a" ]]; then
          mv -f "$screen_tmp" "$run_dir/current.png"
          screenshot_ok=1
          break
        fi
      fi
      sleep 1
    done
    if (( screenshot_ok == 0 && screenshot_recovery_attempt == 0 )) && active_runtime; then
      screenshot_recovery_attempt=1
      if recover_adb_connection; then
        screenshot_attempt=0
        while (( screenshot_attempt < 5 )); do
          (( screenshot_attempt += 1 ))
          rm -f "$screen_tmp"
          if "$ADB" -P "$ADB_PORT" -s "$SERIAL" exec-out screencap -p > "$screen_tmp" 2>> "$screen_stderr"; then
            png_signature="$(dd if="$screen_tmp" bs=1 count=8 2>/dev/null | od -An -tx1 | tr -d ' \\n')"
            if [[ "$png_signature" == "89504e470d0a1a0a" ]]; then
              mv -f "$screen_tmp" "$run_dir/current.png"
              screenshot_ok=1
              break
            fi
          fi
          sleep 1
        done
      fi
    fi
    (( screenshot_ok == 1 )) || { event "SCREENSHOT_CAPTURE_GAP" "attempts=$screenshot_attempt recovery_attempted=$screenshot_recovery_attempt"; return 1; }
    CURRENT_SCREEN_HASH="$(hash_file "$run_dir/current.png")"
    integer classifier_attempt=0 classifier_succeeded=0
    while (( classifier_attempt < 2 )); do
      (( classifier_attempt += 1 ))
      rm -f "$run_dir/current.json"
      "$CLASSIFIER" "$run_dir/current.png" > "$run_dir/current.json" &
      local classifier_pid="$!"
      integer classifier_wait=0
      local classifier_state=""
      while kill -0 "$classifier_pid" >/dev/null 2>&1; do
        classifier_state="$(ps -p "$classifier_pid" -o stat= 2>/dev/null | tr -d '[:space:]')"
        [[ "$classifier_state" == Z* ]] && break
        if (( classifier_wait >= CLASSIFIER_TIMEOUT_SEC )); then
          kill -TERM "$classifier_pid" >/dev/null 2>&1 || true
          sleep 1
          kill -KILL "$classifier_pid" >/dev/null 2>&1 || true
          wait "$classifier_pid" >/dev/null 2>&1 || true
          event "CLASSIFIER_TIMEOUT" "timeout_seconds=$CLASSIFIER_TIMEOUT_SEC attempt=$classifier_attempt"
          break
        fi
        sleep 1
        (( classifier_wait += 1 ))
      done
      if wait "$classifier_pid" >/dev/null 2>&1; then
        classifier_succeeded=1
        break
      fi
      if (( classifier_attempt < 2 )); then
        event "CLASSIFIER_RETRY" "attempt=$classifier_attempt"
        sleep 1
      fi
    done
    (( classifier_succeeded == 1 )) || return 1
    if [[ "$("$JQ" -r '.state // "unknown"' "$run_dir/current.json")" == "login" ]]; then
      rm -f "$run_dir/current.png"
    fi
    "$JQ" -c --arg utc "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      '. + {observed_utc:$utc}' "$run_dir/current.json" >> "$run_dir/navigation.jsonl"
  }
  action() {
    local before_state="$1" label="$2" x="$3" y="$4" space="${5:-display}" before_hash after_state after_hash
    local action_key="$before_state:$label"
    integer action_count="${action_counts[$action_key]:-0}"
    (( action_count < 3 )) || { print -u2 "action acknowledgement failed after three attempts: $label"; return 1; }
    action_counts[$action_key]=$(( action_count + 1 ))
    before_hash="$CURRENT_SCREEN_HASH"
    "$JQ" -cn --arg utc "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg before "$before_state" \
      --arg action "$label" --argjson x "$x" --argjson y "$y" --arg screenshot "$before_hash" \
      --arg space "$space" '{utc:$utc,state_before:$before,action:$action,target:{x:$x,y:$y,coordinate_space:$space},screenshot_before_sha256:$screenshot}' >> "$run_dir/actions.jsonl"
    if [[ "$space" == "game" ]]; then
      "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell input tap "$(game_scale_x "$x")" "$(game_scale_y "$y")" >/dev/null
    elif [[ "$space" == "back" ]]; then
      "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell input keyevent 4 >/dev/null
    elif [[ "$space" == "center" ]]; then
      "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell input tap "$(( display_width / 2 + x ))" "$(( display_height / 2 + y ))" >/dev/null
    else
      "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell input tap "$(scale_x "$x")" "$(scale_y "$y")" >/dev/null
    fi
    sleep 1
    snapshot || return 1
    after_state="$("$JQ" -r '.state // "unknown"' "$run_dir/current.json")"
    after_hash="$CURRENT_SCREEN_HASH"
    if [[ "$before_hash" != "$after_hash" || "$before_state" != "$after_state" ]]; then
      ACTION_ACK=1
    else
      ACTION_ACK=0
    fi
    "$JQ" -cn --arg utc "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg before "$before_state" \
      --arg action "$label" --arg after "$after_state" --arg before_hash "$before_hash" --arg screenshot "$after_hash" --arg space "$space" \
      '{utc:$utc,state_before:$before,action:$action,state_after:$after,coordinate_space:$space,screenshot_before_sha256:$before_hash,screenshot_after_sha256:$screenshot,acknowledged:($before != $after or $before_hash != $screenshot)}' >> "$run_dir/actions.jsonl"
  }
  trial_choice_action() {
    local before_state="$1" label="$2" after_state before_hash="$CURRENT_SCREEN_HASH"
    local point x y action_label
    # Coordinates are expressed in the 2560x1440 display reference used by
    # scale_x/scale_y. At 1920x1080 the three visible choice cards are near
    # these centers. Try each card once and require a semantic transition.
    local -a points=("733 700" "1280 700" "1827 700")
    for point in "${points[@]}"; do
      x="${point% *}"; y="${point#* }"
      trial_choice_serial=$(( trial_choice_serial + 1 ))
      action_label="${label}_${trial_choice_serial}"
      action "$before_state" "$action_label" "$x" "$y" display || return 1
      after_state="$($JQ -r '.state // "unknown"' "$run_dir/current.json")"
      # A valid choice can advance to another choice screen, so the semantic
      # state may remain trial_choice. A changed screenshot is the acknowledgement
      # in that case; unknown screens never count as success.
      if [[ "$after_state" != "unknown" && ( "$after_state" != "trial_choice" || "$CURRENT_SCREEN_HASH" != "$before_hash" ) ]]; then
        return 0
      fi
    done
    print -u2 "trial choice acknowledgement failed after bounded card targets: $label"
    return 1
  }
  reward_sweep() {
    local before_state="$1" before_hash="$CURRENT_SCREEN_HASH" after_state after_hash input_script=""
    local point
    local -a points=("1050 300" "860 610" "1280 700")
    "$JQ" -cn --arg utc "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg before "$before_state" \
      --arg action "COLLECT_REWARD_ORBS" --arg screenshot "$before_hash" \
      '{utc:$utc,state_before:$before,action:$action,coordinate_space:"game",screenshot_before_sha256:$screenshot}' >> "$run_dir/actions.jsonl"
    for point in "${points[@]}"; do
      input_script+="input tap $(game_scale_x "${point% *}") $(game_scale_y "${point#* }"); sleep 0.65; "
    done
    "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell "$input_script" >/dev/null
    snapshot || return 1
    after_state="$($JQ -r '.state // "unknown"' "$run_dir/current.json")"
    after_hash="$CURRENT_SCREEN_HASH"
    "$JQ" -cn --arg utc "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg before "$before_state" \
      --arg after "$after_state" --arg before_hash "$before_hash" --arg screenshot "$after_hash" \
      '{utc:$utc,state_before:$before,action:"COLLECT_REWARD_ORBS",state_after:$after,coordinate_space:"game",screenshot_before_sha256:$before_hash,screenshot_after_sha256:$screenshot,acknowledged:($before != $after or $before_hash != $screenshot)}' >> "$run_dir/actions.jsonl"
  }
  prepare_planning_stage() {
    local stage_key="$1" input_script="" xp_x xp_y
    [[ "${planning_prepared[$stage_key]:-0}" != "1" ]] || return 0
    # Use the bounded, reversible preparation that the established Trial
    # mechanics expect: collect visible reward orbs, spend only the current
    # four-gold XP control, then offer the normal Fight point. Disabled taps
    # are ignored by TFT; no shop slot or unit identity is guessed.
    reward_sweep battle || return 1
    xp_x="$(game_scale_x 80)"
    xp_y="$(game_scale_y 1060)"
    input_script="input tap $xp_x $xp_y; input tap $xp_x $xp_y; input tap $xp_x $xp_y; input tap $xp_x $xp_y;"
    "$ADB" -P "$ADB_PORT" -s "$SERIAL" shell "$input_script" >/dev/null
    planning_prepared[$stage_key]=1
    event "PLANNING_PREPARE" "stage=$stage_key reward_sweep=1 xp_taps=4"
    sleep 1
  }
  invoke_saved_login() {
    # The native DEV runtime owns current-route saved sign-in. The former
    # shell helper targets the retired PBE/5582 route and must never be called
    # from this 18.3 StockShadow campaign. Keep the semantic state machine
    # waiting for the native runtime to transition the official form; if Riot
    # or Google requires an external challenge, the classifier/authority gate
    # will pause the run without guessing or sending credentials elsewhere.
    event "SAVED_LOGIN_DELEGATED_TO_NATIVE_RUNTIME" \
      "package=$PACKAGE serial=$SERIAL credential_source=DEV_LocalCredentialFile"
    return 0
  }
  integer nav_started="$SECONDS"
  integer nav_timeout_seconds=$(( FULL_MATCH == 1 ? 3600 : 1200 ))
  while (( SECONDS - nav_started < nav_timeout_seconds )); do
    snapshot || { print -u2 "classifier or screenshot failed"; return 3; }
    local state="$("$JQ" -r '.state // "unknown"' "$run_dir/current.json")"
    local reason="$("$JQ" -r '.reason // ""' "$run_dir/current.json")"
    local stage="$("$JQ" -r '.stage // ""' "$run_dir/current.json")"
    local phase="$("$JQ" -r '.phase // ""' "$run_dir/current.json")"
    local stage_key="${stage:-unknown-battle}"
    if [[ -n "$stage" && "$stage" != "$LAST_ACTION_STAGE" ]]; then
      action_counts=()
      trial_choice_serial=0
      LAST_ACTION_STAGE="$stage"
    fi
    # Once the semantic gate has confirmed 1-1 combat, the scored interval is
    # wall-clock bounded. Evaluate completion before state dispatch so a
    # transient classifier gap cannot strand an otherwise complete capture.
    if (( FULL_MATCH == 0 && measurement_started > 0 && SECONDS - measurement_started >= MEASURE_SECONDS )); then
      measurement_valid=1
      WORKLOAD_END_NS="$($PYTHON3 -c 'import time; print(time.monotonic_ns())')"
      event "WORKLOAD_END" "five-minute confirmed combat interval"
      break
    fi
    case "$state" in
      login)
        if [[ "$reason" == "sign_in_splash" ]]; then action login SIGN_IN 1280 875 || return 3
        else invoke_saved_login || return 3; fi
        ;;
      lobby) action lobby PLAY 2220 1300 || return 3 ;;
      mode_select) action mode_select TOCKERS_TRIALS 1475 1000 || return 3 ;;
      trials_lobby)
        LAST_ACTION_STAGE=""
        LAST_PHASE=""
        action_counts=()
        trial_choice_serial=0
        action trials_lobby START 2220 1300 || return 3
        ;;
      match_found) action match_found ACCEPT 1280 960 || return 3 ;;
      trial_choice)
        [[ -n "$stage" ]] || { print -u2 "trial choice had no stage"; return 3; }
        if [[ "$reason" == "trial_option_choice" ]]; then trial_choice_action "$state" TRIAL_OPTION_CHOICE || return 3
        else action "$state" TRIAL_REWARD_CHOICE 1200 150 || return 3; fi
        ;;
      settings)
        [[ "$resetting_stale" == "1" ]] || { print -u2 "settings appeared outside stale-trial reset"; return 3; }
        action settings SURRENDER -237 318 center || return 3
        ;;
      surrender_confirm)
        [[ "$resetting_stale" == "1" ]] || { print -u2 "surrender confirmation appeared outside stale-trial reset"; return 3; }
        action surrender_confirm CONFIRM_SURRENDER 129 102 center || return 3
        ;;
      trial_results)
        if (( FULL_MATCH == 1 && measurement_started > 0 )); then
          measurement_valid=1
          WORKLOAD_END_NS="$($PYTHON3 -c 'import time; print(time.monotonic_ns())')"
          event "WORKLOAD_END" "full Tocker's Trial reached results"
          break
        fi
        [[ "$resetting_stale" == "1" ]] || { print -u2 "trial results appeared before a valid workload"; return 3; }
        LAST_ACTION_STAGE=""
        LAST_PHASE=""
        action_counts=()
        trial_choice_serial=0
        action trial_results PLAY_AGAIN 2200 1320 || return 3
        ;;
      battle)
        unknown_since=0
        local shop_open="$("$JQ" -r 'if .shop_open then "1" else "0" end' "$run_dir/current.json")"
        local fight_visible="$("$JQ" -r 'if .fight_button_visible then "1" else "0" end' "$run_dir/current.json")"
        # A transient OCR frame can preserve the battle HUD while dropping
        # the stage label. Do not reuse the prior stage or spend bounded shop
        # actions on that frame; wait for a fresh stage-confirmed observation.
        # The first fresh Trial battle is a contract-bound exception: the
        # accepted-match action starts a new Trial and the first semantic
        # planning HUD is necessarily 1-1. Record that evidence explicitly so
        # a clipped top label cannot strand the run.
        if [[ -z "$stage" ]]; then
          if (( measurement_started == 0 )) && [[ -z "$LAST_ACTION_STAGE" && "$phase" == "planning" && "$shop_open" == "1" && "$reason" == "battle_hud_without_stage" ]]; then
            stage="1-1"
            stage_key="1-1"
            event "STAGE_CONFIRMED_FROM_FRESH_TRIAL" "state=battle phase=planning shop_open=1 prior_stage=none"
          elif [[ -n "$LAST_ACTION_STAGE" && "$phase" == "planning" && ( "$shop_open" == "1" || "$fight_visible" == "1" ) ]]; then
            # Vision can lose only the clipped round glyph while the planning
            # controls remain explicit.  Carry the last confirmed stage for
            # this bounded planning transition and reset per-stage actions
            # once when combat has ended; never carry through an unknown or
            # disconnected screen.
            stage="$LAST_ACTION_STAGE"
            stage_key="$LAST_ACTION_STAGE"
            [[ "$LAST_PHASE" == "planning" ]] || action_counts=()
            event "STAGE_CARRY_FORWARD" "stage=$stage phase=planning controls=semantic"
          else
            sleep "$SCREEN_POLL_INTERVAL_SEC"
            continue
          fi
        fi
        LAST_PHASE="$phase"
        if (( measurement_started == 0 )) && [[ -n "$stage" && "$stage" != "1-1" ]]; then
          if (( resetting_stale == 0 )); then
            action battle OPEN_SETTINGS 0 0 back || return 3
            resetting_stale=1
            continue
          fi
        elif [[ "$stage" == "1-1" && "$resetting_stale" == "1" ]]; then
          resetting_stale=0
          event "FRESH_TRIAL_CONFIRMED" "stage=1-1 after stale-trial reset"
        fi
        # Tocker's Trial exposes a semantic planning HUD before each combat.
        # On some rounds the only recognized planning control is the shop
        # strip.  Use one bounded card selection followed by one shop-close
        # action, then wait for the semantic Fight control; never act on an
        # unknown screen or a timeout.
        if [[ "$stage" == "1-1" && "$phase" == "planning" && "$shop_open" == "1" ]]; then
          action battle CLOSE_SHOP 1965 1080 game || return 3
          continue
        fi
        if [[ "$phase" == "planning" && "$shop_open" == "1" && "$fight_visible" == "0" ]]; then
          # The shop strip is part of the normal planning HUD, not a modal
          # that must be dismissed. After a Trial choice the game may expose
          # it while the next fight is being prepared. One bounded tap at the
          # documented outside-shop point can dismiss a delayed shop animation;
          # after that, wait for the semantic Fight/combat transition instead
          # of guessing at reward or buy coordinates.
          if [[ "${shop_close_attempted[$stage_key]:-0}" != "1" ]]; then
            action battle CLOSE_SHOP 1965 1080 game || return 3
            shop_close_attempted[$stage_key]=1
          elif [[ "${planning_prepared[$stage_key]:-0}" != "1" ]]; then
            prepare_planning_stage "$stage_key" || return 3
          else
            event "PLANNING_WAIT_FOR_FIGHT" "stage=$stage_key shop_open=1 fight_visible=0"
            sleep "$SCREEN_POLL_INTERVAL_SEC"
          fi
          continue
        fi
        if [[ "$phase" == "planning" && "$fight_visible" == "1" ]]; then
          action battle FIGHT 1965 920 game || return 3
          continue
        fi
        if (( measurement_started == 0 )) && [[ "$stage" == "1-1" && "$phase" == "combat" ]]; then
          measurement_started="$SECONDS"
          WORKLOAD_START_NS="$($PYTHON3 -c 'import time; print(time.monotonic_ns())')"
          event "WORKLOAD_START" "confirmed battle 1-1 combat"
          if (( FULL_MATCH == 1 )); then
            print "TOCKERS_TRIAL_WORKLOAD_START: confirmed 1-1 combat; measuring full Trial"
          else
            print "TOCKERS_TRIAL_WORKLOAD_START: confirmed 1-1 combat; measuring 300s"
          fi
        fi
        ;;
      trial_ended)
        print -u2 "Trial ended before the five-minute workload"; return 3
        ;;
      unknown)
        (( unknown_since == 0 )) && unknown_since="$SECONDS"
        if (( SECONDS - unknown_since > 120 )); then
          print -u2 "unknown screen persisted; pausing without guessing"; return 3
        fi
        ;;
      disconnected)
        if (( measurement_started > 0 && reconnect_attempts < 3 )); then
          reconnect_attempts=$(( reconnect_attempts + 1 ))
          event "RECONNECT_ATTEMPT" "attempt=$reconnect_attempts state=disconnected"
          action disconnected RECONNECT 1280 720 game || return 3
          sleep 3
          continue
        fi
        print -u2 "disconnected state did not recover after bounded reconnect attempts"; return 3
        ;;
      error)
        if (( measurement_started == 0 )) && [[ "$reason" == "error_reject_marker" && "$ready_retry_count" -lt 2 ]]; then
          ready_retry_count=$(( ready_retry_count + 1 ))
          event "READY_CHECK_RECOVERY" "attempt=$ready_retry_count reason=$reason"
          # This is the exact acknowledgement button for Riot's explicit
          # ready-check decline modal.  Dismiss it, then re-enter the Trial
          # flow; do not treat a generic error as recoverable.
          action error DISMISS_READY_DECLINE 1280 800 display || return 3
          continue
        fi
        print -u2 "external or error state $state; pausing without guessing"; return 3
        ;;
      login_service_error)
        print -u2 "external or error state $state; pausing without guessing"; return 3
        ;;
      *) ;;
    esac
    if (( measurement_started > 0 )); then
      sleep "$SCREEN_POLL_INTERVAL_SEC"
    else
      sleep 1
    fi
  done
  (( measurement_valid == 1 )) || { print -u2 "$([[ "$FULL_MATCH" == 1 ]] && print 'full-match' || print 'five-minute') semantic workload was not completed"; return 3; }
  if (( FULL_MATCH == 1 )); then
    print "TOCKER_WORKLOAD_VALID: full Trial interval complete"
  else
    print "TOCKER_WORKLOAD_VALID: five-minute interval complete"
  fi
  /usr/bin/osascript -e 'tell application id "com.flashls1.tftmac.dev" to quit' >/dev/null 2>&1 || true
  integer stopped_wait=0
  until ! active_runtime; do
    (( stopped_wait += 1 ))
    (( stopped_wait < 120 )) || { print -u2 "runtime did not stop cleanly"; return 4; }
    sleep 1
  done
  local sealed_capture=""
  for manifest in "$CAPTURE_DIR_ROOT"/*/capture-manifest.json; do
    [[ -f "$manifest" && "$manifest" -nt "$run_dir/launch-start" ]] || continue
    sealed_capture="$(dirname "$manifest")"
  done
  [[ -n "$sealed_capture" ]] || { print -u2 "capture did not seal"; return 4; }
  [[ -n "$WORKLOAD_START_NS" && -n "$WORKLOAD_END_NS" ]] || { print -u2 "workload monotonic interval was not recorded"; return 4; }
  "$ROOT/scripts/analyze-flight-recorder.command" --format json --output "$run_dir/analyzer.json" "$sealed_capture" || return 4
  "$PYTHON3" "$WORKLOAD_ANALYZER" "$sealed_capture/TFTMAC_NATIVE_RUNTIME.sqlite" "$WORKLOAD_START_NS" "$WORKLOAD_END_NS" > "$run_dir/workload-metrics.json" || return 4
  local workload_metrics_json="$(cat "$run_dir/workload-metrics.json")"
  "$JQ" -e '.status == "AVAILABLE" and .frameWindows > 0' "$run_dir/workload-metrics.json" >/dev/null || { print -u2 "workload interval has no available frame windows"; return 4; }
  local session_metrics_json="$("$JQ" -c '.captures[0] | {
    averageFPS:.frame_metrics.fps.avg,
    medianFPS:.frame_metrics.fps.p50,
    p95FPS:.frame_metrics.fps.p95,
    p99FrameIntervalMs:.frame_metrics.p99_interval_ms.p99,
    jankyFrames:.frame_metrics.jank.avg,
    severeStalls:.frame_metrics.severe.avg,
    audioUnderruns:.audio_metrics.underrun_samples,
    inputLatencyP95Ms:.input_metrics.first_present_after_input_ms.p95,
    memorySwapUsedKiB:.resource_metrics.host_swap_used_kib.max,
    decision:.decision
  }' "$run_dir/analyzer.json")"
  # The full analyzer covers the complete launch session. The Trial interval
  # is the scored workload, so frame and tail fields must come from the
  # bounded workload analyzer rather than startup/teardown windows outside
  # the confirmed match. Whole-session audio/input fields remain health data.
  local metrics_json="$("$JQ" -c --argjson workload "$workload_metrics_json" '
    .captures[0] as $capture | {
      averageFPS:$workload.averageFPS,
      medianFPS:$workload.medianFPS,
      p95FPS:$workload.p95FPS,
      p99FrameIntervalMs:$workload.medianP99FrameIntervalMs,
      medianP95FrameIntervalMs:$workload.medianP95FrameIntervalMs,
      medianP99FrameIntervalMs:$workload.medianP99FrameIntervalMs,
      jankyFrames:$workload.jankyFrameRatePercent,
      severeStalls:$workload.severeStallsPerWindow,
      missedVsyncPerWindow:$workload.missedVsyncPerWindow,
      frameWindows:$workload.frameWindows,
      audioUnderruns:$capture.audio_metrics.underrun_samples,
      inputLatencyP95Ms:$capture.input_metrics.first_present_after_input_ms.p95,
      memorySwapUsedKiB:$workload.hostSwapUsedKiBMax,
      decision:$workload.bottleneckEvidence.rootOutcome
    }' "$run_dir/analyzer.json")"
  local workload_seconds="$($PYTHON3 -c 'import sys; print(round((int(sys.argv[2])-int(sys.argv[1]))/1_000_000_000,3))' "$WORKLOAD_START_NS" "$WORKLOAD_END_NS")"
  local workload_name="$([[ "$FULL_MATCH" == 1 ]] && print TOCKERS_TRIAL_FULL_MATCH || print TOCKERS_TRIAL)"
  "$JQ" -n --arg run "$run_id" --arg candidate "$CURRENT_CANDIDATE_ID" --arg capture "$sealed_capture" \
    --arg package "$PACKAGE" --arg version "$VERSION_NAME" --arg installer "$INSTALLER" \
    --arg route "UNREAL_OPENGL_ES_THROUGH_ANGLE" --arg display "$CURRENT_DISPLAY" --arg vcpu "$CURRENT_VCPU" --arg ram "$CURRENT_RAM" \
    --arg observed_display "$observed_size" --arg observed_density "$observed_density" --arg observed_vcpu "$observed_vcpu" --arg observed_ram "$observed_ram" \
    --argjson metrics "$metrics_json" --argjson sessionMetrics "$session_metrics_json" --argjson workloadMetrics "$workload_metrics_json" --argjson seconds "$workload_seconds" \
    --arg workload_name "$workload_name" --arg full_match "$FULL_MATCH" \
    --arg start_ns "$WORKLOAD_START_NS" --arg end_ns "$WORKLOAD_END_NS" --arg poll "$SCREEN_POLL_INTERVAL_SEC" \
    '{schemaVersion:1,runId:$run,candidateId:$candidate,valid:true,status:"VALID_SEALED_FULL_MATCH",authority:{package:$package,versionName:$version,installer:$installer,route:$route},requested:{display:$display,density:416,vcpu:($vcpu|tonumber),ramMiB:($ram|tonumber)},observed:{display:$observed_display,density:$observed_density,vcpu:($observed_vcpu|tonumber),ramMiB:($observed_ram|tonumber)},observer:{classifierPollIntervalSec:($poll|tonumber)},workload:{name:$workload_name,fullMatch:($full_match == "1"),confirmedStage:"1-1",durationSeconds:$seconds,startMonotonicNs:($start_ns|tonumber),endMonotonicNs:($end_ns|tonumber)},metrics:$metrics,sessionMetrics:$sessionMetrics,workloadMetrics:$workloadMetrics,capture:{root:$capture,seal:"SEALED",analysis:"COMPLETE"},decision:"BASELINE_VALID"}' \
    > "$run_dir/receipt.json"
  mkdir -p "$SSOT/receipts/tocker-campaign"
  cp -p "$run_dir/receipt.json" "$SSOT/receipts/tocker-campaign/$run_id.json"
  stop_adb_server
  checkpoint_write "$(checkpoint_read | "$JQ" --arg run "$run_id" --arg candidate "$CURRENT_CANDIDATE_ID" --arg receipt "$run_dir/receipt.json" '.status="RUNNING" | .attempts=(.attempts+1) | .runs += [{runId:$run,candidateId:$candidate,receipt:$receipt,valid:true}]')"
  event "RUN_SEALED" "$run_id $CURRENT_CANDIDATE_ID baseline_valid"
  return 0
}

validate_manifest
case "$MODE" in
  self-test) self_test; exit 0 ;;
  dry-run)
    self_test; write_dry_receipt control-1440p; print "DRY_RUN_PASS candidate=control-1440p capture=not_started"; exit 0 ;;
  stop) stop_campaign; exit 0 ;;
esac
(( MAX_RUNS <= 24 )) || die "campaign budget is 24 launches"
acquire_lock
preflight
local_cp="$(checkpoint_read)"
if (( RESUME == 0 )); then
  checkpoint_write '{"schemaVersion":1,"status":"RUNNING","attempts":0,"nextCandidate":"control-1440p","runs":[]}'
else
  print -r -- "$local_cp" | "$JQ" -e '.schemaVersion == 1' >/dev/null || die "cannot resume invalid checkpoint"
fi
event "CAMPAIGN_START" "max_runs=$MAX_RUNS"
integer campaign_rc=0
while :; do
  local_cp="$(checkpoint_read)"
  integer attempts="$("$JQ" -r '.attempts // 0' <<< "$local_cp")"
  (( attempts < MAX_RUNS && attempts < 24 )) || break
  local next_candidate="$("$JQ" -r '.nextCandidate // "control-1440p"' <<< "$local_cp")"
  local candidate_spec="$(candidate_json "$next_candidate")"
  [[ -n "$candidate_spec" ]] || die "checkpoint points at an unknown candidate: $next_candidate"
  if ! candidate_supported "$candidate_spec"; then
    local reason="candidate_not_admitted_by_current_evidence"
    if [[ "$next_candidate" == "vcpu-10" && -f "$VCPU10_CAPABILITY_RECEIPT" ]]; then
      reason="VCPU10_UNSUPPORTED_BY_STOCKSHADOW_QEMU_MAX_8"
    fi
    checkpoint_write "$(print -r -- "$local_cp" | "$JQ" --arg reason "$reason" '.status="QUEUE_EXHAUSTED" | .pauseReason=$reason')"
    event "CAMPAIGN_PAUSED" "$next_candidate not admitted by evidence gate"
    print "CAMPAIGN_PAUSED: $next_candidate is not runnable on the current sealed runtime ($reason)."
    exit 3
  fi
  load_candidate "$next_candidate"
  if run_control_smoke; then
    local_cp="$(checkpoint_read)"
    integer candidate_runs="$("$JQ" --arg candidate "$CURRENT_CANDIDATE_ID" '[.runs[] | select(.candidateId==$candidate and .valid==true)] | length' <<< "$local_cp")"
    if (( candidate_runs >= CURRENT_RUNS_REQUIRED )); then
      local next_after=""
      if [[ "$CURRENT_CANDIDATE_ID" == "control-1440p" ]]; then next_after="guest-1080p"
      elif [[ "$CURRENT_CANDIDATE_ID" == "guest-1080p" ]]; then next_after="program-lru-20"
      elif [[ "$CURRENT_CANDIDATE_ID" == "program-lru-20" ]]; then next_after="defer-texture-1"
      elif [[ "$CURRENT_CANDIDATE_ID" == "defer-texture-1" || "$CURRENT_CANDIDATE_ID" == "pso-wait-all" || "$CURRENT_CANDIDATE_ID" == "pso-priority-escalate" ]]; then next_after="vcpu-10"
      else next_after="vcpu-10"; fi
      checkpoint_write "$(print -r -- "$local_cp" | "$JQ" --arg next "$next_after" '.nextCandidate=$next')"
      event "CONDITION_COMPLETE" "$CURRENT_CANDIDATE_ID valid_runs=$candidate_runs next=$next_after"
    fi
  else
    campaign_rc="$?"
    /usr/bin/osascript -e 'tell application id "com.flashls1.tftmac.dev" to quit' >/dev/null 2>&1 || true
    stop_adb_server
    checkpoint_write "$(checkpoint_read | "$JQ" --arg reason "run_failed_$campaign_rc" '.status="PAUSED" | .pauseReason=$reason')"
    event "CAMPAIGN_PAUSED" "$CURRENT_CANDIDATE_ID run_failed=$campaign_rc"
    exit "$campaign_rc"
  fi
done
local_cp="$(checkpoint_read)"
integer final_attempts="$("$JQ" -r '.attempts // 0' <<< "$local_cp")"
if (( final_attempts >= MAX_RUNS || final_attempts >= 24 )); then
  checkpoint_write "$(print -r -- "$local_cp" | "$JQ" '.status="BUDGET_EXHAUSTED"')"
  event "CAMPAIGN_STOPPED" "launch_budget_exhausted=$final_attempts"
  print "CAMPAIGN_STOPPED: launch budget exhausted at $final_attempts attempts."
else
  print "CAMPAIGN_WAITING: checkpoint preserved for --resume."
fi
