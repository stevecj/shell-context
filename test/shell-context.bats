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
printf 'FAKE_SHELL CMD=%s SHELL_CONTEXT=%s START=%s FINAL=%s\n' \
  '$TEST_SHELL' "\${SHELL_CONTEXT-}" "\${SHELL_CONTEXT_START_FILE-}" "\${SHELL_CONTEXT_FINALIZE_FILE-}"
EOF
  chmod +x "$FAKE_BIN/$TEST_SHELL"
}

@test "top-level help is available" {
  run_in_test_shell 'source "$1"; shell-context -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: shell-context <subcommand> [arguments]"* ]]
  [[ "$output" == *"Subcommands:"* ]]
  [[ "$output" == *"Run \`shell-context <subcommand> -h\` for subcommand-specific help."* ]]
}

@test "top-level help is still available when Shell Context is disabled" {
  mkdir -p "$HOME/.config/shell-context"
  : >"$HOME/.config/shell-context/DISABLED"

  run_in_test_shell 'export HOME="$1"; source "$2"; shell-context -h' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: shell-context <subcommand> [arguments]"* ]]
}

@test "unknown subcommands fail with usage output" {
  run_in_test_shell 'source "$1"; shell-context unknown 2>&1' "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown subcommand: unknown"* ]]
  [[ "$output" == *"Usage: shell-context <subcommand> [arguments]"* ]]
  [[ "$output" == *"Subcommands:"* ]]
}

@test "init subcommand help uses the Shell Context name" {
  run_in_test_shell 'source "$1"; shell-context init-start -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Initialize the Shell Context system."* ]]
  [[ "$output" == *"~/.zshrc"* ]]

  run_in_test_shell 'source "$1"; shell-context init-finalize -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Finalize the initialization of the Shell Context system."* ]]
  [[ "$output" == *"~/.zshrc"* ]]
}

@test "subcommand help is still available when Shell Context is disabled" {
  mkdir -p "$HOME/.config/shell-context"
  : >"$HOME/.config/shell-context/DISABLED"

  run_in_test_shell 'export HOME="$1"; source "$2"; shell-context use -h' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: shell-context use <context_name>"* ]]
}

@test "non-help subcommands fail when Shell Context is disabled" {
  mkdir -p "$HOME/.config/shell-context"
  : >"$HOME/.config/shell-context/DISABLED"

  run_in_test_shell 'export HOME="$1"; source "$2"; shell-context init-start 2>&1' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Shell Context is disabled."* ]]
  [[ "$output" == *"$HOME/.config/shell-context/DISABLED"* ]]
}

@test "prompt-title uses the explicit title value" {
  run_in_test_shell 'source "$1"; SHELL_CONTEXT_TITLE=dev; shell-context prompt-title "[%s]" fallback' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[dev]" ]
}

@test "prompt-title falls back to the provided default value" {
  run_in_test_shell 'source "$1"; unset SHELL_CONTEXT_TITLE; shell-context prompt-title "[%s]" fallback' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[fallback]" ]
}

@test "init-start loads the default context-start file" {
  mkdir -p "$HOME/.config/shell-context/contexts"
  printf 'export TEST_FLAG=loaded\n' >"$HOME/.config/shell-context/contexts/_default.context-start"

  run_in_test_shell 'export HOME="$1"; source "$2"; unset SHELL_CONTEXT TEST_FLAG; SHELL_CONTEXT_PRE_PATH=/usr/bin:/bin; shell-context init-start; printf "%s|%s" "$TEST_FLAG" "$SHELL_CONTEXT_START_FILE"' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "loaded|$HOME/.config/shell-context/contexts/_default.context-start" ]
}

@test "use rejects missing named contexts" {
  run_in_test_shell 'export HOME="$1"; source "$2"; shell-context use missing 2>&1' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"No context-start file found for 'missing'"* ]]
}

@test "use-local reports when no local context exists" {
  mkdir -p "$BATS_TEST_TMPDIR/work"

  run_in_test_shell 'export HOME="$1"; source "$2"; cd "$3"; shell-context use-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No .shell-context file found and no context currently loaded."* ]]
}

@test "use-local errors when the discovered .shell-context file is empty" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  : >"$BATS_TEST_TMPDIR/project/.shell-context"

  run_in_test_shell 'export HOME="$1"; source "$2"; cd "$3"; shell-context use-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/project"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Context file $BATS_TEST_TMPDIR/project/.shell-context is empty."* ]]
}

@test "use-local short-circuits when the requested context is already active" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.shell-context"

  run_in_test_shell 'export HOME="$1"; source "$2"; export SHELL_CONTEXT=demo; cd "$3"; shell-context use-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/project"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Already in context 'demo'."* ]]
}

@test "use-local finds the nearest .shell-context file and launches that context in the current shell" {
  install_fake_shell
  mkdir -p "$HOME/.config/shell-context/contexts" "$BATS_TEST_TMPDIR/project/child"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.shell-context"
  : >"$HOME/.config/shell-context/contexts/demo.context-start"

  run_in_test_shell 'export HOME="$1"; export PATH="$3:$PATH"; source "$2"; cd "$4/project/child"; shell-context use-local 2>&1' "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Entering context 'demo'..."* ]]
  [[ "$output" == *"FAKE_SHELL CMD=$TEST_SHELL SHELL_CONTEXT=demo START=$HOME/.config/shell-context/contexts/demo.context-start FINAL="* ]]
}
