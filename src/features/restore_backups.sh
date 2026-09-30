#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
die "Automatic multi-file restoration is disabled. Use the matching backend snapshot manifest and native tools; never restore legacy cross-backend files."
