plan "packaging — missing required source cannot produce false success"
npm_bin=$(command -v npm)
bootstrap
fixture="$TEST_ROOT/package-fixture"
mkdir -p "$fixture/Module/webroot"
cp "$REPO_ROOT/package.json" "$fixture/package.json"
cp -R "$REPO_ROOT/src" "$fixture/src"
mv "$fixture/src/lib" "$fixture/lib-missing"
(cd "$fixture" && "$npm_bin" run build:module >/dev/null 2>&1)
assert_exit_code "missing required library fails the complete module build" 1 "$?"
done_testing
