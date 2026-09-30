#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
die "Vendor key provisioning is disabled: irreversible hardware/key changes are outside preservation-safe operations."
