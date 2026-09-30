plan "runner — assertion failures must fail CI"

bootstrap
fixture="$TEST_ROOT/runner/tests"
mkdir -p "$fixture"
cp "$REPO_ROOT/tests/run.sh" "$fixture/run.sh"
: > "$fixture/mock_env.sh"
cp "$REPO_ROOT/tests/helpers.sh" "$fixture/helpers.sh"
printf 'assert_eq "failure fixture" expected actual\ndone_testing\n' > "$fixture/test_failure.sh"
printf 'exit 0\n' > "$fixture/test_later_pass.sh"
bash "$fixture/run.sh" >/dev/null 2>&1
assert_exit_code "nonzero test makes runner nonzero" 1 "$?"
printf 'exit 0\n' > "$fixture/test_failure.sh"
bash "$fixture/run.sh" >/dev/null 2>&1
assert_exit_code "passing fixture accepted" 0 "$?"

done_testing
