plan "uninstall — only unchanged owned settings restored, backups retained"

bootstrap
source_libs
mkdir -p "$BACKUP_DIR"
printf keep > "$BACKUP_DIR/original-secret"
set_prop persist.sys.pixelprops.gms original
sp_force persist.sys.pixelprops.gms specter
assert_prop_eq "owned property actually changed before uninstall" persist.sys.pixelprops.gms specter
set_prop persist.sys.pixelprops.unrelated user-setting
set_prop persist.test.changed original
sp_force persist.test.changed specter
set_prop persist.test.changed newer-owner
sp_force persist.test.created created
PATH="$BIN_DIR:/usr/bin:/bin" sh "$REPO_ROOT/src/uninstall.sh" >/dev/null 2>&1
assert_prop_eq "owned original restored" persist.sys.pixelprops.gms original
assert_prop_eq "unowned setting retained" persist.sys.pixelprops.unrelated user-setting
assert_prop_eq "later owner's value retained" persist.test.changed newer-owner
assert_eq "originally absent owned property removed" "" "$(prop_value persist.test.created)"
assert_file_eq "rollback snapshot retained on uninstall" "$BACKUP_DIR/original-secret" keep

done_testing
