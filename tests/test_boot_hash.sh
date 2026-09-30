plan "boot hash — opt-in freshly observed evidence, no cache/random fallback"
_setup_boot_hash_env() {
  bootstrap
  source_libs
  set_cfg toggle_boot_hash 1
  export SPECTER_DEX="$TEST_ROOT/deps/classes.dex"
  mkdir -p "$TEST_ROOT/deps"
  touch "$SPECTER_DEX"
  printf '#!/bin/sh\nprintf "%%s" "$MOCK_TEE_HASH"\n' > "$BIN_DIR/app_process"
  chmod +x "$BIN_DIR/app_process"
}
_setup_boot_hash_env
export MOCK_TEE_HASH=0d3cbbb6ea69c34ffcba2b1c36e4f66cdd34823383bd9f67d9f1b469e21785ab
run_feature boot_hash.sh >/dev/null
assert_exit_code "fresh observed digest accepted" 0 "$?"
assert_prop_eq "fresh observed digest applied" ro.boot.vbmeta.digest "$MOCK_TEE_HASH"
assert_file_exists "original absence journalled" "$SPECTER_DIR/property-journal/ro.boot.vbmeta.digest/original"
assert_file_not_exists "no stale boot cache created" "$SPECTER_DIR/boot_hash"
_setup_boot_hash_env
printf '%s' 1122334455667788990011223344556677889900112233445566778899001122 > "$SPECTER_DIR/boot_hash"
export MOCK_TEE_HASH=invalid
run_feature boot_hash.sh --refresh >/dev/null
assert_exit_code "failed probe is failure, not random success" 1 "$?"
assert_prop_not_set "stale cache ignored" ro.boot.vbmeta.digest
_setup_boot_hash_env
set_prop ro.boot.vbmeta.digest aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899
run_feature boot_hash.sh --refresh >/dev/null
assert_exit_code "valid existing digest retained" 0 "$?"
assert_prop_eq "fresh probe never overrides existing digest" ro.boot.vbmeta.digest aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899
done_testing
