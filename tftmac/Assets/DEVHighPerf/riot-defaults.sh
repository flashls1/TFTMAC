#!/system/bin/sh
# One-time DEV graphics reset. Riot regenerates settings; no CVars are injected.
set -eu
action=${1:-}
session=${2:-}
package=com.riotgames.league.teamfighttactics
stage=/data/local/tmp/tftmac-riot-defaults-v1
private=/data/user/0/$package/files/UnrealGame/TFT/TFT/Saved/Config/Android
public=/sdcard/Android/data/$package/files/UnrealGame/TFT/TFT/Saved/Config/Android
fail() { echo "Riot defaults: $*" >&2; exit 1; }
sha() { sha256sum "$1" | cut -d ' ' -f 1; }
metadata() { stat -c '%u:%g %a' "$1"; }
context() { ls -Zd "$1" | cut -d ' ' -f 1; }
case "$session" in ''|*[!a-zA-Z0-9._:-]*) fail 'invalid session' ;; esac
[ "$(id -u)" = 0 ] || fail 'root required'
[ "$(getprop ro.boot.tftmac.session)" = "$session" ] || fail 'session mismatch'
[ "$(getprop ro.debuggable)" = 1 ] || fail 'DEV debug boot required'
[ "$(getenforce)" = Enforcing ] || fail 'SELinux must remain Enforcing'
[ -z "$(pidof "$package" || true)" ] || fail 'game must be stopped'
[ ! -L "$stage" ] || fail 'journal symlink'
case "$action" in apply|rollback) ;; *) fail 'unsupported action' ;; esac

if [ "$action" = rollback ]; then
  [ -e "$stage/PREPARED" ] || { [ ! -e "$stage" ] || fail 'incomplete journal'; echo RIOT_DEFAULTS_NOT_APPLIED; exit 0; }
  while IFS='|' read -r target backup; do
    [ ! -L "$target" ] && [ ! -L "$backup" ] || fail 'rollback symlink'
    if [ "$(cat "$backup/present")" = yes ]; then
      if [ -f "$backup/original.ini" ]; then
        [ "$(sha "$backup/original.ini")" = "$(cat "$backup/sha256")" ] || fail 'backup changed'
        if [ -e "$target" ]; then
          [ -f "$target" ] && [ ! -e "$backup/post-baseline.ini" ] || fail 'unexpected new settings'
          mv "$target" "$backup/post-baseline.ini"
        fi
        mv "$backup/original.ini" "$target"
      fi
      [ "$(sha "$target")" = "$(cat "$backup/sha256")" ] || fail 'restored bytes differ'
      [ "$(metadata "$target")" = "$(cat "$backup/metadata")" ] || fail 'restored metadata differs'
      [ "$(context "$target")" = "$(cat "$backup/context")" ] || fail 'restored context differs'
    elif [ -e "$target" ]; then
      [ -f "$target" ] && [ ! -e "$backup/post-baseline.ini" ] || fail 'unexpected generated settings'
      mv "$target" "$backup/post-baseline.ini"
    fi
  done < "$stage/manifest"
  archive="$stage.rolled-back.$(cat "$stage/id")"
  [ ! -e "$archive" ] || fail 'rollback archive exists'
  mv "$stage" "$archive"
  sync
  echo RIOT_DEFAULTS_ROLLED_BACK
  exit 0
fi

if [ -e "$stage/COMPLETE" ]; then
  echo RIOT_DEFAULTS_ALREADY_INITIALIZED
  exit 0
fi
[ ! -e "$stage" ] || fail 'interrupted reset; rollback the retained journal before retry'
for target in "$private/DeviceProfiles.ini" "$public/DeviceProfiles.ini" "$private/GameUserSettings.ini"; do
  [ ! -L "$target" ] || fail 'settings symlink'
  [ ! -e "$target" ] || [ -f "$target" ] || fail 'unexpected settings type'
  [ "$(awk -v p="$target" '$5==p {n++} END {print n+0}' /proc/self/mountinfo)" = 0 ] || fail 'settings still mounted'
done
mkdir -m 700 "$stage"
id="$session.$$"
printf '%s\n' "$id" > "$stage/id"
: > "$stage/manifest"
index=0
for target in "$private/DeviceProfiles.ini" "$public/DeviceProfiles.ini" "$private/GameUserSettings.ini"; do
  index=$((index + 1))
  # Sibling backup preserves inode metadata/context through same-filesystem rename.
  parent=${target%/*}
  [ -d "$parent" ] || fail 'settings parent missing'
  backup="$parent/.tftmac-riot-defaults-$id-$index"
  [ ! -e "$backup" ] || fail 'backup already exists'
  mkdir "$backup"
  if [ -e "$target" ]; then
    echo yes > "$backup/present"
    sha "$target" > "$backup/sha256"
    metadata "$target" > "$backup/metadata"
    context "$target" > "$backup/context"
  else
    echo no > "$backup/present"
  fi
  printf '%s|%s\n' "$target" "$backup" >> "$stage/manifest"
done
sync
touch "$stage/PREPARED"
sync
while IFS='|' read -r target backup; do
  if [ "$(cat "$backup/present")" = yes ]; then
    [ "$(sha "$target")" = "$(cat "$backup/sha256")" ] || fail 'settings changed before reset'
    mv "$target" "$backup/original.ini"
    [ "$(sha "$backup/original.ini")" = "$(cat "$backup/sha256")" ] || fail 'backup verification failed'
    [ "$(metadata "$backup/original.ini")" = "$(cat "$backup/metadata")" ] || fail 'backup metadata differs'
    [ "$(context "$backup/original.ini")" = "$(cat "$backup/context")" ] || fail 'backup context differs'
  fi
  [ ! -e "$target" ] || fail 'old settings remain'
done
sync
touch "$stage/COMPLETE"
sync
echo RIOT_DEFAULTS_INITIALIZED
