# shellcheck shell=sh
# Ownership journal: original existence/value plus last successful Specter write.
# Values are base64 encoded so delimiters/newlines cannot corrupt the journal.

_sp_write() (
  _jw_name="$1" _jw_kind="$2" _jw_persist="$3" _jw_value="${4:-}"
  [ "$_jw_persist" = 0 ] || { log_e "PROPS" "Persistent-store mutation is unvalidated; refusing"; return 1; }
  case "$_jw_name" in ''|*[!A-Za-z0-9_.-]*) return 1 ;; esac
  _jw_current=$(resetprop "$_jw_name" 2>/dev/null) && _jw_exists=1 || _jw_exists=0
  if [ "$_jw_kind" = set ] && [ "$_jw_exists" = 1 ] && [ "$_jw_current" = "$_jw_value" ]; then return 0; fi
  [ "$_jw_kind" != delete ] || [ "$_jw_exists" = 1 ] || return 0
  _jw_dir="$SPECTER_DIR/property-journal/$_jw_name"
  [ ! -L "$_jw_dir" ] || return 1
  umask 077
  mkdir -p "$_jw_dir" || return 1
  mkdir "$_jw_dir/lock" 2>/dev/null || return 1
  trap 'rmdir "$_jw_dir/lock" 2>/dev/null' 0
  _jw_current=$(resetprop "$_jw_name" 2>/dev/null) && _jw_exists=1 || _jw_exists=0
  if [ ! -f "$_jw_dir/original" ]; then
    {
      printf '%s\n' "$_jw_exists"
      printf '%s' "$_jw_current" | base64 | tr -d '\r\n'
      printf '\n'
    } > "$_jw_dir/original.new" || return 1
    mv "$_jw_dir/original.new" "$_jw_dir/original" || return 1
  fi
  [ "$_jw_persist" != 1 ] || printf '1\n' > "$_jw_dir/persistent"
  case "$_jw_kind:$_jw_persist" in
    set:1) resetprop -n -p "$_jw_name" "$_jw_value" || return 1 ;;
    set:0) resetprop -n "$_jw_name" "$_jw_value" || return 1 ;;
    delete:1) resetprop -p --delete "$_jw_name" || return 1 ;;
    delete:0) resetprop --delete "$_jw_name" || return 1 ;;
    *) return 1 ;;
  esac
  _jw_after=$(resetprop "$_jw_name" 2>/dev/null) && _jw_present=1 || _jw_present=0
  if [ "$_jw_kind" = set ]; then
    [ "$_jw_present" = 1 ] && [ "$_jw_after" = "$_jw_value" ] || return 1
  else
    [ "$_jw_present" = 0 ] || return 1
  fi
  {
    printf '%s\n' "$_jw_present"
    printf '%s' "$_jw_after" | base64 | tr -d '\r\n'
    printf '\n'
  } > "$_jw_dir/last.new"
  mv "$_jw_dir/last.new" "$_jw_dir/last"
)

sp_try() (
  [ "$#" -ge 2 ] || return 1
  _st_current=$(resetprop "$1" 2>/dev/null) || return 0
  if [ "$#" -eq 2 ]; then
    _sp_write "$1" set 0 "$2"
  else
    case "$_st_current" in *"$2"*) _sp_write "$1" set 0 "$3" ;; *) return 1 ;; esac
  fi
)
sp_force() { _sp_write "$1" set 0 "$2"; }
sp_persist() { _sp_write "$1" set 1 "$2"; }
sp_delete() { _sp_write "$1" delete "${2:-0}"; }

_sp_restore_one() (
  _jr_dir="$1"; _jr_name="${_jr_dir##*/}"
  case "$_jr_name" in ''|*[!A-Za-z0-9_.-]*) return 1 ;; esac
  [ ! -L "$_jr_dir" ] && [ -f "$_jr_dir/last" ] || return 1
  [ ! -f "$_jr_dir/persistent" ] || return 1
  mkdir "$_jr_dir/lock" 2>/dev/null || return 1
  trap 'rmdir "$_jr_dir/lock" 2>/dev/null' 0
  _jr_now=$(resetprop "$_jr_name" 2>/dev/null) && _jr_exists=1 || _jr_exists=0
  _jr_encoded=$(printf '%s' "$_jr_now" | base64 | tr -d '\r\n')
  if [ "$_jr_exists" != "$(sed -n '1p' "$_jr_dir/last")" ] ||
     [ "$_jr_encoded" != "$(sed -n '2p' "$_jr_dir/last")" ]; then
    log_w "RESTORE" "$_jr_name changed by another owner; journal retained"
    return 1
  fi
  _jr_value=$(sed -n '2p' "$_jr_dir/original" | base64 -d) || return 1
  _jr_was=$(sed -n '1p' "$_jr_dir/original")
  case "$_jr_was" in
    1) resetprop -n "$_jr_name" "$_jr_value" || return 1 ;;
    0) resetprop --delete "$_jr_name" || return 1 ;;
    *) return 1 ;;
  esac
  _jr_after=$(resetprop "$_jr_name" 2>/dev/null) && _jr_present=1 || _jr_present=0
  [ "$_jr_present" = "$_jr_was" ] && [ "$_jr_after" = "$_jr_value" ] || return 1
  rm -f "$_jr_dir/original" "$_jr_dir/last"
  rmdir "$_jr_dir/lock" || return 1
  trap - 0
  rmdir "$_jr_dir" 2>/dev/null || true
)

sp_restore_owned() (
  _restore_failed=0
  for _original in "$SPECTER_DIR/property-journal"/*/original; do
    [ -f "$_original" ] || continue
    _sp_restore_one "${_original%/original}" || _restore_failed=1
  done
  return "$_restore_failed"
)

apply_boot_props() {
  for _abp_prop in \
    ro.build.selinux:1 ro.build.selinux.enforce:1 \
    ro.secure:1 ro.crypto.state:encrypted \
    ro.hardware.virtual_device:0 ro.build.type:user ro.build.tags:release-keys \
    ro.boot.warranty_bit:0 ro.warranty_bit:0 ro.vendor.warranty_bit:0 ro.vendor.boot.warranty_bit:0 \
    ro.is_ever_orange:0 ro.secureboot.lockstate:locked \
    ro.boot.vbmeta.device_state:locked ro.boot.verifiedbootstate:green \
    ro.boot.veritymode:enforcing \
    ro.boot.veritymode.managed:yes ro.boot.selinux:enforcing \
    vendor.boot.verifiedbootstate:green vendor.boot.vbmeta.device_state:locked \
    ro.boot.realmebootstate:green ro.boot.realme.lockstate:1 \
    ro.kernel.qemu: ro.boot.qemu:0 \
    ro.bootimage.build.tags:release-keys \
    ro.system.build.tags:release-keys ro.vendor.build.tags:release-keys; do
    sp_try "${_abp_prop%%:*}" "${_abp_prop#*:}"
  done
  sp_force "ro.boot.flash.locked" "1"
  for _abp_prop in ro.product.build.type ro.system.build.type ro.vendor.build.type \
    ro.odm.build.type ro.product.vendor.build.type ro.product.odm.build.type; do
    sp_try "$_abp_prop" "user"
  done
  for _abp_prop in ro.product.build.tags ro.system.build.tags ro.vendor.build.tags \
    ro.odm.build.tags ro.product.vendor.build.tags ro.product.odm.build.tags; do
    sp_try "$_abp_prop" "release-keys"
  done
  for _abp_prop in partition.system.verified partition.vendor.verified \
    partition.product.verified partition.system_ext.verified partition.odm.verified; do
    sp_try "$_abp_prop" "1"
  done
  unset _abp_prop

  # Boot error prop cleanup
  sp_delete "ro.boot.verifiedbooterror" || true
  sp_delete "ro.boot.verifyerrorpart" || true
  sp_delete "crashrecovery.rescue_boot_count" || true
}

spoof_build_props() {
  _fb_flavor=$(resetprop ro.build.flavor 2>/dev/null || echo "")
  [ -n "$_fb_flavor" ] && log_i "PROPS" "ro.build.flavor: $_fb_flavor (checking)"
  case "$_fb_flavor" in
    *userdebug*) sp_try "ro.build.flavor" "${_fb_flavor%userdebug}user" ;;
    *eng*)       sp_try "ro.build.flavor" "${_fb_flavor%eng}user" ;;
    *)           log_i "PROPS" "ro.build.flavor: $_fb_flavor, already release" ;;
  esac
  unset _fb_flavor

  _fb_fingerprint=$(resetprop ro.build.fingerprint 2>/dev/null || echo "")
  case "$_fb_fingerprint" in
    *userdebug*) sp_try "ro.build.fingerprint" "${_fb_fingerprint%userdebug}user" ;;
    *)           [ -n "$_fb_fingerprint" ] && log_i "PROPS" "ro.build.fingerprint: already release" ;;
  esac
  unset _fb_fingerprint

  # Clean -dirty suffix from build properties
  for _fb_prop in ro.build.display.id ro.build.description ro.build.version.incremental \
                  ro.bootimage.build.version.incremental ro.system.build.version.incremental \
                  ro.vendor.build.version.incremental ro.odm.build.version.incremental \
                  ro.product.build.version.incremental ro.system_ext.build.version.incremental; do
    _fb_val=$(resetprop "$_fb_prop" 2>/dev/null || echo "")
    case "$_fb_val" in
      *-dirty)
        sp_try "$_fb_prop" "${_fb_val%-dirty}"
        ;;
    esac
  done
  unset _fb_prop _fb_val
}
