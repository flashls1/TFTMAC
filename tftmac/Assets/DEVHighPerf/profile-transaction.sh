#!/system/bin/sh
# DEV only. Called by the native owner after authenticated adb root and CE unlock.
set -eu
mode="$1"
session="$2"
control_expected=5b46164caea56dd4f24caf6afac7650fe61ae7c8fc20f8ae7c0b0a95b13e4264
prev2_control_expected=ccd23e717f2ae146ce76fc1f5bab8befa208c44d588fc5303bcb8670b20ea1ec
prev_control_expected=0e4c0f5816f1834f027db52f11696578c4984e2cb688ed81e3418b6275d9bb1e
prior_control_expected=636cdb47792b8975fe0ef29a1669368eea041b665a45a7169d475d0a67b40d64
candidate_expected=cbb645faa3a6772e70f969860c9c739046dcd5d38fce0eef061ed974cf68903c
priority_candidate_expected=87c281b39d8e28ab75f7bd2a82e24493acf1b65db3f0eece9743f79bc929072d
program_lru_candidate_expected=b87de95aaa4720204d199b55da908661f0aa249ee5873b738a2e92b2af09aaea
defer_texture_candidate_expected=36c7572b0bc2b95234a0faf3ab3e852eb5a480766d3b66fb9bacf1d17c0401ab
expected="$control_expected"
# Previously staged DEV profiles left behind by interrupted sessions are
# admitted only for rollback, after which the journal is archived and all
# new applies use the current hash above.
legacy_expected=76f1eb0ae79d60373dc034a9632dfe788087709d4a863ce9c6ceea12e4a05bc4
mql1_expected=8c98b6cb0e233b0fda844c50d7b8c81a101c777e30c345d0cb1f184b967bbdfb
older_control_expected=6d8751171edb53c51d565868e2e4a8bd1336829e1bab92976fded8c9de3437f2
lkg_control_expected=45d6465040ef8b7298cd8da000208e4ee0be924c65a20326900267f25adf5c9c
package=com.riotgames.league.teamfighttactics
target=/data/user/0/$package/files/UnrealGame/TFT/TFT/Saved/Config/Android/DeviceProfiles.ini
parent=${target%/*}
stage=/data/local/tmp/tftmac-native-highperf
fail() { echo "HighPerf transaction: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'root required'
[ "$(getprop ro.boot.tftmac.session)" = "$session" ] || fail 'session mismatch'
[ "$(getprop ro.debuggable)" = 1 ] || fail 'debug boot missing'
[ "$(getenforce)" = Enforcing ] || fail 'global SELinux must remain Enforcing'
[ -z "$(pidof "$package" || true)" ] || fail 'game must be stopped'
mount_count() { awk -v p="$target" '$5==p {n++} END {print n+0}' /proc/self/mountinfo; }
sha() { sha256sum "$1" | cut -d ' ' -f 1; }
context() { ls -Zd "$1" | cut -d ' ' -f 1; }
metadata() { stat -c '%u:%g %a' "$1"; }
rollback() {
  if [ ! -e "$stage/PREPARED" ]; then
    [ "$(mount_count)" = 0 ] || fail 'unowned mount'
    [ ! -e "$stage" ] || fail 'incomplete staging; preserve for inspection'
    return
  fi
  [ ! -L "$stage" ] && [ "$(cat "$stage/target")" = "$target" ] || fail 'journal target mismatch'
  observed_expected=$(cat "$stage/expected" 2>/dev/null || true)
  case "$observed_expected" in
    "$control_expected"|"$prev2_control_expected"|"$prev_control_expected"|"$prior_control_expected"|"$candidate_expected"|"$priority_candidate_expected"|"$program_lru_candidate_expected"|"$defer_texture_candidate_expected"|"$legacy_expected"|"$mql1_expected"|"$older_control_expected"|"$lkg_control_expected") journal_expected="$observed_expected" ;;
    *) fail "journal revision mismatch expected=$expected observed=${observed_expected:-missing}" ;;
  esac
  count=$(mount_count)
  [ "$count" -le 1 ] || fail 'stacked mounts'
  if [ "$count" = 1 ]; then
    [ "$(sha "$target")" = "$journal_expected" ] || fail 'unknown mount bytes'
    umount "$target"
  fi
  [ "$(mount_count)" = 0 ] || fail 'unmount not proven'
  if [ "$(cat "$stage/present")" = yes ]; then
    [ "$(sha "$target")" = "$(cat "$stage/original.sha256")" ] || fail 'underlying original changed'
    [ "$(metadata "$target")" = "$(cat "$stage/original.metadata")" ] || fail 'underlying metadata changed'
    [ "$(context "$target")" = "$(cat "$stage/original.context")" ] || fail 'underlying context changed'
  else
    if [ -e "$target" ]; then
      [ ! -L "$target" ] && [ -f "$target" ] && [ "$(stat -c %s "$target")" = 0 ] || fail 'unexpected underlying file'
      rm "$target"
    fi
    [ ! -e "$target" ] || fail 'original absence not restored'
  fi
  echo ROLLED_BACK > "$stage/state"
  sync
  archive="$stage.rolled-back.$(cat "$stage/session")"
  [ ! -e "$archive" ] || fail 'archive already exists'
  mv "$stage" "$archive"
  sync
  echo 'ROLLED_BACK original content, metadata and presence verified'
}
case "$mode" in
rollback) rollback; exit 0 ;;
apply) rollback ;;
*) fail 'unsupported operation' ;;
esac
if [ "$mode" = apply ] && [ "${3:-control}" = pso_wait_all ]; then
  expected="$candidate_expected"
elif [ "$mode" = apply ] && [ "${3:-control}" = pso_priority_escalate ]; then
  expected="$priority_candidate_expected"
elif [ "$mode" = apply ] && [ "${3:-control}" = program_lru_evict20 ]; then
  expected="$program_lru_candidate_expected"
elif [ "$mode" = apply ] && [ "${3:-control}" = defer_texture_creation1 ]; then
  expected="$defer_texture_candidate_expected"
fi
[ -d "$parent" ] && [ ! -L "$target" ] || fail 'private parent missing or target symlink'
[ "$(stat -c %u "$parent")" = 10215 ] || fail 'unexpected official package owner'
ctx=$(context "$parent")
case "$ctx" in u:object_r:app_data_file:s0:c*) ;; *) fail 'unexpected app context' ;; esac
[ "$(sha /data/local/tmp/tftmac-native-profile.ini)" = "$expected" ] || fail 'staged input mismatch'
mkdir -m 700 "$stage"
printf '%s\n' "$session" > "$stage/session"
printf '%s\n' "$target" > "$stage/target"
printf '%s\n' "$expected" > "$stage/expected"
cp /data/local/tmp/tftmac-native-profile.ini "$stage/DeviceProfiles.ini"
chown 0:0 "$stage/DeviceProfiles.ini"
chmod 444 "$stage/DeviceProfiles.ini"
chcon "$ctx" "$stage/DeviceProfiles.ini"
if [ -e "$target" ]; then
  [ -f "$target" ] || fail 'unexpected target type'
  echo yes > "$stage/present"
  sha "$target" > "$stage/original.sha256"
  metadata "$target" > "$stage/original.metadata"
  context "$target" > "$stage/original.context"
  cp -p "$target" "$stage/original.ini"
  [ "$(sha "$stage/original.ini")" = "$(cat "$stage/original.sha256")" ] || fail 'backup mismatch'
else
  echo no > "$stage/present"
fi
echo PREPARED > "$stage/state"
sync
touch "$stage/PREPARED"
sync
if [ "$(cat "$stage/present")" = no ]; then
  touch "$target"
  chown 10215:10215 "$target"
  chmod 600 "$target"
  chcon "$ctx" "$target"
fi
mount -o bind "$stage/DeviceProfiles.ini" "$target"
[ "$(mount_count)" = 1 ] && [ "$(sha "$target")" = "$expected" ] || fail 'mount verification failed'
[ "$(metadata "$target")" = '0:0 444' ] && [ "$(context "$target")" = "$ctx" ] || fail 'mounted metadata mismatch'
verified_zygotes=
last_zygotes=
consecutive=0
attempt=0
while [ "$attempt" -lt 60 ]; do
  zygotes=$(pidof zygote64 2>/dev/null || true)
  all_visible=yes
  current_zygotes=
  if [ -z "$zygotes" ]; then
    all_visible=no
  else
    for zygote in $zygotes; do
      case "$zygote" in *[!0-9]*|'') all_visible=no; continue ;; esac
      [ -d "/proc/$zygote" ] || { all_visible=no; continue; }
      current_zygotes="${current_zygotes}${current_zygotes:+ }$zygote"
      observed=$(nsenter -t "$zygote" -m -- sha256sum "$target" 2>/dev/null | cut -d ' ' -f 1 || true)
      [ "$observed" = "$expected" ] || all_visible=no
    done
  fi
  if [ "$all_visible" = yes ] && [ -n "$current_zygotes" ]; then
    if [ "$current_zygotes" = "$last_zygotes" ]; then
      consecutive=$((consecutive + 1))
    else
      consecutive=1
    fi
    last_zygotes="$current_zygotes"
    if [ "$consecutive" -ge 2 ]; then
      verified_zygotes="$current_zygotes"
      break
    fi
  else
    consecutive=0
    last_zygotes="$current_zygotes"
  fi
  attempt=$((attempt + 1))
  sleep 0.25
done
[ -n "$verified_zygotes" ] || fail "zygote mount namespace convergence timed out: last=${last_zygotes:-none}"
echo MOUNT_VERIFIED > "$stage/state"
sync
printf 'MOUNT_VERIFIED sha256=%s owner=0:0 mode=444 context=%s zygotes=%s original_present=%s convergence_polls=%s\n' "$expected" "$ctx" "$verified_zygotes" "$(cat "$stage/present")" "$attempt"
