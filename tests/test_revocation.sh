plan "revocation — unknown is not clear, every install path is checked"

bootstrap
source_libs
download() { printf '%s' "$response"; }
response='{"entries":{"ab12":{"status":"REVOKED","reason":"KEY_COMPROMISE"}}}'
check_google_revocation ab12
assert_exit_code "revoked serial" 0 "$?"
response='{"entries":{}}'
check_google_revocation ab12
assert_exit_code "valid empty status list is clear" 1 "$?"
response=''
check_google_revocation ab12
assert_exit_code "empty network result unknown" 2 "$?"
response='<html>error</html>'
check_google_revocation ab12
assert_exit_code "error page unknown" 2 "$?"
response='{"entries":'
check_google_revocation ab12
assert_exit_code "truncated status unknown" 2 "$?"
response='{"entries":{},"other":{"ab12":"not an entry"}}'
check_google_revocation ab12
assert_exit_code "serial outside entries is not revoked" 1 "$?"
response='{"entries":{}}'
check_google_revocation '../invalid'
assert_exit_code "invalid serial rejected as unknown" 2 "$?"

done_testing
