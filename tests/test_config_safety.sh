plan "config — unsupported input is never silently rewritten"

bootstrap
source_libs
mkdir -p "$TEESIM_DIR"
for unsupported in \
  '{"version":1,"profiles":{"default":{"apps":false}}}' \
  '{"version":1,"profiles":{"default":{"patchLevel":"bad","apps":[]}}}' \
  '{"version":1,"profiles":{"default":{"apps":[1]}}}' \
  '{"version":1,"profiles":{},"version":1}' \
  '{"version":2,"profiles":{"default":{"apps":["com.bank.app"]}}}' \
  '{"version":1,"profiles":{"default":{"apps":["com.bank.app"],"future":{"secret":"keep"}}}}' \
  '{"version":1,"profiles":{"default":{"apps":["com.bank.app"]}},"nested":{"secret":"keep"}}' \
  '{"version":1,"profiles":{"default":{"apps":["com.bank.app"]}}'; do
  printf '%s' "$unsupported" > "$TEESIM_CONFIG"
  cp "$TEESIM_CONFIG" "$TEST_ROOT/original"
  _teesim_set_mode "$TEESIM_CONFIG" generation >/dev/null 2>&1
  assert_exit_code "unsupported/malformed schema refused" 1 "$?"
  cmp -s "$TEESIM_CONFIG" "$TEST_ROOT/original"
  assert_exit_code "original bytes unchanged on refusal" 0 "$?"
done
printf '%s' '{"version":1,"profiles":{"default":{"apps":["com.bank.app"]},"empty":{"mode":"patch","apps":[]}},"lastFlag":true}' > "$TEESIM_CONFIG"
_teesim_set_mode "$TEESIM_CONFIG" generation
assert_exit_code "known schema update succeeds" 0 "$?"
assert_contains "requested mode actually applied to sparse profile" "$(cat "$TEESIM_CONFIG")" '"mode": "generation"'
assert_contains "empty profile preserved" "$(cat "$TEESIM_CONFIG")" '"empty"'
assert_contains "top-level scalar after profiles preserved" "$(cat "$TEESIM_CONFIG")" '"lastFlag": true'
printf '%s' '{"version":1,"profiles":{"bank":{"apps":[]}}}' > "$TEESIM_CONFIG"
mkdir -p "$MODULES_BASE/teesim"
printf '%s' '{"version":1,"profiles":{}}' > "$MODULES_BASE/teesim/config.default.json"
cp "$TEESIM_CONFIG" "$TEST_ROOT/original"
_teesim_set_mode "$TEESIM_CONFIG" generation >/dev/null 2>&1
assert_exit_code "seed without default profile is refused" 1 "$?"
cmp -s "$TEESIM_CONFIG" "$TEST_ROOT/original"
assert_exit_code "missing-default refusal preserves source" 0 "$?"

done_testing
