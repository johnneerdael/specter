#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
log_w "ADB" "Automatic debugging/OEM-unlock changes are disabled; recovery access is preserved"
exit 0
