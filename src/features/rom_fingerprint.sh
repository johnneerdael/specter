#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/constants.sh"

[ "$(cfg_get toggle_rom_fingerprint 1)" = "0" ] && exit 0

_rf_hexpatch=$(cfg_get toggle_rom_fingerprint_names 1)
_rf_prefix=$(cfg_get toggle_rom_fingerprint_prefix 1)
_rf_pif=$(cfg_get toggle_rom_fingerprint_pif 1)
_rf_spoof=$(cfg_get toggle_rom_fingerprint_build_type 1)

[ "$_rf_hexpatch$_rf_prefix$_rf_pif$_rf_spoof" = "0000" ] && exit 0

log_i "ROM_FP" "Cleaning ROM fingerprints"
_cleaned=0

if [ "$_rf_spoof" != "0" ]; then
  spoof_build_props
fi

# Broad ROM/PIF property scans intentionally do not delete anything.
if [ "$_rf_prefix" != "0" ]; then
  for _rf_build_prop in ro.build.fingerprint ro.build.display.id ro.build.description ro.build.version.incremental ro.product.vendor.name; do
    _rf_val=$(resetprop "$_rf_build_prop" 2>/dev/null || echo "")
    [ -z "$_rf_val" ] && continue
    _rf_new_val="$_rf_val"
    for _rf_pref in aosp_ lineage_ lineage-; do
      case "$_rf_new_val" in
        "$_rf_pref"*) _rf_new_val=${_rf_new_val#"$_rf_pref"} ;;
      esac
    done
    [ "$_rf_new_val" != "$_rf_val" ] && sp_force "$_rf_build_prop" "$_rf_new_val" && _cleaned=$((_cleaned + 1))
  done
  unset _rf_build_prop _rf_val _rf_new_val _rf_pref
fi

if [ "$_cleaned" -gt 0 ]; then
  log_i "ROM_FP" "Cleaned $_cleaned ROM-specific fingerprints"
else
  log_i "ROM_FP" "No ROM fingerprints to clean"
fi
unset _cleaned
log_i "ROM_FP" "ROM fingerprint cleanup complete"
