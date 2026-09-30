#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/constants.sh"

[ "$(cfg_get toggle_action_gms 1)" = "0" ] && exit 0

_force_stop=$(cfg_get toggle_action_gms_force_stop 1)
_clear_data=$(cfg_get toggle_action_gms_clear_data 0)
[ "$_clear_data" = 0 ] || [ "${1:-}" = --confirmed ] || die "Data clearing requires explicit --confirmed"

[ "$_force_stop$_clear_data" = "00" ] && exit 0

log_i "GMS" "Starting GMS management"

_installed_pkgs=$(pm list packages 2>/dev/null) || log_w "GMS" "Failed to list installed packages"
_count=0

if [ "$_force_stop" != "0" ]; then
  for _pkg in $GMS_KILL_LIST; do
    echo "$_installed_pkgs" | grep -Fxq "package:$_pkg" || continue
    am force-stop "$_pkg" >/dev/null 2>&1 || die "Failed to force-stop $_pkg"
    log_i "GMS" "Force-stopped $_pkg"
    _count=$((_count + 1))
  done
fi

if [ "$_clear_data" != "0" ] && echo "$_installed_pkgs" | grep -Fxq "package:com.android.vending"; then
  log_d "GMS" "Clearing Play Store data..."
  pm clear com.android.vending >/dev/null 2>&1 || die "Failed to clear Play Store data"
  log_d "GMS" "Play Store data cleared"
fi
unset _installed_pkgs

log_i "GMS" "Force-stopped $_count packages"
exit 0
