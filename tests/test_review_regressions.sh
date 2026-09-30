plan "review regressions — honest action failures and one final transaction commit"
bootstrap
source_libs
mk_module teesim TEESimulator
printf '%s\n' 'teesim|TEESim|passive|target,keybox|' > "$CONFIG_DIR/conflicts.txt"
conflict_resolve_for_feature target
conflict_set_choice teesim priority_module
_conflict_claimed target && ownership=1 || ownership=0
assert_eq "native module selection revokes stale feature grants" 1 "$ownership"

bootstrap
source_libs
mk_module tricky_store 'Tricky Store'
run_feature target.sh --merge >/dev/null
assert_exit_code "missing target file needs one successful final commit" 0 "$?"
assert_contains "missing target file includes selected apps" "$(cat "$TARGET_TXT")" com.dpejoh.specter

bootstrap
source_libs
fixture="$TEST_ROOT/module"
cp -R "$REPO_ROOT/src" "$fixture"
printf '#!/bin/sh\nexit 7\n' > "$fixture/features/keybox.sh"
for diagnostic in keybox_info keystore_info; do
  printf '#!/bin/sh\nexit 0\n' > "$fixture/features/$diagnostic.sh"
done
set_cfg toggle_action_keybox 1
PATH="$BIN_DIR:/usr/bin:/bin" sh "$fixture/action.sh" >/dev/null 2>&1
assert_exit_code "root action propagates refused/failed feature" 1 "$?"
set_cfg toggle_action_keybox 0
set_cfg toggle_action_target 1
mk_module tricky_store 'Tricky Store'
printf '[bank-keybox]\ncom.pinned.bank?\n' > "$TARGET_TXT"
PATH="$BIN_DIR:/usr/bin:/bin" sh "$fixture/action.sh" >/dev/null 2>&1
assert_exit_code "aggregate target merge succeeds" 0 "$?"
assert_contains "aggregate preserves named keybox sections" "$(cat "$TARGET_TXT")" '[bank-keybox]'
assert_contains "aggregate preserves custom per-app states" "$(cat "$TARGET_TXT")" 'com.pinned.bank?'
done_testing
