# shellcheck shell=sh

MODDIR="${0%/*}"
case "$MODDIR" in */lib) MODDIR="${MODDIR%/lib}" ;; */features) MODDIR="${MODDIR%/features}" ;; esac
[ -n "$MODDIR" ] || { echo "[SCHED] MODDIR not set" >&2; exit 1; }

. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/constants.sh"
. "$MODDIR/lib/desc.sh"

PID_FILE="$SPECTER_DIR/scheduler.pid"
TASKS_DIR="$SPECTER_DIR/scheduler_tasks"
INOTIFY_HANDLER="$SPECTER_DIR/.inotify_handler.sh"

ensure_dir "$TASKS_DIR" 2>/dev/null
ensure_dir "$SPECTER_DIR/log" 2>/dev/null

[ "$(cfg_get toggle_scheduler 0)" = 1 ] || exit 0
# An atomic directory prevents duplicate schedulers; stale locks require inspection.
_sched_lock="$SPECTER_DIR/.scheduler.lock"
mkdir "$_sched_lock" 2>/dev/null || { log_w "SCHED" "Scheduler lock exists; refusing duplicate"; exit 1; }
printf '%s' "$$" > "$PID_FILE"
trap 'rm -f "$PID_FILE" "$INOTIFY_HANDLER"; rmdir "$_sched_lock" 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP

log_i "SCHED" "Started (PID $$)"

# Detached inotify children could outlive the verified scheduler PID.
# Preserve native watchers; use only the explicitly enabled polling loop until
# child lifetime/identity cleanup has dedicated Android validation.
log_w "SCHED" "Detached inotify watchers disabled; explicit polling only"

while true; do
  [ -d "$MODDIR" ] || exit 0
  _now=$(date +%s 2>/dev/null || echo "0")

  for _task_line in keybox_info:keybox_info.sh:21600:toggle_keybox_info \
                    auto_target:auto_target.sh:300:toggle_auto_target \
                    autopif:pif.sh:86400:toggle_autopif \
                    autokeybox:keybox.sh:86400:toggle_autokeybox; do
    _name="${_task_line%%:*}"
    _rest="${_task_line#*:}"
    _script="${_rest%%:*}"
    _rest="${_rest#*:}"
    _default_interval="${_rest%%:*}"
    _toggle="${_rest#*:}"

    [ "$(cfg_get "$_toggle" 1)" = "0" ] && continue

    _last_run=$(cat "$TASKS_DIR/${_name}_last" 2>/dev/null || echo "0")
    _cfg_interval=$(cfg_get "${_name}_interval" "$_default_interval")
    [ "$_cfg_interval" -lt 10 ] && _cfg_interval=10

    if [ "$_now" -ge "$((_last_run + _cfg_interval))" ]; then
      log_rotate "$SPECTER_DIR/log/sched_${_name}.log"
      log_i "SCHED" "Running $_name"
      sh "$MODDIR/features/$_script" >"$SPECTER_DIR/log/sched_${_name}.log" 2>&1 || log_e "SCHED" "$_name failed"
      printf '%s' "$_now" > "$TASKS_DIR/${_name}_last"

      case "$_name" in
        keybox_info|auto_target|autopif|autokeybox)
          refresh_module_description
          ;;
      esac
    fi
  done

  sleep 57
done
