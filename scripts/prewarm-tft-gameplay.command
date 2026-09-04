#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

readonly ROOT="${0:A:h:h}"
source "$ROOT/scripts/android-environment.sh"

readonly ADB_PORT="${TFT_ADB_SERVER_PORT:-5041}"
readonly SERIAL="${TFT_SERIAL:-emulator-5586}"
readonly PACKAGE="com.riotgames.league.teamfighttactics"

ADB="$(tft_resolve_adb)"
readonly ADB

export ANDROID_ADB_SERVER_PORT="$ADB_PORT"

print "=== TFTMAC Gameplay Pre-Warm & Optimization ==="
print "ADB Port: $ADB_PORT, Serial: $SERIAL, Package: $PACKAGE"

if ! "$ADB" -P "$ADB_PORT" -s "$SERIAL" get-state >/dev/null 2>&1; then
    print -u2 "Device $SERIAL is not online on port $ADB_PORT."
    exit 1
fi

print "Step 1/4: Forcing full ART Ahead-Of-Time (AOT) compilation to 'speed'..."
"$ADB" -P "$ADB_PORT" -s "$SERIAL" shell cmd package compile -m speed "$PACKAGE" || {
    print -u2 "Warning: cmd package compile encountered an error or was partially applied."
}

print "Step 2/4: Pre-faulting game asset packages into guest Linux RAM pagecache..."
"$ADB" -P "$ADB_PORT" -s "$SERIAL" shell '
    total_bytes=0
    # Find base APK and assets
    apk_paths=$(pm path com.riotgames.league.teamfighttactics 2>/dev/null | sed "s/^package://")
    for apk in $apk_paths; do
        if [ -r "$apk" ]; then
            cat "$apk" > /dev/null 2>&1
        fi
    done
    # Pre-read data pak files
    data_dir="/data/data/com.riotgames.league.teamfighttactics/files"
    if [ -d "$data_dir" ]; then
        find "$data_dir" -type f \( -name "*.pak" -o -name "*.bundle" -o -name "*.dat" -o -name "*.bin" \) 2>/dev/null | while read -r asset; do
            cat "$asset" > /dev/null 2>&1
        done
    fi
' || true

print "Step 3/4: Tuning SurfaceFlinger compositor properties..."
"$ADB" -P "$ADB_PORT" -s "$SERIAL" shell '
    setprop debug.sf.latch_unsignaled 1 2>/dev/null || true
    setprop debug.sf.enable_gl_backpressure 0 2>/dev/null || true
' || true

print "Step 4/4: Setting high priority for Unreal Engine PSO program workers..."
"$ADB" -P "$ADB_PORT" -s "$SERIAL" shell '
    for pso_pid in $(pidof com.riotgames.league.teamfighttactics:psoprogramservice com.riotgames.league.teamfighttactics 2>/dev/null); do
        renice -n -10 -p "$pso_pid" 2>/dev/null || true
    done
' || true

print "=== Pre-warm Complete: Game code compiled, assets cached in RAM, compositor tuned ==="
