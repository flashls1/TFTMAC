#!/bin/zsh
set -euo pipefail

readonly SOURCE_LAB="${0:A:h}"
readonly PROJECT_ROOT="${SOURCE_LAB:h}"
readonly LIVE_ROOT="/Volumes/MAC MINI M4/TFTMAC"
readonly LIVE_LAB="$LIVE_ROOT/OvernightLab"

copy_file() {
    local mode="$1"
    local source="$2"
    local destination="$3"
    mkdir -p "${destination:h}"
    if [[ "${source:A}" == "${destination:A}" ]]; then
        chmod "$mode" "$destination"
        return
    fi
    if [[ -f "$destination" ]] && cmp -s "$source" "$destination"; then
        chmod "$mode" "$destination"
        return
    fi
    /usr/bin/install -m "$mode" "$source" "$destination"
}

[[ -d "$LIVE_ROOT" ]] || { print -u2 -- "TFTMAC live root is missing: $LIVE_ROOT"; exit 2; }

# Source/config only. Generated campaigns/database/reports/bin remain in place.
copy_file 755 "$SOURCE_LAB/overnight_lab.py" "$LIVE_LAB/overnight_lab.py"
copy_file 755 "$SOURCE_LAB/install.command" "$LIVE_LAB/install.command"
copy_file 755 "$SOURCE_LAB/run-overnight-campaign.command" "$LIVE_LAB/run-overnight-campaign.command"
copy_file 644 "$SOURCE_LAB/README.md" "$LIVE_LAB/README.md"
copy_file 644 "$SOURCE_LAB/schema.sql" "$LIVE_LAB/schema.sql"
copy_file 644 "$SOURCE_LAB/authority/official-client-runtime.json" "$LIVE_LAB/authority/official-client-runtime.json"
copy_file 644 "$SOURCE_LAB/authority/native-capture-recovery-2026-09-11.json" "$LIVE_LAB/authority/native-capture-recovery-2026-09-11.json"
copy_file 644 "$SOURCE_LAB/manifests/official-candidates.json" "$LIVE_LAB/manifests/official-candidates.json"

# Existing controller code resolves these two classifier inputs from ROOT.parent.
copy_file 644 "$PROJECT_ROOT/tools/tft-screen-classifier.swift" "$LIVE_ROOT/tools/tft-screen-classifier.swift"
copy_file 755 "$PROJECT_ROOT/scripts/build-tft-screen-classifier.command" "$LIVE_ROOT/scripts/build-tft-screen-classifier.command"

TFT_SCREEN_CLASSIFIER_BINARY="$LIVE_LAB/bin/tft-screen-classifier" \
TFT_SCREEN_CLASSIFIER_MODULE_CACHE="$LIVE_LAB/bin/swift-module-cache" \
    "$LIVE_ROOT/scripts/build-tft-screen-classifier.command" >/dev/null

/usr/bin/python3 "$LIVE_LAB/overnight_lab.py" verify-static
print -r -- "$LIVE_LAB"
