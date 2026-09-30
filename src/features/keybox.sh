#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
die "Specter keybox installation is disabled: complete candidate validation is unavailable. Preserve your existing key material and use the backend's native tools."
