# shellcheck shell=sh
CONFLICT_BACKUP_FILE="$SPECTER_DIR/conflict_backups.txt"
CONFLICT_LIST="$CONFIG_DIR/conflicts.txt"

_conflict_detect() {
  case "$1" in
    integritybox) module_enabled playintegrityfix >/dev/null && [ -d "/data/adb/Box-Brain" ] ;;
    *) module_enabled "$1" >/dev/null ;;
  esac
}

_conflict_uninstall() {
  log_w "CONFLICT" "Refusing automatic uninstall of $1; remove conflicts manually after backup"
  return 1
}

_conflict_toggle_key() {
  case "$1" in target|security_patch|gms|keybox|pif) printf 'toggle_action_%s' "$1" ;;
    crom_props) printf 'toggle_custom_rom_props' ;;
    *) printf 'toggle_%s' "$1" ;; esac
}

_feature_should_run() {
  _fsr_feature="$1" _fsr_default="${2:-1}"
  [ "$(cfg_get "$(_conflict_toggle_key "$_fsr_feature")" "$_fsr_default")" != "0" ] || return 1
  if _conflict_claimed "$_fsr_feature"; then
    log_d "CONFLICT" "$_fsr_feature claimed by another module, skipping"
    return 1
  fi
}

_resolve_aggressive() {
  _resolve_passive "$@"
  log_w "CONFLICT" "$2 overlaps; existing module retained"
}

_resolve_moderate() {
  _resolve_passive "$@"
}

_resolve_passive() {
  if [ ! -f "$CONFIG_DIR/val/conflict_$1.val" ]; then
    cfg_set "conflict_$1" "priority_module"
    log_i "CONFLICT" "$2: partial overlap, defaulting to Module priority"
  fi
}

resolve_conflicts() {
  ensure_dir "$SPECTER_DIR"
  touch "$CONFLICT_BACKUP_FILE" 2>/dev/null || true

  while IFS='|' read -r _rc_id _rc_name _rc_type _rc_features _rc_scripts; do
    case "$_rc_id" in ''|\#*) continue ;; esac
    if ! _conflict_detect "$_rc_id"; then
      [ -f "$CONFIG_DIR/val/conflict_$_rc_id.val" ] || continue
      rm -f "$CONFIG_DIR/val/conflict_$_rc_id.val"
      sed -i "\|/$_rc_id/|d" "$CONFLICT_BACKUP_FILE" 2>/dev/null || true
    fi
  done < "$CONFLICT_LIST"

  while IFS='|' read -r _rc_id _rc_name _rc_type _rc_features _rc_scripts; do
    case "$_rc_id" in ''|\#*) continue ;; esac
    _conflict_detect "$_rc_id" || continue
    case "$_rc_type" in
      aggressive) _resolve_aggressive "$_rc_id" "$_rc_name" "$_rc_scripts" ;;
      moderate) _resolve_moderate "$_rc_id" "$_rc_name" "$_rc_scripts" ;;
      passive) _resolve_passive "$_rc_id" "$_rc_name" ;;
    esac
  done < "$CONFLICT_LIST"
}

_conflict_claimed() {
  _cc_feature="$1"
  [ -f "$CONFLICT_LIST" ] || return 1
  while IFS='|' read -r _cc_id _cc_name _cc_type _cc_features _cc_scripts; do
    case "$_cc_id" in ''|\#*) continue ;; esac
    _conflict_detect "$_cc_id" || continue
    case ",$_cc_features," in *,"$_cc_feature",*) ;; *) continue ;; esac
    [ "$(cfg_get "conflict_${_cc_id}_${_cc_feature}" "$(cfg_get "conflict_$_cc_id" "priority_module")")" = "priority_module" ] && return 0
  done < "$CONFLICT_LIST"

  return 1
}

conflict_status_json() {
  _cs_first=1
  printf '['
  [ -f "$CONFLICT_LIST" ] || { printf ']'; return 0; }
  while IFS='|' read -r _cs_id _cs_name _cs_type _cs_features _cs_scripts; do
    case "$_cs_id" in ''|\#*) continue ;; esac
    _conflict_detect "$_cs_id" || continue
    [ "$_cs_first" -eq 0 ] && printf ',' || _cs_first=0
    _cs_choice=$(cfg_get "conflict_$_cs_id" "priority_module")
    printf '{"key":"%s","friendlyName":"%s","detected":true,"prioritySpecter":%s,"type":"%s","features":"%s"}' \
      "$_cs_id" "$_cs_name" "$([ "$_cs_choice" = "priority_specter" ] && echo true || echo false)" "$_cs_type" "$_cs_features"
  done < "$CONFLICT_LIST"
  printf ']'
}

conflict_set_choice() {
  case "$2" in priority_specter|priority_module) ;; *) return 1 ;; esac
  [ -f "$CONFLICT_LIST" ] || return 1
  awk -F'|' -v id="$1" '$1 == id { found=1 } END { exit !found }' "$CONFLICT_LIST" || return 1
  cfg_set "conflict_$1" "$2" || return 1
  _choice_id="$1"; _choice_value="$2"
  _choice_features=$(awk -F'|' -v id="$_choice_id" '$1==id {print $4}' "$CONFLICT_LIST")
  _choice_ifs="$IFS"; IFS=','
  for _choice_feature in $_choice_features; do
    [ -n "$_choice_feature" ] || continue
    cfg_set "conflict_${_choice_id}_$_choice_feature" "$_choice_value" || { IFS="$_choice_ifs"; return 1; }
  done
  IFS="$_choice_ifs"
}

conflict_resolve_for_feature() {
  _crf_toggle_key="$(_conflict_toggle_key "$1")"
  while IFS='|' read -r _crf_id _crf_name _crf_type _crf_features _crf_scripts; do
    case "$_crf_id" in ''|\#*) continue ;; esac
    _conflict_detect "$_crf_id" || continue
    case ",$_crf_features," in *,"$1",*) ;; *) continue ;; esac
    [ "$(cfg_get "conflict_$_crf_id" priority_module)" = "priority_module" ] || continue
    cfg_set "conflict_${_crf_id}_$1" "priority_specter"
  done < "$CONFLICT_LIST"
  cfg_set "$_crf_toggle_key" "1"
}
