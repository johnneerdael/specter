#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
umask 077
ensure_dir "$SPECTER_DIR/log"
ACTION_LOG="$SPECTER_DIR/log/action.log"
log_rotate "$ACTION_LOG"
_step=$(mktemp "$SPECTER_DIR/log/.action.XXXXXX") || exit 1
trap 'rm -f "$_step"' EXIT
_failed=0
_run_step() {
  _step_script="$1"
  shift
  printf 'Running %s\n' "$_step_script"
  if sh "$MODDIR/features/$_step_script" "$@" > "$_step" 2>&1; then _step_code=0; else _step_code=$?; _failed=1; fi
  cat "$_step"
  cat "$_step" >> "$ACTION_LOG" || _failed=1
  printf '%s exited %s\n' "$_step_script" "$_step_code"
}
for _pair in gms:gms.sh target:target.sh security_patch:security_patch.sh keybox:keybox.sh pif:pif.sh; do
  _feature_should_run "${_pair%%:*}" 0 || continue
  case "${_pair%%:*}" in
    target) _run_step target.sh --merge ;;
    *) _run_step "${_pair#*:}" ;;
  esac
done
# Diagnostics are not evidence that the requested actions succeeded.
_run_step keystore_info.sh
_run_step keybox_info.sh
if [ "$_failed" = 0 ]; then _summary="Requested actions completed"; else _summary="One or more requested actions failed or were refused"; fi
printf '%s\n' "$_summary"
printf '{"script":"action.sh","output":"%s","time":"%s","code":%s}\n' "$_summary" "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" "$_failed" >> "$SPECTER_DIR/log/history.jsonl"
exit "$_failed"
