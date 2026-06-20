#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
supported_shells=(bash zsh)

usage() {
  cat <<'EOF'
Usage: test/run.bash [--shell bash|zsh] [bats arguments...]
Usage: test/run.bash -h

Run the Bats suite against one or more supported shells.

Options:
  --shell SHELL  Run tests only for the given shell. Repeat to run a subset.
  -h             Show this usage output and return.
EOF
}

validate_shell() {
  local shell_name=$1
  local supported

  for supported in "${supported_shells[@]}"; do
    if [[ $shell_name == "$supported" ]]; then
      return 0
    fi
  done

  echo "Unsupported shell for tests: $shell_name" >&2
  return 1
}

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

selected_shells=()
bats_args=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    --shell)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--shell requires an argument" >&2
        exit 1
      fi
      validate_shell "$1"
      selected_shells+=("$1")
      ;;
    --shell=*)
      validate_shell "${1#--shell=}"
      selected_shells+=("${1#--shell=}")
      ;;
    --)
      shift
      bats_args+=("$@")
      break
      ;;
    *)
      bats_args+=("$1")
      ;;
  esac
  shift
done

if [[ ${#bats_args[@]} -eq 0 ]]; then
  bats_args=("$script_dir")
fi

if [[ ${#selected_shells[@]} -eq 0 ]]; then
  for shell_name in "${supported_shells[@]}"; do
    if command -v "$shell_name" >/dev/null 2>&1; then
      selected_shells+=("$shell_name")
    fi
  done
fi

if [[ ${#selected_shells[@]} -eq 0 ]]; then
  echo "No supported test shells are installed. Expected bash or zsh." >&2
  exit 1
fi

for shell_name in "${selected_shells[@]}"; do
  echo "Running tests with $shell_name..."
  TEST_SHELL="$shell_name" bats "${bats_args[@]}"
done
