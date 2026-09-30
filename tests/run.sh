#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT/tests"

TESTS=()
if [ $# -gt 0 ]; then
  for arg; do for f in test_*.sh; do [[ "$f" == *"$arg"* ]] && TESTS+=("$f"); done; done
else
  for f in test_*.sh; do TESTS+=("$f"); done
fi

[ ${#TESTS[@]} -eq 0 ] && echo "No tests found." && exit 1

echo "=============================================="
echo "  Specter Boot Script Test Suite"
echo "=============================================="

failed=0
for tf in "${TESTS[@]}"; do
  [ ! -f "$tf" ] && echo "  SKIP  $tf" && continue
  if ! ( . ./mock_env.sh; . ./helpers.sh; set +e; . "$tf" ); then
    failed=1
  fi
done

echo "=============================================="
exit "$failed"
