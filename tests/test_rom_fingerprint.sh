plan "ROM properties — actual entrypoint preserves unknown settings, journals explicit edits"
bootstrap
source_libs
set_cfg toggle_rom_fingerprint 1
set_cfg toggle_rom_fingerprint_names 1
set_cfg toggle_rom_fingerprint_prefix 0
set_cfg toggle_rom_fingerprint_build_type 0
set_prop ro.build.display.id lineage_rom
set_prop vendor.camera.aux.packagelist org.lineageos.aperture
set_prop init.svc.vendor.lineage_health running
set_prop persist.sys.xposed 1
run_feature rom_fingerprint.sh >/dev/null
assert_prop_eq "broad ROM deletion disabled" ro.build.display.id lineage_rom
assert_prop_eq "camera access preserved" vendor.camera.aux.packagelist org.lineageos.aperture
assert_prop_eq "vendor service not stopped" init.svc.vendor.lineage_health running
assert_prop_eq "unrelated root setting preserved" persist.sys.xposed 1
set_cfg toggle_rom_fingerprint_prefix 1
run_feature rom_fingerprint.sh >/dev/null
assert_prop_eq "explicit prefix edit works" ro.build.display.id rom
assert_file_exists "explicit prefix edit journalled" "$SPECTER_DIR/property-journal/ro.build.display.id/original"
sp_restore_owned
assert_prop_eq "owned prefix edit restored" ro.build.display.id lineage_rom
set_cfg toggle_rom_fingerprint 0
run_feature rom_fingerprint.sh >/dev/null
assert_prop_eq "master off unchanged" ro.build.display.id lineage_rom
set_prop ro.build.flavor lineage_userdebug
spoof_build_props
assert_prop_eq "helper flavor edit" ro.build.flavor lineage_user
assert_file_exists "helper edit journalled" "$SPECTER_DIR/property-journal/ro.build.flavor/original"
done_testing
