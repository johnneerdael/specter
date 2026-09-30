#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
detect_keystore_manager
if [ "$KSM" = none ]; then
  log_w "FIRST_BOOT" "No unambiguous backend; no setup changes made"
  exit 0
fi
if [ "${SPECTER_LOCK_HELD:-}" != "$KSM" ]; then
  specter_backend_edit snapshot sh "$0" "$@"
  exit $?
fi
_snapshot="$BACKUP_DIR/$KSM/original"
if [ ! -d "$_snapshot" ]; then
  umask 077
  mkdir -p "$(dirname "$_snapshot")"
  _staging=$(mktemp -d "${_snapshot}.new.XXXXXX") || exit 1
  trap 'rm -rf "$_staging"' EXIT
  printf '%s\n' "$KSM_FORMAT" > "$_staging/format"
  printf 'backend=%s\nformat=%s\nrestore=manual-only\nsnapshot=live-not-atomic\n' "$KSM" "$KSM_FORMAT" > "$_staging/manifest"
  printf 'unknown\n' > "$_staging/completeness"
  for _kind in keybox config targets; do
    case "$_kind" in
      keybox) _source="$KSM_KEYBOX" ;;
      config) _source="$KSM_CONFIG" ;;
      targets) _source="$KSM_TARGETS" ;;
    esac
    if [ -f "$_source" ]; then
      cp -p "$_source" "$_staging/$_kind"
      printf '%s|present|%s\n' "$_kind" "$_source" >> "$_staging/manifest"
    else
      printf '%s|absent|%s\n' "$_kind" "$_source" >> "$_staging/manifest"
    fi
  done
  if [ "$KSM" = omk ] && [ -f "$OMK_INJECTOR" ]; then
    cp -p "$OMK_INJECTOR" "$_staging/injector"
    printf 'injector|present|%s\n' "$OMK_INJECTOR" >> "$_staging/manifest"
  fi
  if [ "$KSM" = teesim ] && [ -f "$KSM_CONFIG" ]; then
    mkdir "$_staging/keyboxes"
    _complete=1
    if awk -f "$SPECTER_JSON_AWK" "$KSM_CONFIG" > "$_staging/nodes"; then
      awk -F '\t' '$1 ~ /\/keybox$/ && $2=="string" { print substr($3,2,length($3)-2) }' "$_staging/nodes" > "$_staging/references"
      _number=0
      while IFS= read -r _reference; do
        _number=$((_number + 1))
        case "$_reference" in
          ''|*\\*|*'..'*|*'|'*) _complete=0; printf 'keybox-ref|unsupported\n' >> "$_staging/manifest"; continue ;;
          /*) _referenced="$_reference" ;;
          *) _referenced="$TEESIM_DIR/$_reference" ;;
        esac
        if [ -f "$_referenced" ] && [ ! -L "$_referenced" ]; then
          cp -p "$_referenced" "$_staging/keyboxes/$_number"
          printf 'keyboxes/%s|present|%s\n' "$_number" "$_referenced" >> "$_staging/manifest"
        else
          _complete=0
          printf 'keyboxes/%s|missing-or-unsupported|%s\n' "$_number" "$_referenced" >> "$_staging/manifest"
        fi
      done < "$_staging/references"
      [ "$_complete" != 1 ] || printf 'referenced-files-copied-live\n' > "$_staging/completeness"
    fi
    rm -f "$_staging/nodes" "$_staging/references"
  fi
  [ ! -f "$_staging/config" ] || cmp -s "$KSM_CONFIG" "$_staging/config" || die "Config changed during snapshot; retry after inspection"
  mv "$_staging" "$_snapshot"
  log_i "FIRST_BOOT" "Original $KSM files preserved in $_snapshot; inspect manifest"
fi
log_i "FIRST_BOOT" "Preservation-first setup: no downloads, key changes or app targeting"
