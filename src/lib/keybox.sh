# shellcheck shell=sh
# Alphabet variables are defined in decode.sh (sourced via common.sh)

decode_keybox_blob() {
  _dkb_in="$1" _dkb_out="$2"
  _dkb_tmp="/data/local/tmp/_dkb_$$.tmp"
  decode_substitution "$_dkb_in" "$_dkb_tmp" 2>/dev/null || { rm -f "$_dkb_tmp"; return 1; }
  base64 -d < "$_dkb_tmp" > "$_dkb_out" 2>/dev/null || { rm -f "$_dkb_tmp"; return 1; }
  rm -f "$_dkb_tmp"
  unset _dkb_in _dkb_out _dkb_tmp
}

# Full DER decoding is delegated to a real X.509 parser. Unknown is safe.
decode_keybox_serial() (
  command -v openssl >/dev/null 2>&1 || return 1
  umask 077
  _dks_dir=$(mktemp -d) || return 1
  trap 'rm -rf "$_dks_dir"' 0
  sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p; /-----END CERTIFICATE-----/q' "$1" > "$_dks_dir/cert.pem"
  _dks_out=$(openssl x509 -in "$_dks_dir/cert.pem" -noout -serial 2>/dev/null) || return 1
  _dks_serial=$(printf '%s' "$_dks_out" | sed 's/^serial=//' | tr 'A-F' 'a-f')
  case "$_dks_serial" in ''|*[!0-9a-f]*) return 1 ;; esac
  printf '%s\n' "$_dks_serial"
)

# 0=listed/revoked, 1=checked and absent, 2=unknown. Never treat errors as clear.
check_google_revocation() (
  case "$1" in ''|*[!0-9a-fA-F]*) return 2 ;; esac
  _gr_serial=$(printf '%s' "$1" | tr 'A-F' 'a-f' | sed 's/^0*//')
  [ -n "$_gr_serial" ] || _gr_serial=0
  case "$_gr_serial" in *[!0-9a-f]*) return 2 ;; esac
  _gr_resp=$(download "$GOOGLE_REVOCATION_URL" 2>/dev/null) || return 2
  [ -n "$_gr_resp" ] || return 2
  _gr_nodes=$(printf '%s' "$_gr_resp" | awk -f "$SPECTER_JSON_AWK") || return 2
  printf '%s\n' "$_gr_nodes" | awk -F '\t' -v serial="$_gr_serial" '
    $1 == "/entries" && $2 == "object" { valid=1 }
    $1 ~ /^\/entries\/[0-9a-fA-F]+$/ {
      key=tolower(substr($1,10)); sub(/^0+/,"",key); if(key=="") key="0"
      if(key==serial) revoked=1
    }
    END { if(!valid) exit 2; exit (revoked ? 0 : 1) }
  '
)

# No weak marker/serial check is advertised as cryptographic validation.
keybox_validate_candidate() {
  log_e "KEYBOX" "Complete private-key/XML/chain validation unavailable; refusing candidate"
  return 1
}

find_kmInstallKeybox() {
  _fk_abi=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64")
  _fk_lib_dir="/vendor/lib64"
  [ "$_fk_abi" != "arm64" ] && [ "$_fk_abi" != "x86_64" ] && _fk_lib_dir="/vendor/lib"
  _fk_bin=""
  for _fk_dir in "$_fk_lib_dir/hw" "$_fk_lib_dir" "/vendor/bin"; do
    _fk_bin=$(find "$_fk_dir" -iname "*kmInstallKeybox*" 2>/dev/null | head -1)
    [ -n "$_fk_bin" ] && break
  done
  echo "${_fk_bin:-}"
  unset _fk_abi _fk_lib_dir _fk_bin _fk_dir
}

# True if catalog entry for SOURCE/VERSION is softbanned.
keybox_is_softbanned() {
  echo "$1" | grep -o '"entries":\[[^]]*\]' | grep -o '{[^}]*"source":"'"$2"'"[^}]*"version":"'"$3"'"[^}]*}' | head -1 | grep -q '"softbanned":true'
}

# Prefer active (non-softbanned) candidates. stdin: one JSON object per line
# with source/version. $1 = full catalog JSON. stdout: preferred pool.
keybox_prefer_active() {
  _kpa_hist="$1"
  _kpa_active=""
  _kpa_soft=""
  while IFS= read -r _kpa_entry || [ -n "$_kpa_entry" ]; do
    [ -z "$_kpa_entry" ] && continue
    _kpa_src=$(echo "$_kpa_entry" | sed 's/.*"source":"\([^"]*\)".*/\1/')
    _kpa_ver=$(echo "$_kpa_entry" | sed 's/.*"version":"\([^"]*\)".*/\1/')
    if keybox_is_softbanned "$_kpa_hist" "$_kpa_src" "$_kpa_ver"; then
      _kpa_soft="${_kpa_soft}${_kpa_entry}
"
    else
      _kpa_active="${_kpa_active}${_kpa_entry}
"
    fi
  done
  if [ -n "$_kpa_active" ]; then
    printf '%s' "$_kpa_active"
  else
    printf '%s' "$_kpa_soft"
  fi
  unset _kpa_hist _kpa_active _kpa_soft _kpa_entry _kpa_src _kpa_ver
}

# Latest version for PROVIDER from catalog, preferring non-softbanned and non-revoked.
keybox_latest_for_provider() {
  _klp_hist="$1"
  _klp_prov="$2"
  _klp_entries=$(echo "$_klp_hist" | grep -o '"entries":\[[^]]*\]' | grep -o '{[^}]*"source":"'"$_klp_prov"'"[^}]*}' | grep -v '"revoked":true')
  _klp_ver=$(printf '%s\n' "$_klp_entries" | grep -v '"softbanned":true' | sed 's/.*"version":"\([^"]*\)".*/\1/' | sort -rn | head -1)
  [ -z "$_klp_ver" ] && _klp_ver=$(printf '%s\n' "$_klp_entries" | grep '"softbanned":true' | sed 's/.*"version":"\([^"]*\)".*/\1/' | sort -rn | head -1)
  echo "$_klp_ver"
  unset _klp_hist _klp_prov _klp_entries _klp_ver
}
