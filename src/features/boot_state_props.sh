#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/constants.sh"

_feature_should_run prop_handler 0 || exit 0
_conflict_claimed boot_state_props && exit 0

log_i "PROPS" "Starting boot-time property hardening"

# --- Conditional toggles ---
_do_bootprops=$(cfg_get toggle_boot_state_props 1)
_do_bootmode=$(cfg_get toggle_bootmode_spoof 1)

# --- 1. Boot property overrides (formerly inline in service.sh) ---
if [ "$_do_bootprops" != "0" ]; then
  if [ "$_do_bootmode" != "0" ]; then
    sp_try "ro.bootmode" "normal"
  fi

  apply_boot_props
  log_i "PROPS" "Boot property overrides applied"

  if [ -f "$MODDIR/boot_hash.sh" ]; then
    sh "$MODDIR/boot_hash.sh" || log_w "PROPS" "Boot hash resolution failed"
  fi
fi

log_i "PROPS" "Persistent property scanning/deletion disabled: other modules own these settings"
exit 0
