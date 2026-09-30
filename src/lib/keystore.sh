# shellcheck shell=sh
# Enabled backends only: teesim → Tricky Store / TEESimulator-RS → OMK.
#
# Keystore manager contract (set by detect_keystore_manager):
#   KSM              backend id: teesim | trickystore | omk | none
#   KSM_NAME         display name from the module's module.prop
#   KSM_DIR          the backend's data directory
#   KSM_KEYBOX       keybox file
#   KSM_TARGETS      target/app list file
#   KSM_CONFIG       main config file: security patch level lives here; for
#                    toml also the trust fields, for json also the profiles
#   KSM_FORMAT       file format of targets/config: txt | ini | json | toml
#   KSM_PER_APP_MODES  1 when per-app !/? suffixes are meaningful (txt/ini)
#
# Feature scripts and the WebUI consume only this contract; nothing outside
# this file (plus the per-format helpers) knows backend-specific paths.

_ksm_auto_pick() {
  _kap_count=0 _kap_choice=none
  for _kap_pair in teesim:teesim tricky_store:trickystore "${OMK_MODULE##*/}:omk"; do
    module_enabled "${_kap_pair%%:*}" >/dev/null || continue
    _kap_count=$((_kap_count + 1))
    _kap_choice="${_kap_pair#*:}"
  done
  [ "$_kap_count" -eq 1 ] && printf '%s\n' "$_kap_choice" || printf '%s\n' none
  unset _kap_count _kap_choice _kap_pair
}

ksm_enforce_singleton() {
  # Retained API, now diagnostic only: refreshing status must never disable apps/modules.
  detect_keystore_manager
  [ "$KSM" != none ] || log_w "KSM" "No unambiguous enabled backend; select one explicitly before editing"
  return 0
}

detect_keystore_manager() {
  _dkm_override=$(cfg_get keystore_manager auto 2>/dev/null)
  case "$_dkm_override" in
    trickystore) KSM=none; module_enabled tricky_store >/dev/null && KSM=trickystore ;;
    teesim) KSM=none; module_enabled teesim >/dev/null && KSM=teesim ;;
    omk) KSM=none; module_enabled "${OMK_MODULE##*/}" >/dev/null && KSM=omk ;;
    *)
      KSM=$(_ksm_auto_pick)
      [ -n "$KSM" ] || KSM=none
      ;;
  esac

  case "$KSM" in
    trickystore)
      KSM_NAME=$(_ts_prop)
      [ -n "$KSM_NAME" ] || KSM_NAME="Tricky Store"
      KSM_DIR="$TRICKY_DIR"
      KSM_KEYBOX="$TARGET_FILE"
      KSM_TARGETS="$TARGET_TXT"
      KSM_CONFIG="$SECURITY_PATCH_FILE"
      KSM_FORMAT="txt"
      # Some Tricky Store versions migrate legacy configuration to INI.
      # Select the backend from the configuration file present on disk.
      if [ -f "$TRICKY_CONFIG" ]; then
        KSM_TARGETS="$TRICKY_CONFIG"
        KSM_CONFIG="$TRICKY_CONFIG"
        KSM_FORMAT="ini"
      fi
      KSM_PER_APP_MODES=1
      ;;
    teesim)
      KSM_NAME=$(_teesim_prop)
      [ -n "$KSM_NAME" ] || KSM_NAME="TEESimulator"
      KSM_DIR="$TEESIM_DIR"
      KSM_KEYBOX="$TEESIM_KEYBOX"
      KSM_TARGETS="$TEESIM_CONFIG"
      KSM_CONFIG="$TEESIM_CONFIG"
      KSM_FORMAT="json"
      KSM_PER_APP_MODES=0
      ;;
    omk)
      KSM_NAME="OhMyKeymint"
      KSM_DIR="$OMK_DIR"
      KSM_KEYBOX="$OMK_KEYBOX"
      KSM_TARGETS="$OMK_INJECTOR"
      KSM_CONFIG="$OMK_CONFIG"
      KSM_FORMAT="toml"
      KSM_PER_APP_MODES=0
      ;;
    *)
      KSM_NAME=""
      KSM_DIR=""
      KSM_KEYBOX=""
      KSM_TARGETS=""
      KSM_CONFIG=""
      KSM_FORMAT=""
      KSM_PER_APP_MODES=0
      ;;
  esac

  export KSM KSM_NAME KSM_DIR KSM_KEYBOX KSM_TARGETS KSM_CONFIG KSM_FORMAT KSM_PER_APP_MODES
  unset _dkm_override
}

ksm_available() {
  [ "$KSM" != "none" ] && [ -n "$KSM_DIR" ] && [ -d "$KSM_DIR" ] || return 1
  [ "$KSM_FORMAT" != "ini" ] || [ -f "$KSM_CONFIG" ]
}

# Explicit Tools for injector; keymint also auto-touches on trust field saves.
ksm_reload() {
  [ "$KSM" = "omk" ] || return 0
  mkdir -p "$OMK_RESTART_DIR" 2>/dev/null || true
  touch "$OMK_RESTART_DIR/restart.keymint" 2>/dev/null
}

ksm_reload_injector() {
  [ "$KSM" = "omk" ] || return 0
  mkdir -p "$OMK_RESTART_DIR" 2>/dev/null || true
  touch "$OMK_RESTART_DIR/restart.injector" 2>/dev/null
}

_ksm_inplace_from() {
  _kif_src="$1" _kif_dst="$2"
  [ -f "$_kif_dst" ] || { unset _kif_src _kif_dst; return 1; }
  specter_atomic_copy "$_kif_src" "$_kif_dst" || { unset _kif_src _kif_dst; return 1; }
  unset _kif_src _kif_dst
}

_ksm_strip_suffix() {
  _kss_line="$1"
  case "$_kss_line" in *!) _kss_line=${_kss_line%!} ;; *\?) _kss_line=${_kss_line%\?} ;; esac
  printf '%s' "$_kss_line"
  unset _kss_line
}

_ksm_pkg_ok() {
  _kpo=$(_ksm_strip_suffix "$1")
  if printf '%s\n' "$_kpo" | grep -qxE '[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*'; then
    unset _kpo
    return 0
  fi
  unset _kpo
  return 1
}

_ksm_filter_pkgs() {
  while IFS= read -r _kfp || [ -n "$_kfp" ]; do
    [ -z "$_kfp" ] && continue
    _ksm_pkg_ok "$_kfp" || continue
    printf '%s\n' "$_kfp"
  done
  unset _kfp
}

ksm_read_targets() {
  case "$KSM_FORMAT" in
    ini)
      _ini_read_targets "$KSM_TARGETS" | while IFS= read -r _krt_ini; do
        _ksm_strip_suffix "$_krt_ini"
        printf '\n'
      done
      ;;
    json)
      _teesim_read_apps "$KSM_TARGETS" | _ksm_filter_pkgs
      ;;
    toml)
      [ -f "$KSM_TARGETS" ] || return 0
      _toml_read_scoop "$KSM_TARGETS" | _ksm_filter_pkgs
      ;;
    *)
      [ -f "$KSM_TARGETS" ] || return 0
      while IFS= read -r _krt_line || [ -n "$_krt_line" ]; do
        [ -z "$_krt_line" ] && continue
        case "$_krt_line" in \[*\]) continue ;; esac
        _krt_base=$(_ksm_strip_suffix "$_krt_line")
        _ksm_pkg_ok "$_krt_base" || continue
        printf '%s\n' "$_krt_base"
      done < "$KSM_TARGETS"
      unset _krt_line _krt_base
      ;;
  esac
}

ksm_read_targets_raw() {
  case "$KSM_FORMAT" in
    ini) _ini_read_targets "$KSM_TARGETS" ;;
    # UI-facing list: package names only — uid:/pkg@user tokens are the
    # TEESimulator WebUI's concern and are preserved on commit regardless.
    json) _teesim_read_apps "$KSM_TARGETS" default | _ksm_filter_pkgs ;;
    toml) ksm_read_targets ;;
    *)
      [ -f "$KSM_TARGETS" ] || return 0
      while IFS= read -r _krr_line || [ -n "$_krr_line" ]; do
        [ -z "$_krr_line" ] && continue
        case "$_krr_line" in
          \[*\]) printf '%s\n' "$_krr_line"; continue ;;
        esac
        _ksm_pkg_ok "$_krr_line" || continue
        printf '%s\n' "$_krr_line"
      done < "$KSM_TARGETS"
      unset _krr_line
      ;;
  esac
}

# Feature entry points hold the common backend transaction lock.
ksm_lock_targets() { return 0; }

_ksm_commit_targets() {
  _kct_src="$1"
  case "$KSM_FORMAT" in
    ini)
      _ini_write_targets "$KSM_TARGETS" "$_kct_src" || {
        unset _kct_src
        return 1
      }
      ;;
    json)
      _teesim_commit_apps "$KSM_TARGETS" "$_kct_src" || {
        unset _kct_src
        return 1
      }
      ;;
    toml)
      _kct_tmp="${KSM_TARGETS}.pkgs.$$"
      : > "$_kct_tmp"
      while IFS= read -r _kct_line || [ -n "$_kct_line" ]; do
        [ -z "$_kct_line" ] && continue
        case "$_kct_line" in \[*\]) continue ;; esac
        _kct_base=$(_ksm_strip_suffix "$_kct_line")
        [ -n "$_kct_base" ] && printf '%s\n' "$_kct_base" >> "$_kct_tmp"
      done < "$_kct_src"
      _toml_write_scoop "$KSM_TARGETS" < "$_kct_tmp" || {
        rm -f "$_kct_tmp"
        unset _kct_line _kct_base _kct_tmp _kct_src
        return 1
      }
      rm -f "$_kct_tmp"
      unset _kct_line _kct_base _kct_tmp
      ;;
    *)
      rm -f "${KSM_TARGETS}.bak"
      [ -f "$KSM_TARGETS" ] && cp "$KSM_TARGETS" "${KSM_TARGETS}.bak"
      specter_atomic_copy "$_kct_src" "$KSM_TARGETS" || return 1
      rm -f "$_kct_src"
      ;;
  esac
  unset _kct_src
}

# Commit a desired flat package list (one per line, optional !/? suffix) while
# preserving configuration the flat list cannot express:
#  - txt: [name.xml] keybox scoping sections and their member packages
#  - json: non-default TEESimulator profiles (only the default profile's apps
#    are managed; ksm_read_targets_raw already returns default-only)
#  - toml: no sections, same as ksm_commit_targets
_ksm_commit_targets_merge() {
  _kcm_src="$1"
  case "$KSM_FORMAT" in
    ini) _ini_write_targets "$KSM_TARGETS" "$_kcm_src" || { unset _kcm_src; return 1; } ;;
    txt)
      if [ -f "$KSM_TARGETS" ]; then
        _ksm_txt_merge "$_kcm_src" || { unset _kcm_src; return 1; }
      else
        ksm_commit_targets "$_kcm_src" || { unset _kcm_src; return 1; }
      fi
      ;;
    json) _teesim_commit_apps "$KSM_TARGETS" "$_kcm_src" || { unset _kcm_src; return 1; } ;;
    toml) ksm_commit_targets "$_kcm_src" || { unset _kcm_src; return 1; } ;;
  esac
  unset _kcm_src
}

ksm_get_security_patch() {
  case "$KSM_FORMAT" in
    ini) _ini_get_boot_patch "$KSM_CONFIG" ;;
    json)
      _teesim_get_boot_patch "$KSM_CONFIG"
      ;;
    toml)
      [ -f "$KSM_CONFIG" ] || return 1
      grep -E '^[ ]*security_patch[ ]*=' "$KSM_CONFIG" 2>/dev/null | head -1 |
        sed 's/.*=[ ]*"\([^"]*\)".*/\1/'
      ;;
    *)
      [ -f "$KSM_CONFIG" ] || return 1
      _kgsp=$(awk '
        /^[[:space:]]*\[/ { exit }
        /^[[:space:]]*boot=/ { sub(/^[[:space:]]*boot=/,""); sub(/[[:space:]]*$/,""); if ($0 != "") { print; exit } }
      ' "$KSM_CONFIG") || _kgsp=""
      if [ -z "$_kgsp" ]; then
        _kgsp=$(awk '
          /^[[:space:]]*\[/ { exit }
          /^[[:space:]]*all=/ { sub(/^[[:space:]]*all=/,""); sub(/[[:space:]]*$/,""); if ($0 != "") { print; exit } }
        ' "$KSM_CONFIG") || _kgsp=""
      fi
      [ -n "$_kgsp" ] || { unset _kgsp; return 1; }
      printf '%s\n' "$_kgsp"
      unset _kgsp
      ;;
  esac
}

_ksm_set_security_patch() {
  _ksp_date="$1"
  case "$KSM_FORMAT" in
    ini)
      _ini_set_patch "$KSM_CONFIG" "$_ksp_date" || {
        unset _ksp_date
        return 1
      }
      ;;
    json)
      _teesim_set_patch "$KSM_CONFIG" "$_ksp_date" || {
        unset _ksp_date
        return 1
      }
      ;;
    toml)
      _ksm_wait_file "$KSM_CONFIG" 10 || {
        log_w "KSM" "OMK config.toml not available yet, skip security patch"
        unset _ksp_date
        return 1
      }
      _toml_set_trust_key "$KSM_CONFIG" "security_patch" "\"$_ksp_date\"" || {
        unset _ksp_date
        return 1
      }
      ;;
    *)
      _ksp_vendor=$(getprop ro.vendor.build.security_patch 2>/dev/null || echo "")
      if [ -z "$_ksp_vendor" ] && [ -f /vendor/build.prop ]; then
        _ksp_vendor=$(grep '^ro.vendor.build.security_patch=' /vendor/build.prop 2>/dev/null |
          head -1 | cut -d= -f2 | tr -d '[:space:]') || _ksp_vendor=""
      fi
      [ -n "$_ksp_vendor" ] || _ksp_vendor="$_ksp_date"
      _ksp_yyyymm=$(printf '%s' "$_ksp_date" | cut -d'-' -f1-2 | tr -d '-')
      _ksp_tmp="${KSM_CONFIG}.new.$$"
      {
        printf 'system=%s\nboot=%s\nvendor=%s\n' "$_ksp_yyyymm" "$_ksp_date" "$_ksp_vendor"
        if [ -f "$KSM_CONFIG" ]; then
          # Keep per-package [pkg] sections and their contents untouched.
          awk '/^[[:space:]]*\[/ { emit = 1 } emit { print }' "$KSM_CONFIG"
        fi
      } > "$_ksp_tmp"
      if [ -f "$KSM_CONFIG" ]; then
        _ksm_inplace_from "$_ksp_tmp" "$KSM_CONFIG" || {
          rm -f "$_ksp_tmp"
          unset _ksp_date _ksp_vendor _ksp_yyyymm _ksp_tmp
          return 1
        }
        rm -f "$_ksp_tmp"
      else
        specter_atomic_copy "$_ksp_tmp" "$KSM_CONFIG" || {
          rm -f "$_ksp_tmp"
          unset _ksp_date _ksp_vendor _ksp_yyyymm _ksp_tmp
          return 1
        }
      fi
      rm -f "$_ksp_tmp"
      unset _ksp_vendor _ksp_yyyymm _ksp_tmp
      ;;
  esac
  unset _ksp_date
}

ksm_get_mode() {
  case "$KSM_FORMAT" in
    json) _teesim_get_mode "$KSM_TARGETS" ;;
    *) printf '' ;;
  esac
}

_ksm_set_mode() {
  case "$KSM_FORMAT" in
    json) _teesim_set_mode "$KSM_TARGETS" "$1" ;;
    *) return 1 ;;
  esac
}

ksm_get_trust_field() {
  _kgt_key="$1"
  case "$KSM_FORMAT" in
    toml) _toml_get_trust_key "$KSM_CONFIG" "$_kgt_key" ;;
    *) printf '' ;;
  esac
  unset _kgt_key
}

_ksm_set_trust_field() {
  _kst_key="$1" _kst_val="$2"
  case "$KSM_FORMAT" in
    toml)
      _ksm_wait_file "$KSM_CONFIG" 10 || {
        log_w "KSM" "OMK config.toml not available yet, skip trust field"
        unset _kst_key _kst_val
        return 1
      }
      case "$_kst_key" in
        os_version)
          case "$_kst_val" in auto) _kst_val='"auto"' ;; esac
          _toml_set_trust_key "$KSM_CONFIG" "os_version" "$_kst_val" || {
            unset _kst_key _kst_val
            return 1
          }
          ;;
        vb_key|vb_hash)
          _toml_set_trust_key "$KSM_CONFIG" "$_kst_key" "\"$_kst_val\"" || {
            unset _kst_key _kst_val
            return 1
          }
          ;;
        *)
          unset _kst_key _kst_val
          return 1
          ;;
      esac
      ksm_reload
      ;;
    *) unset _kst_key _kst_val; return 1 ;;
  esac
  unset _kst_key _kst_val
}

# MODE "copy" keeps SRC; default "move" consumes it.
_ksm_install_keybox() {
  log_e "KEYBOX" "Installation disabled: complete key/certificate validation is not available; use the backend's native tool"
  return 1
}

ksm_commit_targets() { specter_backend_edit target _ksm_commit_targets "$@"; }

ksm_commit_targets_merge() { specter_backend_edit target _ksm_commit_targets_merge "$@"; }

ksm_set_security_patch() { specter_backend_edit security_patch _ksm_set_security_patch "$@"; }

ksm_set_mode() { specter_backend_edit teesim_mode _ksm_set_mode "$@"; }

ksm_set_trust_field() { specter_backend_edit security_patch _ksm_set_trust_field "$@"; }

ksm_install_keybox() { specter_backend_edit keybox _ksm_install_keybox "$@"; }
