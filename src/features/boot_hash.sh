#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"

_feature_should_run boot_hash 0 || exit 0
_is_valid_hash() {
  case "$1" in *[!0]*) ;; *) return 1 ;; esac
  case "$1" in *[!0-9a-fA-F]*) return 1 ;; esac
  [ "${#1}" -eq 64 ]
}

# Cache is not evidence about this boot. Do not override an existing valid
# bootloader/backend property with a stale cache or attestation probe.
_current=$(resetprop ro.boot.vbmeta.digest 2>/dev/null || true)
if _is_valid_hash "$_current"; then
  log_i "BOOT_HASH" "Existing digest retained; no spoofing"
  exit 0
fi
_dex="${SPECTER_DEX:-$MODDIR/../deps/classes.dex}"
[ -f "$_dex" ] || { log_e "BOOT_HASH" "No observed digest; refusing fabrication"; exit 1; }
_observed=$(CLASSPATH="$_dex" app_process / com.dpejoh.specter.Main 2>/dev/null || true)
_observed=$(printf '%s' "$_observed" | tr -d ' \r\n' | tr '[:upper:]' '[:lower:]')
_is_valid_hash "$_observed" || { log_e "BOOT_HASH" "Attestation probe failed; digest unchanged"; exit 1; }
sp_force ro.boot.vbmeta.digest "$_observed"
log_i "BOOT_HASH" "Applied freshly observed digest (explicitly enabled)"
