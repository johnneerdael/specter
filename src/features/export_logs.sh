#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
umask 077
# Raw logs, arbitrary .val files and logcat can contain private keys/URLs/tokens.
# Export only this bounded, non-secret summary. The old sanitize flag cannot
# opt back into raw export.
OUTPUT_DIR="${SPECTER_EXPORT_DIR:-/sdcard/Download}"
OUTPUT_FILE="$OUTPUT_DIR/specter_logs.txt"
mkdir -p "$OUTPUT_DIR" || die "Cannot create export directory"
[ ! -L "$OUTPUT_FILE" ] || die "Refusing symlinked export"
_tmp=$(mktemp "$OUTPUT_DIR/.specter-summary.XXXXXX") || exit 1
trap 'rm -f "$_tmp"' 0
{
  printf 'Specter privacy-safe settings summary\n'
  printf 'Raw logs, logcat, key material, paths and URLs intentionally excluded.\n'
  for _key in toggle_scheduler toggle_hot_install toggle_prop_handler toggle_action_gms toggle_action_target toggle_action_security_patch toggle_action_pif toggle_action_keybox toggle_auto_target toggle_autopif toggle_autokeybox; do
    _value=$(cfg_get "$_key" 0)
    case "$_value" in 0|1) printf '%s=%s\n' "$_key" "$_value" ;; *) printf '%s=[invalid or non-boolean]\n' "$_key" ;; esac
  done
} > "$_tmp"
mv "$_tmp" "$OUTPUT_FILE" || die "Export commit failed"
printf 'Privacy-safe summary exported to: %s\n' "$OUTPUT_FILE"
