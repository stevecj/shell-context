#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v bats >/dev/null 2>&1; then
  cat >&2 <<'EOF'
bats-core is required to run this test suite.

Install bats-core, then rerun:
  bats test
or:
  test/run.bash
EOF
  exit 1
fi

if [[ $# -eq 0 ]]; then
  set -- "$script_dir"
fi

exec bats "$@"
