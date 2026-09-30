plan "lifecycle — first boot preserves state and original snapshots"

bootstrap
source_libs
mk_module teesim TEESimulator
mkdir -p "$TEESIM_DIR"
printf '%s\n' '{"version":1,"profiles":{"default":{"apps":["com.bank.app"]},"work":{"apps":[],"mode":"generation"}}}' > "$TEESIM_CONFIG"
printf '%s' original-keybox > "$TEESIM_KEYBOX"
fixture="$TEST_ROOT/module"
cp -R "$REPO_ROOT/src" "$fixture"
printf 'check_network() { return 0; }\n' > "$fixture/lib/network.sh"
printf 'touch "%s"\n' "$TEST_ROOT/pipeline-ran" > "$fixture/action.sh"
sh "$fixture/features/first_boot_setup.sh" >/dev/null 2>&1
assert_exit_code "first boot succeeds without setup mutations" 0 "$?"
assert_file_not_exists "first boot never runs full pipeline" "$TEST_ROOT/pipeline-ran"
assert_file_eq "keybox preserved" "$TEESIM_KEYBOX" original-keybox
assert_file_exists "full config snapshot namespaced by backend" "$BACKUP_DIR/teesim/original/config"
assert_file_eq "original keybox snapshot exists" "$BACKUP_DIR/teesim/original/keybox" original-keybox
printf '%s' later-keybox > "$TEESIM_KEYBOX"
sh "$fixture/features/first_boot_setup.sh" >/dev/null 2>&1
assert_file_eq "reinstall does not overwrite original snapshot" "$BACKUP_DIR/teesim/original/keybox" original-keybox

bootstrap
source_libs
. "$REPO_ROOT/src/lib/hotinstall.sh"
ROOT_SOL=kernelsu
ROOT_TYPE=KernelSU
MODPATH="${MODULES_BASE}_update/specter"
mkdir -p "$MODULES_BASE/specter" "$MODPATH"
printf '%s' original > "$MODULES_BASE/specter/module.prop"
printf '%s' update > "$MODPATH/module.prop"
ui_print() { :; }
specter_hot_install
assert_file_eq "installation does not hot-replace live module" "$MODULES_BASE/specter/module.prop" original
assert_file_eq "staged update retained for normal root-manager install" "$MODPATH/module.prop" update

done_testing
