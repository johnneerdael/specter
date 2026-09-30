plan "process cleanup — stale PID must never signal a different process"

bootstrap
source_libs
export SPECTER_PROC_ROOT="$TEST_ROOT/proc"
mkdir -p "$SPECTER_PROC_ROOT/1234"
printf '1234' > "$TEST_ROOT/worker.pid"
printf 'sh\0/unrelated/scheduler.sh\0' > "$SPECTER_PROC_ROOT/1234/cmdline"
printf '1234 (sh) S 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 42\n' > "$SPECTER_PROC_ROOT/1234/stat"
specter_stop_pid_file "$TEST_ROOT/worker.pid" "$REPO_ROOT/src/lib/scheduler.sh"
assert_exit_code "unrelated scheduler rejected" 1 "$?"
printf '0' > "$TEST_ROOT/worker.pid"
specter_stop_pid_file "$TEST_ROOT/worker.pid" "$REPO_ROOT/src/lib/scheduler.sh"
assert_exit_code "process-group PID rejected" 1 "$?"
printf '%s' '-1' > "$TEST_ROOT/worker.pid"
specter_stop_pid_file "$TEST_ROOT/worker.pid" "$REPO_ROOT/src/lib/scheduler.sh"
assert_exit_code "negative PID rejected" 1 "$?"

done_testing
