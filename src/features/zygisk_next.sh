#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
die "Automatic denylist configuration is disabled. Export existing settings and use the native root manager."
