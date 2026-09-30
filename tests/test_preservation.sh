plan "preservation — defaults, conflicts and read-only backend detection"

bootstrap
source_libs
_apply_toggle_defaults
for feature in prop_handler boot_state_props bootmode_spoof rom_fingerprint pif_props target pif keybox gms auto_target autopif autokeybox; do
  _feature_should_run "$feature" && result=run || result=skip
  assert_eq "fresh install does not run $feature" skip "$result"
done
set_cfg toggle_action_pif 1
_feature_should_run pif && result=run || result=skip
assert_eq "explicit action selection preserved" run "$result"

mk_module danger "Untrusted legacy module"
printf 'danger|Legacy|aggressive|keybox,target|\n' > "$CONFIG_DIR/conflicts.txt"
printf '#!/bin/sh\ntouch "%s"\n' "$TEST_ROOT/uninstaller-ran" > "$MODULES_BASE/danger/uninstall.sh"
resolve_conflicts
assert_file_exists "conflicts never delete another module" "$MODULES_BASE/danger/module.prop"
assert_file_not_exists "conflicts never execute another uninstaller" "$TEST_ROOT/uninstaller-ran"
set_cfg toggle_action_keybox 1
_feature_should_run keybox && result=run || result=skip
assert_eq "detected overlap defaults to other module ownership" skip "$result"
touch "$MODULES_BASE/danger/disable"
_conflict_detect danger && result=yes || result=no
assert_eq "disabled module is not an active conflict" no "$result"
set_cfg conflict_danger priority_module
printf 'danger|Legacy|passive|keybox|\n' > "$CONFIG_DIR/conflicts.txt"
rm -f "$MODULES_BASE/danger/disable"
conflict_resolve_for_feature target
assert_file_eq "claiming target does not steal unrelated keybox ownership" "$CONFIG_DIR/val/conflict_danger.val" priority_module

bootstrap
source_libs
mk_module teesim TEESimulator
mk_module tricky_store "Tricky Store"
ksm_enforce_singleton >/dev/null 2>&1
assert_file_not_exists "detection never disables TEESimulator" "$MODULES_BASE/teesim/disable"
assert_file_not_exists "detection never disables Tricky Store" "$MODULES_BASE/tricky_store/disable"
detect_keystore_manager
assert_eq "ambiguous auto selection refuses a writer" none "$KSM"
set_cfg keystore_manager teesim
detect_keystore_manager
assert_eq "explicit enabled selection accepted" teesim "$KSM"
touch "$MODULES_BASE/teesim/disable"
detect_keystore_manager
assert_eq "explicit disabled selection rejected" none "$KSM"
rm -f "$MODULES_BASE/teesim/disable"
touch "$MODULES_BASE/teesim/remove"
detect_keystore_manager
assert_eq "pending removal selection rejected" none "$KSM"

bootstrap
source_libs
mk_module teesim TEESimulator
printf '%s\n' 'teesim|TEESim|passive|target,keybox|' > "$CONFIG_DIR/conflicts.txt"
conflict_resolve_for_feature target
_conflict_claimed keybox && claimed=1 || claimed=0
assert_eq "per-feature selection retains other ownership within same backend" 1 "$claimed"
_conflict_claimed target && claimed=1 || claimed=0
assert_eq "per-feature target handoff is explicit" 0 "$claimed"
done_testing
