#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
die "Automatic HMA scope replacement is disabled. Export your existing HMA settings and manage scopes in its native app."
