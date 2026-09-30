plan "atomic writes — metadata preserved, locks fail closed"

bootstrap
source_libs
printf 'original' > "$TEST_ROOT/destination"
chmod 640 "$TEST_ROOT/destination"
printf 'updated' > "$TEST_ROOT/source"
specter_atomic_copy "$TEST_ROOT/source" "$TEST_ROOT/destination"
assert_exit_code "atomic copy succeeds" 0 "$?"
assert_file_eq "complete replacement written" "$TEST_ROOT/destination" updated
permission=$(ls -l "$TEST_ROOT/destination" | cut -c1-10)
assert_eq "permissions preserved" -rw-r----- "$permission"
ln -s "$TEST_ROOT/destination" "$TEST_ROOT/symlink"
specter_atomic_copy "$TEST_ROOT/source" "$TEST_ROOT/symlink"
assert_exit_code "symlink target refused" 1 "$?"

mk_module teesim TEESimulator
mkdir -p "$TEESIM_DIR" "$SPECTER_DIR/.lock/teesim"
detect_keystore_manager
specter_backend_edit target touch "$TEST_ROOT/should-not-run"
assert_exit_code "existing transaction lock blocks another writer" 1 "$?"
assert_file_not_exists "blocked writer has no side effect" "$TEST_ROOT/should-not-run"
test -d "$SPECTER_DIR/.lock/teesim"
assert_exit_code "unknown lock not stolen/deleted" 0 "$?"

done_testing
