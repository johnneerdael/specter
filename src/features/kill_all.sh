#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
die "Bulk app-data clearing is disabled; app accounts and data must be preserved."
