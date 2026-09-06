#!/system/bin/sh
# Invoked only inside DEV's existing authenticated root/unroot transaction.
set -eu
mode="$1"
session="$2"
case "$session" in ''|*[!a-zA-Z0-9.-]*) exit 2 ;; esac
stage="/data/local/tmp/tftmac-angle-$session"
report="/data/local/tmp/tftmac-angle-report-$session"
package=com.riotgames.league.teamfighttactics
files='libEGL_angle.so libGLESv2_angle.so libGLESv1_CM_angle.so'
properties='debug.angle.feature_overrides_enabled debug.angle.capture.enabled debug.angle.capture.trigger debug.angle.capture.out_dir debug.angle.capture.label debug.angle.capture.frame_start debug.angle.capture.frame_end debug.angle.capture.compression debug.angle.tftmac_view_stats'
fail() { echo "ANGLE transaction: $*" >&2; exit 1; }
sha() { sha256sum "$1" | cut -d ' ' -f 1; }
mount_count() { awk -v p="/system/lib64/$1" '$5==p {n++} END {print n+0}' /proc/self/mountinfo; }
expected() { awk -v p="$1" '$2==p {print $1}' "$stage/expected.sha256"; }
stock() {
  case "$1" in
    libEGL_angle.so) echo b96e3e57c13008203c6785689568d5b43fcb9be901c59c343af1423e93a437d5 ;;
    libGLESv2_angle.so) echo 5da7bb9ec6cf0b40d302d64559a96c4e4af5b8a9afd7d0484866d9b073bc08b6 ;;
    libGLESv1_CM_angle.so) echo d5378998a793324fd0de36a6d32b9fce26edb086ee58b5402b9b92db214f0941 ;;
    *) fail 'unsupported library' ;;
  esac
}
[ "$(id -u)" = 0 ] || fail 'root required'
[ "$(getprop ro.boot.tftmac.session)" = "$session" ] || fail 'DEV session mismatch'
[ "$(getprop ro.debuggable)" = 1 ] || fail 'debug boot missing'
[ "$(getenforce)" = Enforcing ] || fail 'global SELinux changed'
[ -d "$stage" ] && [ ! -L "$stage" ] || fail 'staging missing'
if [ "$mode" = verify ]; then
  pid=$(pidof "$package" || true)
  case "$pid" in ''|*[!0-9]*) fail 'one live TFT process required' ;; esac
  cp "/proc/$pid/maps" "$report/loaded-maps.txt"
  for name in $files; do
    inode=$(stat -c %i "$stage/$name")
    awk -v inode="$inode" -v target="/system/lib64/$name" '$5==inode && $6==target {found=1} END {exit !found}' "$report/loaded-maps.txt" || fail 'requested library inode not mapped by TFT'
    [ "$(sha "/proc/$pid/root/system/lib64/$name")" = "$(expected "$name")" ] || fail 'loaded namespace bytes changed'
  done
  printf 'LOADED_VERIFIED pid=%s session=%s\n' "$pid" "$session"
  cat "$stage/expected.sha256"
  exit 0
fi
[ -z "$(pidof "$package" || true)" ] || fail 'game must be stopped'
if [ "$mode" = rollback ]; then
  for name in $files; do
    count=$(mount_count "$name")
    [ "$count" -le 1 ] || fail 'stacked mounts'
    if [ "$count" = 1 ]; then
      [ -f "$stage/PREPARED" ] || fail 'unowned mount'
      [ "$(sha "/system/lib64/$name")" = "$(expected "$name")" ] || fail 'unknown mounted bytes'
      [ "$(stat -c '%d:%i' "/system/lib64/$name")" = "$(stat -c '%d:%i' "$stage/$name")" ] || fail 'mount ownership changed'
    if ! umount "/system/lib64/$name"; then
      # Detach only our verified mount. Existing mappings retain their inode until
      # the native owner immediately shuts down this isolated guest.
      umount -l "/system/lib64/$name"
      echo "ANGLE_MAPPING_LIFETIME_DEFERRED $name until DEV guest shutdown"
    fi
    fi
    [ "$(mount_count "$name")" = 0 ] && [ "$(sha "/system/lib64/$name")" = "$(stock "$name")" ] || fail 'stock restoration failed'
  done
  for key in $properties; do
    if [ -f "$stage/original-$key" ]; then
      original=$(cat "$stage/original-$key")
      setprop "$key" "$original"
      [ "$(getprop "$key")" = "$original" ] || fail 'property restoration failed'
    fi
  done
  echo ROLLED_BACK > "$stage/state"
  sync
  echo 'ANGLE_ROLLED_BACK stock library hashes and recorded properties restored'
  exit 0
fi
[ "$mode" = apply ] || fail 'unsupported mode'
[ ! -e "$stage/PREPARED" ] || fail 'journal already prepared'
for name in $files; do
  [ "$(mount_count "$name")" = 0 ] && [ "$(sha "/system/lib64/$name")" = "$(stock "$name")" ] || fail 'baseline library mismatch'
  [ "$(sha "$stage/$name")" = "$(expected "$name")" ] || fail 'candidate hash mismatch'
done
for key in $properties; do getprop "$key" > "$stage/original-$key"; done
mkdir -m 700 "$report"
chown 2000:2000 "$report"
echo PREPARED > "$stage/PREPARED"
sync
for name in $files; do
  chmod 644 "$stage/$name"
  chcon u:object_r:system_lib_file:s0 "$stage/$name"
  mount -o bind "$stage/$name" "/system/lib64/$name"
  [ "$(mount_count "$name")" = 1 ] && [ "$(sha "/system/lib64/$name")" = "$(expected "$name")" ] || fail 'candidate mount failed'
done
if [ "$(cat "$stage/reuse")" = 1 ]; then
  enabled=$(getprop debug.angle.feature_overrides_enabled)
  [ -z "$enabled" ] || enabled="$enabled:"
  enabled="${enabled}tftmacRetain*"
  [ "${#enabled}" -le 91 ] || fail 'feature property too long'
  setprop debug.angle.feature_overrides_enabled "$enabled"
  [ "$(getprop debug.angle.feature_overrides_enabled)" = "$enabled" ] || fail 'feature property rejected'
fi
diagnostics=$(cat "$stage/view-diagnostics")
case "$diagnostics" in 0|1) ;; *) fail 'invalid view diagnostics selection' ;; esac
setprop debug.angle.tftmac_view_stats "$diagnostics"
[ "$(getprop debug.angle.tftmac_view_stats)" = "$diagnostics" ] || fail 'view diagnostics property rejected'
frames=$(cat "$stage/capture-frames")
case "$frames" in ''|*[!0-9]*) fail 'capture count invalid' ;; esac
if [ "$frames" -gt 0 ]; then
  [ "$frames" -le 300 ] || fail 'capture count exceeds bound'
  parent="/data/user/0/$package/files"
  [ "$(stat -c %u "$parent")" = 10215 ] || fail 'official package UID changed'
  context=$(ls -Zd "$parent" | cut -d ' ' -f 1)
  case "$context" in u:object_r:app_data_file:s0:c*) ;; *) fail 'private context unknown' ;; esac
  capture="$parent/ta_${session##*-}"
  mkdir -m 700 "$capture"
  chown 10215:10215 "$capture"
  chcon "$context" "$capture"
  # Separate retained sequences can be triggered in a single diagnostic session.
  for index in 1 2 3; do
    mkdir -m 700 "$capture/sequence-$index"
    chown 10215:10215 "$capture/sequence-$index"
    chcon "$context" "$capture/sequence-$index"
  done
  printf '%s\n' "$capture" > "$stage/capture-root"
  setprop debug.angle.capture.enabled 1
  setprop debug.angle.capture.trigger "$frames"
  setprop debug.angle.capture.frame_start ''
  setprop debug.angle.capture.frame_end ''
  setprop debug.angle.capture.out_dir "$capture/sequence-1"
  setprop debug.angle.capture.label tft_driver_sequence
  setprop debug.angle.capture.compression 1
else
  setprop debug.angle.capture.enabled 0
fi
echo MOUNTED > "$stage/state"
sync
echo 'ANGLE_MOUNTED awaiting actual TFT loaded-library verification'
