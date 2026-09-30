plan "boot hash — no fabricated or stale override"

bootstrap
source_libs
set_cfg toggle_boot_hash 1
set_cfg toggle_prop_handler 1
export SPECTER_DEX="$TEST_ROOT/missing.dex"
run_feature boot_hash.sh >/dev/null 2>&1
assert_exit_code "no evidence refuses fabricated digest" 1 "$?"
assert_eq "unknown digest remains absent" "" "$(prop_value ro.boot.vbmeta.digest)"

printf '%064d' 1 > "$SPECTER_DIR/boot_hash"
actual=abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd
set_prop ro.boot.vbmeta.digest "$actual"
run_feature boot_hash.sh >/dev/null 2>&1
assert_prop_eq "stale cache never overrides existing digest" ro.boot.vbmeta.digest "$actual"

mk_module teesim TEESimulator
printf 'teesim|TEESimulator|passive|boot_hash| \n' > "$CONFIG_DIR/conflicts.txt"
set_cfg conflict_teesim priority_module
set_prop ro.boot.vbmeta.digest "$actual"
run_feature boot_hash.sh >/dev/null 2>&1
assert_prop_eq "backend-owned digest untouched" ro.boot.vbmeta.digest "$actual"

done_testing
