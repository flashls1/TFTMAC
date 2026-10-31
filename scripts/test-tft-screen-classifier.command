#!/bin/zsh
set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly BUILD="$PROJECT_DIR/scripts/build-tft-screen-classifier.command"
readonly CLASSIFIER="${TFT_SCREEN_CLASSIFIER_BINARY:-$PROJECT_DIR/runtime/tft-screen-classifier}"
readonly JQ="${TFT_JQ:-$(command -v jq 2>/dev/null || true)}"
typeset -a FIXTURES

if (( $# > 0 )); then
    FIXTURES=("$@")
elif [[ -n "${TFT_SCREEN_CLASSIFIER_FIXTURE:-}" ]]; then
    FIXTURES=("$TFT_SCREEN_CLASSIFIER_FIXTURE")
else
    fixture="$(
        find "$PROJECT_DIR/runtime/measurements" -type f \
            \( -name 'before.png' -o -name 'state-*-battle.png' \) \
            -print 2>/dev/null | sort | tail -n 1 || true
    )"
    if [[ -n "$fixture" ]]; then
        FIXTURES=("$fixture")
    else
        FIXTURES=()
    fi
fi
if (( ${#FIXTURES} == 0 )); then
    "$BUILD" >/dev/null
    "$CLASSIFIER" --self-test >/dev/null
    print "TFT screen classifier self-test: OK (no fixture files present)"
    exit 0
fi

"$BUILD" >/dev/null
"$CLASSIFIER" --self-test >/dev/null
readonly TEST_ROOT="$(mktemp -d /tmp/tft-screen-classifier-test.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

typeset fixture dimensions width height output state stage reference_json
typeset reference_state reference_stage
integer fixture_index=0
for fixture in "${FIXTURES[@]}"; do
    (( fixture_index += 1 ))
    if [[ -z "$fixture" || ! -f "$fixture" ]]; then
        print "Fixture not found: $fixture"
        exit 2
    fi
    reference_json="$TEST_ROOT/reference-${fixture_index}.json"
    "$CLASSIFIER" "$fixture" > "$reference_json"
    reference_state="$("$JQ" -r '.state' "$reference_json")"
    reference_stage="$("$JQ" -r '.stage // ""' "$reference_json")"
    if [[ "$reference_state" == unknown ]]; then
        print "Fixture was classified as unknown: $fixture"
        exit 1
    fi
    if [[ ( "$reference_state" == battle || "$reference_state" == trial_choice ) \
            && -z "$reference_stage" ]]; then
        print "The semantic battle fixture does not contain a stage: $fixture"
        exit 1
    fi

    for dimensions in 1920x1080 2560x1440 2880x1620 3200x1800 3840x2160; do
        width="${dimensions%x*}"
        height="${dimensions#*x}"
        output="$TEST_ROOT/${fixture_index}-${dimensions}.png"
        /usr/bin/sips -z "$height" "$width" "$fixture" --out "$output" >/dev/null
        "$CLASSIFIER" "$output" > "$TEST_ROOT/${fixture_index}-${dimensions}.json"
        state="$("$JQ" -r '.state' "$TEST_ROOT/${fixture_index}-${dimensions}.json")"
        stage="$("$JQ" -r '.stage // ""' "$TEST_ROOT/${fixture_index}-${dimensions}.json")"
        if [[ "$state" != "$reference_state" || "$stage" != "$reference_stage" ]]; then
            print "Classifier scale regression fixture=$fixture dimensions=$dimensions: state=$state stage=$stage"
            exit 1
        fi
    done
    print "TFT classifier fixture: OK ($reference_state/${reference_stage:-none}, four resolutions)"
done

/usr/bin/sips -z 900 1600 "${FIXTURES[1]}" --out "$TEST_ROOT/unsupported.png" >/dev/null
if "$CLASSIFIER" "$TEST_ROOT/unsupported.png" >/dev/null 2>&1; then
    print "The classifier incorrectly accepted unsupported resolution 1600x900."
    exit 1
fi

print "TFT screen classifier scale fixtures: OK (${#FIXTURES} fixture(s))"
