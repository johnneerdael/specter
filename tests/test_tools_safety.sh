plan "tools — destructive operations require explicit consent"

bootstrap
source_libs
set_prop sys.boot_completed 1
mkdir -p "$SPECTER_DIR/log"
printf 'keep' > "$SPECTER_DIR/backup-sentinel"
run_feature cleanup.sh full >/dev/null 2>&1
assert_exit_code "full cleanup refused without consent" 1 "$?"
assert_file_eq "unrelated data retained" "$SPECTER_DIR/backup-sentinel" keep
run_feature hma.sh >/dev/null 2>&1
assert_exit_code "HMA replacement refused without consent" 1 "$?"
set_cfg toggle_action_gms 1
set_cfg toggle_action_gms_clear_data 1
run_feature gms.sh >/dev/null 2>&1
assert_exit_code "GMS data clear refused without consent" 1 "$?"
run_feature kill_play_store.sh >/dev/null 2>&1
assert_exit_code "pipeline Play Store clear refused without consent" 1 "$?"
case " $GMS_KILL_LIST " in *" com.google.android.rkpdapp "*) result=unsafe ;; *) result=safe ;; esac
assert_eq "RKPD excluded from stop targets" safe "$result"

set_cfg keybox_custom_value 'https://private.invalid/key.xml?token=SECRET_EXPORT_SENTINEL'
set_cfg toggle_action_target 0
mkdir -p "$SPECTER_DIR/log"
printf 'SECRET_EXPORT_SENTINEL' > "$SPECTER_DIR/log/action.log"
SPECTER_EXPORT_DIR="$TEST_ROOT/export" run_feature export_logs.sh >/dev/null 2>&1
assert_exit_code "privacy-safe summary export succeeds" 0 "$?"
assert_contains "export includes allowlisted boolean setting" "$(cat "$TEST_ROOT/export/specter_logs.txt" 2>/dev/null)" 'toggle_action_target=0'
assert_not_contains "export excludes private URLs and raw logs" "$(cat "$TEST_ROOT/export/specter_logs.txt" 2>/dev/null)" SECRET_EXPORT_SENTINEL

done_testing
