#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
[ "${1:-logs-only}" = logs-only ] || die "Full cleanup is disabled: user/tool/system data must be preserved"
[ ! -L "$SPECTER_DIR/log" ] || die "Refusing symlinked log directory"
rm -f "$SPECTER_DIR/log"/*.log "$SPECTER_DIR/log"/*.gz
log_i "CLEANUP" "Specter logs cleared; user data retained"
