#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
log_w "PROPS" "Broad property cleanup is disabled; unknown/third-party-owned values are preserved"
exit 0
