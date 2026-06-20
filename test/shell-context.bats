#!/usr/bin/env bats

SCRIPT_PATH="$BATS_TEST_DIRNAME/../src/shell-context.sh"
TEST_SHELL="${TEST_SHELL:-bash}"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export FAKE_BIN="$BATS_TEST_TMPDIR/bin"

  mkdir -p "$HOME" "$FAKE_BIN"

  if ! command -v "$TEST_SHELL" >/dev/null 2>&1; then
    skip "test shell '$TEST_SHELL' is not installed"
  fi
}

run_in_test_shell() {
  local command=$1
  shift
  run "$TEST_SHELL" -lc "$command" _ "$@"
}

install_fake_shell() {
  cat >"$FAKE_BIN/$TEST_SHELL" <<EOF
#!/bin/sh
printf 'FAKE_SHELL CMD=%s INCONTEXT=%s START=%s FINAL=%s\n' \
  '$TEST_SHELL' "\${INCONTEXT-}" "\${INCONTEXT_START_FILE-}" "\${INCONTEXT_FINALIZE_FILE-}"
EOF
  chmod +x "$FAKE_BIN/$TEST_SHELL"
}

@test "top-level help is available" {
  run_in_test_shell 'source "$1"; in-context -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: in-context <subcommand> [arguments]"* ]]
  [[ "$output" == *"Shell Context project."* ]]
  [[ "$output" == *"~/.zshrc"* ]]
}

@test "unknown subcommands fail with usage output" {
  run_in_test_shell 'source "$1"; in-context unknown 2>&1' "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown subcommand: unknown"* ]]
  [[ "$output" == *"Usage: in-context <subcommand> [arguments]"* ]]
  [[ "$output" == *"Shell Context project."* ]]
}

@test "init subcommand help uses the Shell Context name" {
  run_in_test_shell 'source "$1"; in-context init-start -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Initialize the Shell Context system."* ]]
  [[ "$output" == *"~/.zshrc"* ]]

  run_in_test_shell 'source "$1"; in-context init-finalize -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Finalize the initialization of the Shell Context system."* ]]
  [[ "$output" == *"~/.zshrc"* ]]
}

@test "prompt-title uses the explicit title value" {
  run_in_test_shell 'source "$1"; INCONTEXT_TITLE=dev; in-context prompt-title "[%s]" fallback' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[dev]" ]
}

@test "prompt-title falls back to the provided default value" {
  run_in_test_shell 'source "$1"; unset INCONTEXT_TITLE; in-context prompt-title "[%s]" fallback' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[fallback]" ]
}

@test "init-start loads the default context-start file" {
  mkdir -p "$HOME/.config/in-context/contexts"
  printf 'export TEST_FLAG=loaded\n' >"$HOME/.config/in-context/contexts/_default.context-start"

  run_in_test_shell 'export HOME="$1"; source "$2"; unset INCONTEXT TEST_FLAG; INCONTEXT_PRE_PATH=/usr/bin:/bin; in-context init-start; printf "%s|%s" "$TEST_FLAG" "$INCONTEXT_START_FILE"' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "loaded|$HOME/.config/in-context/contexts/_default.context-start" ]
}

@test "use rejects missing named contexts" {
  run_in_test_shell 'export HOME="$1"; source "$2"; in-context use missing 2>&1' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"No context-start file found for 'missing'"* ]]
}

@test "use-local reports when no local context exists" {
  mkdir -p "$BATS_TEST_TMPDIR/work"

  run_in_test_shell 'export HOME="$1"; source "$2"; cd "$3"; in-context use-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No .incontext file found and no context currently loaded."* ]]
}

@test "use-local errors when the discovered .incontext file is empty" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  : >"$BATS_TEST_TMPDIR/project/.incontext"

  run_in_test_shell 'export HOME="$1"; source "$2"; cd "$3"; in-context use-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/project"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Context file $BATS_TEST_TMPDIR/project/.incontext is empty."* ]]
}

@test "use-local short-circuits when the requested context is already active" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.incontext"

  run_in_test_shell 'export HOME="$1"; source "$2"; export INCONTEXT=demo; cd "$3"; in-context use-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/project"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Already in context 'demo'."* ]]
}

@test "use-local finds the nearest .incontext file and launches that context in the current shell" {
  install_fake_shell
  mkdir -p "$HOME/.config/in-context/contexts" "$BATS_TEST_TMPDIR/project/child"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.incontext"
  : >"$HOME/.config/in-context/contexts/demo.context-start"

  run_in_test_shell 'export HOME="$1"; export PATH="$3:$PATH"; source "$2"; cd "$4/project/child"; in-context use-local 2>&1' "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Entering context 'demo'..."* ]]
  [[ "$output" == *"FAKE_SHELL CMD=$TEST_SHELL INCONTEXT=demo START=$HOME/.config/in-context/contexts/demo.context-start FINAL="* ]]
}
