plan "hotinstall — no live replacement, even with legacy opt-in"
. "$REPO_ROOT/src/lib/hotinstall.sh"
for root_kind in magisk kernelsu apatch; do
  for preference in 0 1; do
    bootstrap
    source_libs
    ROOT_SOL="$root_kind"
    set_cfg toggle_hot_install "$preference"
    MODPATH="${MODULES_BASE}_update/specter"
    mkdir -p "$MODULES_BASE/specter" "$MODPATH"
    printf '%s' old > "$MODULES_BASE/specter/module.prop"
    printf '%s' new > "$MODPATH/module.prop"
    printf 'touch "%s"\n' "$TEST_ROOT/executed" > "$MODPATH/hotinstall.sh"
    ui_print() { :; }
    specter_hot_install
    assert_file_eq "live unchanged ($root_kind/$preference)" "$MODULES_BASE/specter/module.prop" old
    assert_file_eq "staging preserved ($root_kind/$preference)" "$MODPATH/module.prop" new
    assert_file_not_exists "no live executor ($root_kind/$preference)" "$TEST_ROOT/executed"
  done
done
sh "$REPO_ROOT/src/hotinstall.sh" >/dev/null 2>&1
assert_exit_code "direct hot-apply refused" 1 "$?"
sh "$REPO_ROOT/scripts/deploy-module.sh" >/dev/null 2>&1
assert_exit_code "direct adb deployment refused" 1 "$?"
done_testing
