#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly PROJECT_DIR="${0:A:h:h}"
readonly LAUNCHER_DIR="$PROJECT_DIR/launcher"
readonly SPARKLE_ROOT="$("$PROJECT_DIR/scripts/prepare-sparkle.command")"
readonly TEST_BINARY="$(mktemp -t mactician-tests)"
readonly LIFECYCLE_ROOT="$(mktemp -d -t mactician-lifecycle)"
readonly HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
    arm64|x86_64) ;;
    *)
        print -u2 "Unsupported unit-test host architecture: $HOST_ARCH"
        exit 2
        ;;
esac
readonly TEST_TARGET="$HOST_ARCH-apple-macosx12.0"
cleanup() {
    local exit_code=$?
    rm -f "$TEST_BINARY"
    rm -rf "$LIFECYCLE_ROOT"
    return "$exit_code"
}
trap cleanup EXIT

jq -e '.schemaVersion == 1 and (.components | length) == 3 and (.game.apks | length) == 4' \
    "$LAUNCHER_DIR/Resources/release-manifest.json" >/dev/null
plutil -lint "$LAUNCHER_DIR/Info.plist" >/dev/null
plutil -lint "$LAUNCHER_DIR/Resources/EmulatorHost-Info.plist" >/dev/null
plutil -lint "$LAUNCHER_DIR/Resources/QEMU-Hypervisor.entitlements" >/dev/null
plutil -lint "$LAUNCHER_DIR/Resources/en.lproj/Localizable.strings" >/dev/null
plutil -lint "$LAUNCHER_DIR/Resources/ru.lproj/Localizable.strings" >/dev/null
typeset -a launcher_localizations
launcher_localizations=("$LAUNCHER_DIR"/Resources/*.lproj(N:t))
if (( ${#launcher_localizations} != 2 )) \
        || [[ "$launcher_localizations[1]" != "en.lproj" ]] \
        || [[ "$launcher_localizations[2]" != "ru.lproj" ]]; then
    print -u2 "Mactician must ship the English and Russian localization resources."
    exit 1
fi
typeset syntax_script
for syntax_script in \
        "$LAUNCHER_DIR/Resources/launcher-runtime.command" \
        "$LAUNCHER_DIR/Resources/emulator-host.command" \
        "$PROJECT_DIR/run-tft-root-affinity.command" \
        "$PROJECT_DIR/run-tft-angle-opengl.command" \
        "$PROJECT_DIR/scripts/run-asg-experiment.command" \
        "$PROJECT_DIR/scripts/run-autonomous-trial-benchmark.command" \
        "$PROJECT_DIR/scripts/run-performance-campaign.command" \
        "$PROJECT_DIR/scripts/run-android-ui-transport-probe.command" \
        "$PROJECT_DIR/scripts/run-host-angle-capability-probe.command" \
        "$PROJECT_DIR/scripts/summarize-android-ui-transport.command" \
        "$PROJECT_DIR/scripts/audit-native-gles-coverage.command" \
        "$PROJECT_DIR/scripts/build-android-egl-capability-probe.command" \
        "$PROJECT_DIR/scripts/watch-root-pso.command" \
        "$PROJECT_DIR/scripts/android-environment.sh" \
        "$PROJECT_DIR/scripts/prepare-sparkle.command" \
        "$PROJECT_DIR/scripts/publish-mactician-update.command" \
        "$PROJECT_DIR/scripts/publish-game-update.command" \
        "$PROJECT_DIR/scripts/build-mactician.command" \
        "$PROJECT_DIR/scripts/integration-test-mactician.command"; do
    zsh -o NO_BG_NICE -n "$syntax_script"
done

if rg -n '[А-Яа-яЁё]' \
        "$LAUNCHER_DIR/Resources/launcher-runtime.command" \
        "$LAUNCHER_DIR/Resources/emulator-host.command" \
        "$PROJECT_DIR/run-tft-root-affinity.command" \
        "$PROJECT_DIR/run-tft-angle-opengl.command" \
        "$PROJECT_DIR/scripts/run-asg-experiment.command" \
        "$PROJECT_DIR/scripts/watch-root-pso.command"; then
    print -u2 "Bundled launcher logs must be in English."
    exit 1
fi
xcrun clang \
    -target arm64-apple-macosx12.0 \
    -fsyntax-only \
    "$LAUNCHER_DIR/EmulatorHost/main.c"

# The current product is the native TFTMAC shell around the stock Play runtime.
# Build it during production validation so Swift/AppKit/window integration cannot drift.
/bin/zsh "$PROJECT_DIR/scripts/build-tftmac-app.command" >/dev/null

"$PROJECT_DIR/scripts/build-tft-screen-classifier.command" >/dev/null
"$PROJECT_DIR/runtime/tft-screen-classifier" --self-test >/dev/null

if ! grep -Fq -- '--options runtime' "$PROJECT_DIR/scripts/build-mactician.command" \
        || ! grep -Fq 'notarytool submit' "$PROJECT_DIR/scripts/build-mactician.command" \
        || ! grep -Fq 'stapler staple' "$PROJECT_DIR/scripts/build-mactician.command" \
        || ! grep -Fq 'Sparkle.framework' "$PROJECT_DIR/scripts/build-mactician.command"; then
    print -u2 "Public release signing and notarization workflow is incomplete."
    exit 1
fi

if ! grep -Fq 'MVK_CONFIG_SUPPORT_LARGE_QUERY_POOLS' \
        "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq 'MVK_CONFIG_USE_MTLHEAP' \
            "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq 'MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE' \
            "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq 'MVK_CONFIG_LOG_LEVEL' \
            "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq 'MVK_CONFIG_PERFORMANCE_LOGGING_FRAME_COUNT' \
            "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq 'MVK_CONFIG_PERFORMANCE_TRACKING' \
            "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! rg -Uq 'for environment_name in \\\n+[[:space:]]+ANGLE_FEATURE_OVERRIDES_ENABLED \\\n+[[:space:]]+ANGLE_FEATURE_OVERRIDES_DISABLED \\\n+[[:space:]]+MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS' \
        "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! rg -Uq 'MVK_CONFIG_FAST_MATH_ENABLED \\\n+[[:space:]]+MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS \\\n+[[:space:]]+MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE; do' \
        "$PROJECT_DIR/run-tft-root-affinity.command"; then
    print -u2 "The Game Mode app wrapper must preserve experimental ANGLE and MoltenVK settings."
    exit 1
fi

if ! jq -e '
        def safe_relative_path:
          type == "string"
          and test("^[A-Za-z0-9._/-]+$")
          and (startswith("/") | not)
          and (contains("..") | not);
        .schemaVersion == 1
        and (.candidates | type == "array" and length > 0)
        and ([.candidates[].id] | length == (unique | length))
        and ([.candidates[].variant] | length == (unique | length))
        and all(.candidates[];
          (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$"))
          and (.launcher | safe_relative_path)
          and ((.profile // "placeholder") | safe_relative_path)
          and (.variant | type == "string" and test("^[a-z0-9][a-z0-9_-]*$"))
          and (.display | type == "string"
            and test("^(2560x1440|2880x1620|3200x1800|3840x2160)$"))
          and (.density | type == "number" and floor == . and . >= 120 and . <= 640)
          and (.stages | type == "array" and length > 0
            and all(.[]; type == "string" and test("^[1-9]-(1[0-9]|[1-9])$")))
          and ((.profileStage // "1-1")
            | type == "string" and test("^[1-9]-(1[0-9]|[1-9])$"))
          and ((.minimumTrialSeconds // 0)
            | type == "number" and floor == . and . >= 0 and . <= 3600)
          and ((.env // {}) | type == "object"
            and all(to_entries[];
              (.key | test("^[A-Z][A-Z0-9_]*$"))
              and (.value | type == "string"
                and test("^[-A-Za-z0-9_./:]+$")))))
    ' "$PROJECT_DIR/scripts/performance-candidates.json" >/dev/null; then
    print -u2 "The performance candidate manifest contract is invalid."
    exit 1
fi
typeset candidate_launcher candidate_profile
while IFS=$'\t' read -r candidate_launcher candidate_profile; do
    if [[ ! -x "$PROJECT_DIR/$candidate_launcher" \
            || ( -n "$candidate_profile" && ! -f "$PROJECT_DIR/$candidate_profile" ) ]]; then
        print -u2 "A performance candidate references a missing launcher or profile: $candidate_launcher ${candidate_profile:-<none>}"
        exit 1
    fi
done < <(jq -r '.candidates[] | [.launcher, (.profile // "")] | @tsv' \
    "$PROJECT_DIR/scripts/performance-candidates.json")

if ! grep -Fq 'osft-no-fence-contexts' "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq -- '-VirtioGpuFenceContexts' \
            "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! jq -e '
            [.candidates[].id] as $ids
            | ($ids | index("performance-max-no-fence-contexts-screen")) != null
              and ($ids | index("performance-max-no-virtual-queue-screen")) == null
              and ($ids | index("performance-max-no-queue-submit-with-commands-screen")) == null
              and ($ids | index("performance-max-argument-buffers-off-screen")) == null
              and ($ids | index("performance-max-single-queue-semaphores-screen")) == null
        ' "$PROJECT_DIR/scripts/performance-candidates.json" >/dev/null; then
    print -u2 "The rejected/no-op performance candidate isolation is incomplete."
    exit 1
fi

if ! grep -Fq 'readonly HOST_GPU="${TFT_HOST_GPU:-host}"' \
        "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq -- '-gpu "$HOST_GPU"' \
        "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq 'TFT_HOST_GPU must be either host or swangle.' \
        "$PROJECT_DIR/run-tft-root-affinity.command" \
        || ! grep -Fq 'host ANGLE -> Vulkan -> SwiftShader CPU' \
        "$PROJECT_DIR/run-tft-root-affinity.command"; then
    print -u2 "The bounded host swangle GLES control is incomplete."
    exit 1
fi

if ! jq -e '
        .schemaVersion == 1
        and (.runs | length) == 10
        and (.aggregates | length) == 5
        and ([.runs[].label] | unique | length) == 10
        and ([.runs[].summarySha256] | unique | length) == 10
        and all(.runs[]; .summarySha256 | test("^[0-9a-f]{64}$"))
        and ([.runs[].graphicsProfile] | unique | length) == 5
        and (.invariants.display == "2560x1440")
        and (.invariants.displayDensityDpi == 320)
        and (.invariants.transport == "virtio-gpu-asg")
        and (.invariants.hwuiRenderer == "skiavk")
        and (.invariants.roundsPerRun == 12)
        and (.invariants.warmupRoundsDiscarded == 3)
        and ([.aggregates[] | select(.graphicsProfile == "osft")][0].warmRounds == 36)
        and ([.aggregates[] | select(.decision == "keep")] | length) == 1
        and (. as $document
          | all($document.aggregates[];
              . as $aggregate
              | [$document.runs[]
                  | select(.graphicsProfile == $aggregate.graphicsProfile)] as $runs
              | ($runs | length) == $aggregate.validRuns
                and (($runs | length) * 9) == $aggregate.warmRounds
                and (((($runs | map(.warmMeanElapsedMs) | add) / ($runs | length))
                  - $aggregate.warmMeanElapsedMs) | fabs) < 0.000001
                and ($runs | map(.warmMaxP95Ms) | max) == $aggregate.warmMaxP95Ms
                and ($runs | map(.warmMaxP99Ms) | max) == $aggregate.warmMaxP99Ms
                and ($runs | map(.warmTotalJankyFrames) | add)
                  == $aggregate.warmTotalJankyFrames))
    ' "$PROJECT_DIR/artifacts/android-ui-transport-attested-20260811.json" \
        >/dev/null; then
    print -u2 "The attested Android UI transport result artifact is incomplete."
    exit 1
fi
typeset source_summary source_label source_utc source_expected_sha source_actual_sha
for source_summary in \
        "$PROJECT_DIR"/runtime/measurements/android-ui-transport/*/summary.json(N); do
    source_label="$(jq -r '.label // ""' "$source_summary")"
    source_utc="$(jq -r '.utc // ""' "$source_summary")"
    source_expected_sha="$(
        jq -r \
            --arg target_label "$source_label" \
            --arg target_utc "$source_utc" \
            '.runs[]
              | select(.label == $target_label and .utc == $target_utc)
              | .summarySha256' \
            "$PROJECT_DIR/artifacts/android-ui-transport-attested-20260811.json"
    )"
    [[ -n "$source_expected_sha" ]] || continue
    source_actual_sha="$(shasum -a 256 "$source_summary" | awk '{ print $1 }')"
    if [[ "$source_actual_sha" != "$source_expected_sha" ]]; then
        print -u2 "An attested Android UI source summary no longer matches its recorded SHA: $source_label"
        exit 1
    fi
done

xcrun clang++ \
    -std=c++17 \
    -Wall \
    -Wextra \
    -Werror \
    -fsyntax-only \
    "$PROJECT_DIR/artifacts/angle-egl-probe.cpp"

if ! grep -Fq 'functional_es32_geometry_pipeline' \
        "$PROJECT_DIR/artifacts/angle-egl-probe.cpp" \
        || ! grep -Fq 'functional_es32_tessellation_pipeline' \
            "$PROJECT_DIR/artifacts/angle-egl-probe.cpp" \
        || ! grep -Fq 'exposeNonConformantExtensionsAndVersions' \
            "$PROJECT_DIR/scripts/run-host-angle-capability-probe.command" \
        || ! grep -Fq 'ANDROID_EMU_gles_max_version_3_2' \
            "$PROJECT_DIR/artifacts/gfxstream-gles32-host-capability-prototype.patch" \
        || ! grep -Fq 'kGles32Aliases' \
            "$PROJECT_DIR/artifacts/gfxstream-gles32-guest-proc-alias-prototype.patch" \
        || ! grep -Fq '{"glTexBuffer", (void*)_egl_glTexBufferEXT}' \
            "$PROJECT_DIR/artifacts/gfxstream-gles32-guest-proc-alias-prototype.patch" \
        || ! grep -Fq 'dynamic_alias_resolution_required' \
            "$PROJECT_DIR/scripts/audit-native-gles-coverage.command" \
        || ! grep -Fq 'runtime.LockOSThread()' \
            "$PROJECT_DIR/artifacts/android-egl-capability-probe/main.go" \
        || ! grep -Fq 'runtime.KeepAlive(highAttrs)' \
            "$PROJECT_DIR/artifacts/android-egl-capability-probe/main.go" \
        || ! grep -Fq 'hwui_renderer: $hwui_renderer' \
            "$PROJECT_DIR/scripts/run-android-ui-transport-probe.command" \
        || ! grep -Fq 'display_density: $display_density' \
            "$PROJECT_DIR/scripts/run-android-ui-transport-probe.command" \
        || ! grep -Fq 'ro.boot.mactician.graphics_profile' \
            "$PROJECT_DIR/scripts/run-android-ui-transport-probe.command" \
        || ! grep -Fq "grep -Fqx 'Status: ok'" \
            "$PROJECT_DIR/scripts/run-android-ui-transport-probe.command" \
        || ! grep -Fq 'write_rejected_summary "non_rendering_round_$round"' \
            "$PROJECT_DIR/scripts/run-android-ui-transport-probe.command" \
        || ! grep -Fq 'existing evidence will not be overwritten' \
            "$PROJECT_DIR/scripts/run-android-ui-transport-probe.command" \
        || ! grep -Fq 'androidboot.mactician.graphics_profile=$GRAPHICS_PROFILE' \
            "$PROJECT_DIR/run-tft-root-affinity.command"; then
    print -u2 "The native GLES capability experiment artifacts are incomplete."
    exit 1
fi
if [[ "$(grep -c '^proc ' \
        "$PROJECT_DIR/artifacts/android-egl-capability-probe/native-clean-boot-output.txt")" != "59" ]] \
        || [[ "$(grep -c '^proc .* false$' \
            "$PROJECT_DIR/artifacts/android-egl-capability-probe/native-clean-boot-output.txt")" != "3" ]]; then
    print -u2 "The recorded native guest proc-address matrix is incomplete."
    exit 1
fi

# The transport summarizer must retain short valid runs, reject empty and
# explicitly failed runs without dividing by zero, and keep display/renderer
# configurations separate.
if "$PROJECT_DIR/scripts/run-android-ui-transport-probe.command" \
        attestation-required 1 \
        >"$LIFECYCLE_ROOT/missing-profile-attestation.out" 2>&1 \
        || ! grep -Fq 'TFT_UI_TRANSPORT_EXPECTED_GRAPHICS_PROFILE is required' \
            "$LIFECYCLE_ROOT/missing-profile-attestation.out"; then
    print -u2 "The Android UI transport probe accepted an unattested graphics profile."
    exit 1
fi
readonly TRANSPORT_FIXTURE_ROOT="$LIFECYCLE_ROOT/android-ui-transport"
mkdir -p "$TRANSPORT_FIXTURE_ROOT/rejected" \
    "$TRANSPORT_FIXTURE_ROOT/empty" \
    "$TRANSPORT_FIXTURE_ROOT/short-osft" \
    "$TRANSPORT_FIXTURE_ROOT/short-stable" \
    "$TRANSPORT_FIXTURE_ROOT/short-skiagl" \
    "$TRANSPORT_FIXTURE_ROOT/short-density"
jq -n '{schema_version: 5, label: "edge-rejected-A", graphics_profile: "osft",
    display: "2560x1440", display_density: 320,
    transport: "virtio-gpu-asg", hwui_renderer: "skiavk",
    rejected_reason: "fixture_failure",
    swipe_pairs: 15,
    minimum_frames_per_round: 120,
    rounds: [range(1; 5) | {round: ., elapsed_ns: 6000000000,
      total_frames: 120, janky_frames: 0, p95_ms: 0, p99_ms: 0}]}' \
    > "$TRANSPORT_FIXTURE_ROOT/rejected/summary.json"
jq -n '{schema_version: 5, label: "edge-rejected-Z", graphics_profile: "osft",
    display: "2560x1440", display_density: 320,
    transport: "virtio-gpu-asg", hwui_renderer: "skiavk",
    swipe_pairs: 15, minimum_frames_per_round: 120, rounds: []}' \
    > "$TRANSPORT_FIXTURE_ROOT/empty/summary.json"
jq -n '{schema_version: 5, label: "edge-short-B", graphics_profile: "osft",
    display: "2560x1440", display_density: 320,
    transport: "virtio-gpu-asg", hwui_renderer: "skiavk",
    swipe_pairs: 15,
    minimum_frames_per_round: 120,
    rounds: [
      {round: 1, elapsed_ns: 6000000000, total_frames: 120,
       janky_frames: 1, p95_ms: 10, p99_ms: 12},
      {round: 2, elapsed_ns: 6200000000, total_frames: 121,
       janky_frames: 2, p95_ms: 11, p99_ms: 13},
      {round: 3, elapsed_ns: 6400000000, total_frames: 122,
       janky_frames: 3, p95_ms: 12, p99_ms: 14}]}' \
    > "$TRANSPORT_FIXTURE_ROOT/short-osft/summary.json"
jq -n '{schema_version: 5, label: "edge-short-C", graphics_profile: "stable",
    display: "2560x1440", display_density: 320,
    transport: "virtio-gpu-asg", hwui_renderer: "skiavk",
    swipe_pairs: 15, minimum_frames_per_round: 120,
    rounds: [
      {round: 1, elapsed_ns: 7000000000, total_frames: 120,
       janky_frames: 0, p95_ms: 9, p99_ms: 11}]}' \
    > "$TRANSPORT_FIXTURE_ROOT/short-stable/summary.json"
jq -n '{schema_version: 5, label: "edge-short-D", graphics_profile: "osft",
    display: "2560x1440", display_density: 320,
    transport: "virtio-gpu-asg", hwui_renderer: "skiagl",
    swipe_pairs: 15, minimum_frames_per_round: 120,
    rounds: [
      {round: 1, elapsed_ns: 7100000000, total_frames: 120,
       janky_frames: 4, p95_ms: 13, p99_ms: 15}]}' \
    > "$TRANSPORT_FIXTURE_ROOT/short-skiagl/summary.json"
jq -n '{schema_version: 5, label: "edge-short-E", graphics_profile: "osft",
    display: "2560x1440", display_density: 416,
    transport: "virtio-gpu-asg", hwui_renderer: "skiavk",
    swipe_pairs: 15, minimum_frames_per_round: 120,
    rounds: [
      {round: 1, elapsed_ns: 7200000000, total_frames: 120,
       janky_frames: 5, p95_ms: 14, p99_ms: 16}]}' \
    > "$TRANSPORT_FIXTURE_ROOT/short-density/summary.json"
TFT_UI_TRANSPORT_ROOT="$TRANSPORT_FIXTURE_ROOT" \
    "$PROJECT_DIR/scripts/summarize-android-ui-transport.command" \
    '^edge-(rejected|short)-[A-Z]$' \
    > "$TRANSPORT_FIXTURE_ROOT/result.json"
if ! jq -e '
    length == 5
    and .[0].group == "edge-rejected"
    and .[0].graphics_profile == "osft"
    and .[0].display_density == 320
    and .[0].hwui_renderer == "skiavk"
    and .[0].valid_runs == 0
    and .[0].rejected_runs == 2
    and .[0].warm_rounds == 0
    and .[0].warm_mean_elapsed_ms == null
    and .[0].warm_total_janky_frames == null
    and .[1].group == "edge-short"
    and .[1].graphics_profile == "osft"
    and .[1].display == "2560x1440"
    and .[1].display_density == 320
    and .[1].transport == "virtio-gpu-asg"
    and .[1].hwui_renderer == "skiagl"
    and .[1].valid_runs == 1
    and .[1].rejected_runs == 0
    and .[1].warm_rounds == 1
    and .[1].warm_mean_elapsed_ms == 7100
    and .[1].warm_max_p95_ms == 13
    and .[1].warm_max_p99_ms == 15
    and .[1].warm_total_janky_frames == 4
    and .[2].group == "edge-short"
    and .[2].graphics_profile == "osft"
    and .[2].display_density == 320
    and .[2].hwui_renderer == "skiavk"
    and .[2].valid_runs == 1
    and .[2].rejected_runs == 0
    and .[2].warm_rounds == 3
    and .[2].warm_mean_elapsed_ms == 6200
    and .[2].warm_median_elapsed_ms == 6200
    and .[2].warm_max_p95_ms == 12
    and .[2].warm_max_p99_ms == 14
    and .[2].warm_total_janky_frames == 6
    and .[3].group == "edge-short"
    and .[3].graphics_profile == "osft"
    and .[3].display_density == 416
    and .[3].hwui_renderer == "skiavk"
    and .[3].valid_runs == 1
    and .[3].warm_rounds == 1
    and .[3].warm_mean_elapsed_ms == 7200
    and .[3].warm_max_p95_ms == 14
    and .[3].warm_max_p99_ms == 16
    and .[4].group == "edge-short"
    and .[4].graphics_profile == "stable"
    and .[4].display_density == 320
    and .[4].hwui_renderer == "skiavk"
    and .[4].valid_runs == 1
    and .[4].warm_rounds == 1
    and .[4].warm_mean_elapsed_ms == 7000
    and .[4].warm_max_p95_ms == 9
    and .[4].warm_max_p99_ms == 11
' "$TRANSPORT_FIXTURE_ROOT/result.json" >/dev/null; then
    print -u2 "Android UI transport summary edge cases regressed."
    cat "$TRANSPORT_FIXTURE_ROOT/result.json" >&2
    exit 1
fi

if ! grep -Fq -- '--allow-adhoc' "$PROJECT_DIR/scripts/publish-mactician-update.command" \
        || ! grep -Fq 'Signature=adhoc' "$PROJECT_DIR/scripts/publish-mactician-update.command" \
        || ! grep -Fq 'hdiutil verify' "$PROJECT_DIR/scripts/publish-mactician-update.command"; then
    print -u2 "Ad-hoc publication safeguards are incomplete."
    exit 1
fi

if ! grep -Fq 'field__input--animate' \
        "$LAUNCHER_DIR/Sources/RiotLoginAnimationRepairService.swift" \
        || ! grep -Fq 'animation: none !important' \
        "$LAUNCHER_DIR/Sources/RiotLoginAnimationRepairService.swift" \
        || ! grep -Fq 'remainingAnimations == 0' \
        "$LAUNCHER_DIR/Sources/RiotLoginAnimationRepairService.swift" \
        || rg -n 'shell input (tap|keyevent)|KEYCODE_TAB|becomeFirstResponder' \
        "$LAUNCHER_DIR/Sources/RiotLoginAnimationRepairService.swift"; then
    print -u2 "Scoped Riot login animation repair is incomplete or uses synthetic focus."
    exit 1
fi

# A user-requested STOP sends TERM while the runtime child is still alive.
# Reproduce that lifecycle with caffeinate as a harmless long-running child and
# verify that it produces a normal stopped event, not a Repair error.
mkdir -p "$LIFECYCLE_ROOT/runtime/scripts"
ln -s /usr/bin/caffeinate "$LIFECYCLE_ROOT/runtime/scripts/run-asg-experiment.command"
env \
    TFT_RUNTIME_PROJECT="$LIFECYCLE_ROOT/runtime" \
    TFT_LAUNCH_LOG="$LIFECYCLE_ROOT/runtime.log" \
    TFT_ADB=/usr/bin/false \
    TFT_AVD_HOME="$LIFECYCLE_ROOT/avd" \
    TFT_AVD_NAME=TftPBE \
    TFT_SERIAL=emulator-5582 \
    TFT_DISPLAY_SIZE=1920x1080 \
    TFT_DISPLAY_DENSITY=320 \
    TFT_GAME_LANGUAGE=en-US \
    TFT_CPU_CORES=6 \
    TFT_MEMORY_MB=6144 \
    TFT_UI_SCALE=1.0 \
    "$LAUNCHER_DIR/Resources/launcher-runtime.command" \
    >"$LIFECYCLE_ROOT/events.jsonl" &
readonly LIFECYCLE_PID=$!
typeset lifecycle_ready=0
for lifecycle_attempt in {1..100}; do
    if grep -q '"event":"booting"' "$LIFECYCLE_ROOT/events.jsonl" 2>/dev/null; then
        lifecycle_ready=1
        break
    fi
    if ! kill -0 "$LIFECYCLE_PID" >/dev/null 2>&1; then
        break
    fi
    sleep 0.05
done
if (( lifecycle_ready == 0 )); then
    print -u2 "Launcher runtime did not reach the booting state."
    cat "$LIFECYCLE_ROOT/events.jsonl" >&2 2>/dev/null || true
    exit 1
fi
kill -TERM "$LIFECYCLE_PID"
if wait "$LIFECYCLE_PID"; then
    readonly LIFECYCLE_STATUS=0
else
    readonly LIFECYCLE_STATUS=$?
fi
if (( LIFECYCLE_STATUS != 0 )) \
        || ! grep -q '"event":"stopped"' "$LIFECYCLE_ROOT/events.jsonl" \
        || grep -q '"event":"error"' "$LIFECYCLE_ROOT/events.jsonl"; then
    print -u2 "Launcher runtime STOP was not classified as a normal shutdown."
    cat "$LIFECYCLE_ROOT/events.jsonl" >&2
    exit 1
fi

# After TFT has started, three consecutive missing package-PID checks represent
# a real game close. Verify that the runtime emits game_stopped before cleanup.
readonly GAME_EXIT_ADB="$LIFECYCLE_ROOT/fake-adb.command"
readonly GAME_EXIT_STATE="$LIFECYCLE_ROOT/fake-adb-state"
cat >"$GAME_EXIT_ADB" <<'FAKE_ADB_EOF'
#!/bin/zsh
set -eu
if [[ "$*" == *" get-state" ]]; then
    exit 0
fi
if [[ "$*" == *" getprop sys.boot_completed" ]]; then
    print 1
    exit 0
fi
if [[ "$*" == *" cmd locale set-app-locales"* ]]; then
    exit 0
fi
if [[ "$*" == *" pidof com.riotgames.league.teamfighttactics.pbe" ]]; then
    typeset -i count=0
    [[ -f "$TFT_FAKE_ADB_STATE" ]] && count="$(<"$TFT_FAKE_ADB_STATE")"
    (( count += 1 ))
    print "$count" >"$TFT_FAKE_ADB_STATE"
    (( count <= 2 )) && print 4242
    exit 0
fi
exit 0
FAKE_ADB_EOF
chmod 755 "$GAME_EXIT_ADB"
env \
    TFT_RUNTIME_PROJECT="$LIFECYCLE_ROOT/runtime" \
    TFT_LAUNCH_LOG="$LIFECYCLE_ROOT/game-exit-runtime.log" \
    TFT_ADB="$GAME_EXIT_ADB" \
    TFT_FAKE_ADB_STATE="$GAME_EXIT_STATE" \
    TFT_AVD_HOME="$LIFECYCLE_ROOT/avd" \
    TFT_AVD_NAME=TftPBE \
    TFT_SERIAL=emulator-5582 \
    TFT_DISPLAY_SIZE=1920x1080 \
    TFT_DISPLAY_DENSITY=320 \
    TFT_GAME_LANGUAGE=en-US \
    TFT_CPU_CORES=6 \
    TFT_MEMORY_MB=6144 \
    TFT_UI_SCALE=1.0 \
    "$LAUNCHER_DIR/Resources/launcher-runtime.command" \
    >"$LIFECYCLE_ROOT/game-exit-events.jsonl" &
readonly GAME_EXIT_PID=$!
typeset game_exit_detected=0
for game_exit_attempt in {1..200}; do
    if grep -q '"event":"game_stopped"' \
            "$LIFECYCLE_ROOT/game-exit-events.jsonl" 2>/dev/null; then
        game_exit_detected=1
        break
    fi
    if ! kill -0 "$GAME_EXIT_PID" >/dev/null 2>&1; then
        break
    fi
    sleep 0.05
done
kill -TERM "$GAME_EXIT_PID" >/dev/null 2>&1 || true
wait "$GAME_EXIT_PID" || true
if (( game_exit_detected == 0 )) \
        || [[ "$(grep -c '"event":"game_stopped"' "$LIFECYCLE_ROOT/game-exit-events.jsonl")" != 1 ]] \
        || grep -q '"event":"error"' "$LIFECYCLE_ROOT/game-exit-events.jsonl"; then
    print -u2 "Launcher runtime did not classify a closed TFT process."
    cat "$LIFECYCLE_ROOT/game-exit-events.jsonl" >&2
    exit 1
fi

mkdir -p "$LAUNCHER_DIR/.build/module-cache"
xcrun swiftc \
    -target "$TEST_TARGET" \
    -module-cache-path "$LAUNCHER_DIR/.build/module-cache" \
    "$LAUNCHER_DIR/Sources/CoreModels.swift" \
    "$LAUNCHER_DIR/Sources/HostedGameUpdate.swift" \
    "$LAUNCHER_DIR/Sources/LauncherPresentation.swift" \
    "$LAUNCHER_DIR/Sources/LauncherTelemetryService.swift" \
    "$LAUNCHER_DIR/Sources/LauncherPaths.swift" \
    "$LAUNCHER_DIR/Sources/SystemServices.swift" \
    "$LAUNCHER_DIR/Sources/EmulatorBrandingPatch.swift" \
    "$LAUNCHER_DIR/Sources/EmulatorAudioRecoveryService.swift" \
    "$LAUNCHER_DIR/Sources/FPSOverlayService.swift" \
    "$LAUNCHER_DIR/Sources/InputBridgeService.swift" \
    "$LAUNCHER_DIR/Sources/InstallerService.swift" \
    "$LAUNCHER_DIR/Tests/LauncherTests.swift" \
    -o "$TEST_BINARY"

"$TEST_BINARY" \
    "$LAUNCHER_DIR/Resources/release-manifest.json" \
    "$LAUNCHER_DIR"

typeset -a ALL_SOURCES
ALL_SOURCES=("$LAUNCHER_DIR"/Sources/*.swift)
xcrun swiftc \
    -typecheck \
    -parse-as-library \
    -target arm64-apple-macosx12.0 \
    -module-cache-path "$LAUNCHER_DIR/.build/module-cache" \
    -F "$SPARKLE_ROOT" \
    "${ALL_SOURCES[@]}"

print "Mactician typecheck: OK"
