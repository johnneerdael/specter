plan "unsupported mutation paths — refuse without touching user state"
bootstrap
source_libs
mk_module teesim TEESimulator
mkdir -p "$TEESIM_DIR"
printf '%s' original > "$TEESIM_KEYBOX"
printf '%s' '{"version":1,"profiles":{"default":{"apps":[]}}}' > "$TEESIM_CONFIG"
detect_keystore_manager
printf '%s' candidate > "$TEST_ROOT/candidate"
# Even a substituted validator must not reopen an unvalidated installer.
keybox_validate_candidate() { return 0; }
ksm_install_keybox "$TEST_ROOT/candidate" copy >/dev/null 2>&1
assert_exit_code "unvalidated candidate installation refused" 1 "$?"
assert_file_eq "existing keybox preserved" "$TEESIM_KEYBOX" original
mkdir -p "$BACKUP_DIR"
printf '%s' other-backend > "$BACKUP_DIR/target.txt.bak"
run_feature restore_backups.sh --confirmed >/dev/null
assert_exit_code "legacy cross-backend restoration refused" 1 "$?"
run_feature hma.sh --confirmed >/dev/null
assert_exit_code "unvalidated HMA scope replacement refused" 1 "$?"
done_testing
