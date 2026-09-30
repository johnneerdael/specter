#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
die "Third-party PIF fingerprint management is disabled to avoid conflicts. Use your single PIF module's native WebUI."
