# shellcheck shell=sh

specter_stop_pid_file() (
  [ -f "$1" ] || return 1
  _pid=$(cat "$1")
  case "$_pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "$_pid" -gt 1 ] 2>/dev/null || return 1
  _proc="${SPECTER_PROC_ROOT:-/proc}/$_pid"
  [ -f "$_proc/cmdline" ] || return 1
  _started=$(awk '{ sub(/^.*\) /,""); print $20 }' "$_proc/stat") || return 1
  case "$_started" in ''|*[!0-9]*) return 1 ;; esac
  _args=$(tr '\0' '\n' < "$_proc/cmdline")
  _interpreter=$(printf '%s\n' "$_args" | sed -n '1p')
  case "$_interpreter" in sh|ash|bash|*/sh|*/ash|*/bash) _script=$(printf '%s\n' "$_args" | sed -n '2p') ;;
    busybox|*/busybox)
      [ "$(printf '%s\n' "$_args" | sed -n '2p')" = sh ] || return 1
      _script=$(printf '%s\n' "$_args" | sed -n '3p') ;;
    *) return 1 ;;
  esac
  [ "$_script" = "$2" ] || return 1
  [ "$(awk '{ sub(/^.*\) /,""); print $20 }' "$_proc/stat")" = "$_started" ] || return 1
  [ "$(tr '\0' '\n' < "$_proc/cmdline")" = "$_args" ] || return 1
  kill -TERM "$_pid" || return 1
)

# Write complete bytes via a private sibling; preserve existing metadata.
# Never follow destination symlinks or overwrite a changed transaction preimage.
specter_atomic_copy() (
  _ac_src="$1" _ac_dst="$2"
  [ -f "$_ac_src" ] && [ ! -L "$_ac_dst" ] && [ ! -d "$_ac_dst" ] || return 1
  case "$_ac_dst" in /*) ;; *) return 1 ;; esac
  if [ "$_ac_dst" = "${KSM_TARGETS:-}" ] && [ -n "${SPECTER_TARGET_PREIMAGE:-}" ]; then
    cmp -s "$_ac_dst" "$SPECTER_TARGET_PREIMAGE" || return 1
  fi
  if [ "$_ac_dst" = "${KSM_CONFIG:-}" ] && [ -n "${SPECTER_EDIT_PREIMAGE:-}" ]; then
    cmp -s "$_ac_dst" "$SPECTER_EDIT_PREIMAGE" || {
      log_e "WRITE" "Backend config changed concurrently; refusing overwrite"; return 1;
    }
  fi
  if [ "$_ac_dst" = "${KSM_CONFIG:-}" ] && [ "${SPECTER_CONFIG_ABSENT:-0}" = 1 ]; then
    [ ! -e "$_ac_dst" ] || return 1
  fi
  if [ "$_ac_dst" = "${KSM_TARGETS:-}" ] && [ "${SPECTER_TARGET_ABSENT:-0}" = 1 ]; then
    [ ! -e "$_ac_dst" ] || return 1
  fi
  umask 077
  _ac_tmp=$(mktemp "${_ac_dst}.specter.XXXXXX") || return 1
  trap 'rm -f "$_ac_tmp"' 0
  if [ -f "$_ac_dst" ]; then
    cp -p "$_ac_dst" "$_ac_tmp" || return 1
    if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" = Enforcing ]; then
      _ac_context=$(ls -Zd "$_ac_dst" 2>/dev/null | awk '{print $1}')
      case "$_ac_context" in u:*) chcon "$_ac_context" "$_ac_tmp" || return 1 ;; *) return 1 ;; esac
    fi
  fi
  cat "$_ac_src" > "$_ac_tmp" || return 1
  mv -f "$_ac_tmp" "$_ac_dst"
)

# Fail closed on a busy/stale lock. No PID-based lock stealing, no signaling.
# The whole read/modify/write runs under one lock shared by Specter editors.
specter_backend_edit() (
  _be_feature="$1"; shift
  ksm_available || return 1
  _conflict_claimed "$_be_feature" && {
    log_e "WRITE" "$_be_feature is owned by the existing backend"; return 1;
  }
  if [ "$_be_feature" != snapshot ]; then
    case "$KSM_FORMAT" in
      ini|toml) log_e "WRITE" "Use native $KSM_NAME tools: live inode/reload semantics not validated"; return 1 ;;
    esac
  fi
  [ "${SPECTER_LOCK_HELD:-}" != "$KSM" ] || { "$@"; return $?; }
  case "$KSM" in teesim|trickystore|omk) ;; *) return 1 ;; esac
  umask 077
  mkdir -p "$SPECTER_DIR/.lock" || return 1
  _be_lock="$SPECTER_DIR/.lock/$KSM"
  mkdir "$_be_lock" 2>/dev/null || { log_e "WRITE" "Backend transaction busy; retry after inspection"; return 1; }
  trap 'rm -f "$_be_lock/preimage" "$_be_lock/target-preimage"; rmdir "$_be_lock" 2>/dev/null' 0
  SPECTER_LOCK_HELD="$KSM"
  SPECTER_EDIT_PREIMAGE=""
  SPECTER_TARGET_PREIMAGE=""
  SPECTER_CONFIG_ABSENT=1
  SPECTER_TARGET_ABSENT=1
  if [ -f "$KSM_CONFIG" ]; then
    cp -p "$KSM_CONFIG" "$_be_lock/preimage" || return 1
    SPECTER_EDIT_PREIMAGE="$_be_lock/preimage"
    SPECTER_CONFIG_ABSENT=0
  fi
  if [ -f "$KSM_TARGETS" ] && [ "$KSM_TARGETS" != "$KSM_CONFIG" ]; then
    cp -p "$KSM_TARGETS" "$_be_lock/target-preimage" || return 1
    SPECTER_TARGET_PREIMAGE="$_be_lock/target-preimage"
    SPECTER_TARGET_ABSENT=0
  elif [ "$KSM_TARGETS" = "$KSM_CONFIG" ]; then
    SPECTER_TARGET_ABSENT=0
  fi
  export SPECTER_LOCK_HELD SPECTER_EDIT_PREIMAGE SPECTER_TARGET_PREIMAGE SPECTER_CONFIG_ABSENT SPECTER_TARGET_ABSENT
  "$@"
)
