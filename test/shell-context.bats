#!/usr/bin/env bats

SCRIPT_PATH="$BATS_TEST_DIRNAME/../src/shell-context.sh"
TEST_SHELL="${TEST_SHELL:-bash}"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  export REAL_TEST_SHELL="$(command -v "$TEST_SHELL")"

  mkdir -p "$HOME" "$FAKE_BIN"

  if [[ -z "$REAL_TEST_SHELL" ]]; then
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
#!$REAL_TEST_SHELL
printf 'FAKE_SHELL CMD=%s SHELL_CONTEXT=%s START=%s FINAL=%s PREVIOUS=%s DEPTH=%s\n' \\
  '$TEST_SHELL'\\
  "\${SHELL_CONTEXT-}" \\
  "\${SHELL_CONTEXT_START_FILE-}" \\
  "\${SHELL_CONTEXT_FINALIZE_FILE-}" \\
  "\${SHELL_CONTEXT_PREVIOUS_CONTEXT-}" \\
  "\${SHELL_CONTEXT_DEPTH-}"
if [[ -n "\${FAKE_SHELL_INIT_START_SCRIPT-}" ]]; then
  . "\$FAKE_SHELL_INIT_START_SCRIPT"
  shell-context init-start || exit \$?
  printf 'FAKE_INIT SHELL_CONTEXT=%s TITLE=%s PREVIOUS=%s DEPTH=%s TEST_FLAG=%s\n' \\
    "\${SHELL_CONTEXT-}" \\
    "\${SHELL_CONTEXT_TITLE-}" \\
    "\${SHELL_CONTEXT_PREVIOUS_CONTEXT-}" \\
    "\${SHELL_CONTEXT_DEPTH-}" \\
    "\${TEST_FLAG-}"
fi
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

  run_in_test_shell \
    'export HOME="$1"; source "$2"; shell-context -h' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: shell-context <subcommand> [arguments]"* ]]
}

@test "version output is still available when Shell Context is disabled" {
  mkdir -p "$HOME/.config/shell-context"
  : >"$HOME/.config/shell-context/DISABLED"

  run_in_test_shell \
    'export HOME="$1"; source "$2"; shell-context -v' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9][.][0-9][.][0-9]$ ]]

  run_in_test_shell \
    'export HOME="$1"; source "$2"; shell-context version' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9][.][0-9][.][0-9]$ ]]
}

@test "unknown subcommands fail with usage output" {
  run_in_test_shell \
    'source "$1"; shell-context unknown 2>&1' "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown subcommand: unknown"* ]]
  [[ "$output" == *"Usage: shell-context <subcommand> [arguments]"* ]]
  [[ "$output" == *"Subcommands:"* ]]
}

@test "init subcommand help uses the Shell Context name" {
  run_in_test_shell \
    'source "$1"; shell-context init-start -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Initialize the Shell Context system."* ]]
  [[ "$output" == *"~/.zshrc"* ]]

  run_in_test_shell \
    'source "$1"; shell-context init-finalize -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Finalize the initialization of the Shell Context system."* ]]
  [[ "$output" == *"~/.zshrc"* ]]
}

@test "auto-local help is available via both the subcommand and the direct hook function" {
  run_in_test_shell \
    'source "$1"; shell-context auto-local -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: shell-context auto-local"* ]]
  [[ "$output" == *"Usage: shell_context_auto_local"* ]]

  run_in_test_shell \
    'source "$1"; shell_context_auto_local -h' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: shell-context auto-local"* ]]
  [[ "$output" == *"Usage: shell_context_auto_local"* ]]
}

@test "init-finalize wires the public auto-local hook function" {
  run_in_test_shell \
    'source "$1"; SHELL_CONTEXT_AUTO=2; shell-context init-finalize; if [[ -n ${BASH_VERSION-} ]]; then printf "%s" "$PROMPT_COMMAND"; else printf "%s" "${precmd_functions[*]-}"; fi' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"shell_context_auto_local"* ]]
}

@test "init-finalize does not wire the auto-local hook when SHELL_CONTEXT_AUTO is zero" {
  run_in_test_shell \
    'source "$1"; SHELL_CONTEXT_AUTO=0; shell-context init-finalize; if [[ -n ${BASH_VERSION-} ]]; then printf "%s" "${PROMPT_COMMAND-}"; else printf "%s" "${precmd_functions[*]-}"; fi' "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" != *"shell_context_auto_local"* ]]
}

@test "subcommand help is still available when Shell Context is disabled" {
  mkdir -p "$HOME/.config/shell-context"
  : >"$HOME/.config/shell-context/DISABLED"

  run_in_test_shell \
    'export HOME="$1"; source "$2"; shell-context load -h' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: shell-context load <context_name>"* ]]
}

@test "non-help subcommands fail when Shell Context is disabled" {
  mkdir -p "$HOME/.config/shell-context"
  : >"$HOME/.config/shell-context/DISABLED"

  run_in_test_shell \
    'export HOME="$1"; source "$2"; shell-context init-start 2>&1' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Shell Context is disabled."* ]]
  [[ "$output" == *"$HOME/.config/shell-context/DISABLED"* ]]
}

@test "prompt-title uses the explicit title value" {
  run_in_test_shell \
    'source "$1"; SHELL_CONTEXT_TITLE=dev; shell-context prompt-title -n "[%s]" fallback' \
    "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[dev]" ]
}

@test "prompt-title falls back to the provided default value" {
  run_in_test_shell \
    'source "$1"; unset SHELL_CONTEXT_TITLE; shell-context prompt-title -n "[%s]" fallback' \
    "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[fallback]" ]
}

@test "prompt-title appends depth when the context depth is at least two" {
  run_in_test_shell \
    'source "$1"; SHELL_CONTEXT_TITLE=dev; SHELL_CONTEXT_DEPTH=2; shell-context prompt-title -n "[%s]"' \
    "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[dev (2)]" ]
}

@test "prompt-title supports custom depth formatting and minimum depth" {
  run_in_test_shell \
    'source "$1"; SHELL_CONTEXT_TITLE=dev; SHELL_CONTEXT_DEPTH=1; shell-context prompt-title -n "[%s]" -d " <%s>" -D 1' \
    "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[dev <1>]" ]
}

@test "init-start loads the default context-start file and initializes depth to zero" {
  mkdir -p "$HOME/.config/shell-context/contexts"
  printf 'export TEST_FLAG=loaded\n' \
    >"$HOME/.config/shell-context/contexts/_default.context-start"

  run_in_test_shell \
    'export HOME="$1"; source "$2"; unset SHELL_CONTEXT TEST_FLAG SHELL_CONTEXT_DEPTH; SHELL_CONTEXT_PRE_PATH=/usr/bin:/bin; shell-context init-start; printf "%s|%s|%s" "$TEST_FLAG" "$SHELL_CONTEXT_START_FILE" "$SHELL_CONTEXT_DEPTH"'\
     "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "loaded|$HOME/.config/shell-context/contexts/_default.context-start|0" ]
}

@test "load rejects missing named contexts" {
  run_in_test_shell \
    'export HOME="$1"; source "$2"; shell-context load missing 2>&1' "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"No context-start file found for 'missing'"* ]]
}

@test "load passes depth 1 when entering the first context shell" {
  install_fake_shell
  mkdir -p "$HOME/.config/shell-context/contexts"
  : >"$HOME/.config/shell-context/contexts/demo.context-start"

  run_in_test_shell \
    'export HOME="$1"; export PATH="$3:$PATH"; export FAKE_SHELL_INIT_START_SCRIPT="$2"; source "$2"; shell-context load demo 2>&1' \
    "$HOME" "$SCRIPT_PATH" "$FAKE_BIN"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Entering context 'demo'..."* ]]
  [[ "$output" == *"FAKE_SHELL CMD=$TEST_SHELL SHELL_CONTEXT=demo START=$HOME/.config/shell-context/contexts/demo.context-start FINAL= PREVIOUS= DEPTH=1"* ]]
  [[ "$output" == *"FAKE_INIT SHELL_CONTEXT=demo TITLE=demo PREVIOUS= DEPTH=1 TEST_FLAG="* ]]
}

@test "load passes the previous context to a nested child shell and leaves the parent shell unchanged" {
  install_fake_shell
  mkdir -p "$HOME/.config/shell-context/contexts"
  : >"$HOME/.config/shell-context/contexts/current.context-start"
  printf 'printf cleaned >"$CLEANUP_MARKER"\n' >"$HOME/.config/shell-context/contexts/current.context-cleanup"
  printf 'export TEST_FLAG=next-loaded\n' >"$HOME/.config/shell-context/contexts/next.context-start"
  local cleanup_marker="$BATS_TEST_TMPDIR/current-cleanup.marker"

  run_in_test_shell \
    'export HOME="$1"; export PATH="$3:$PATH"; export CLEANUP_MARKER="$4"; export FAKE_SHELL_INIT_START_SCRIPT="$2"; export SHELL_CONTEXT=current; export SHELL_CONTEXT_DEPTH=1; export PARENT_FLAG=original; source "$2"; shell-context load next 2>&1; printf "PARENT_FLAG=%s" "$PARENT_FLAG"'\
     "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$cleanup_marker"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Entering context 'next'..."* ]]
  [[ "$output" == *"FAKE_SHELL CMD=$TEST_SHELL SHELL_CONTEXT=next START=$HOME/.config/shell-context/contexts/next.context-start FINAL= PREVIOUS=current DEPTH=2"* ]]
  [[ "$output" == *"FAKE_INIT SHELL_CONTEXT=next TITLE=next PREVIOUS= DEPTH=2 TEST_FLAG=next-loaded"* ]]
  [[ "$output" == *"PARENT_FLAG=original"* ]]
  [ "$(cat "$cleanup_marker")" = "cleaned" ]
}

@test "load falls back to the default cleanup file during child initialization" {
  install_fake_shell
  mkdir -p "$HOME/.config/shell-context/contexts"
  printf 'printf default-cleanup >"$CLEANUP_MARKER"\n' >"$HOME/.config/shell-context/contexts/_default.context-cleanup"
  : >"$HOME/.config/shell-context/contexts/current.context-start"
  printf 'export TEST_FLAG=next-loaded\n' >"$HOME/.config/shell-context/contexts/next.context-start"
  local cleanup_marker="$BATS_TEST_TMPDIR/default-cleanup.marker"

  run_in_test_shell \
    'export HOME="$1"; export PATH="$3:$PATH"; export CLEANUP_MARKER="$4"; export FAKE_SHELL_INIT_START_SCRIPT="$2"; export SHELL_CONTEXT=current; export SHELL_CONTEXT_DEPTH=1; source "$2"; shell-context load next 2>&1' "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$cleanup_marker"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Entering context 'next'..."* ]]
  [[ "$output" == *"FAKE_SHELL CMD=$TEST_SHELL SHELL_CONTEXT=next START=$HOME/.config/shell-context/contexts/next.context-start FINAL= PREVIOUS=current DEPTH=2"* ]]
  [[ "$output" == *"FAKE_INIT SHELL_CONTEXT=next TITLE=next PREVIOUS= DEPTH=2 TEST_FLAG=next-loaded"* ]]
  [ "$(cat "$cleanup_marker")" = "default-cleanup" ]
}

@test "load-local reports when no local context exists" {
  mkdir -p "$BATS_TEST_TMPDIR/work"

  run_in_test_shell \
    'export HOME="$1"; source "$2"; cd "$3"; shell-context load-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No .shell-context file found and no context currently loaded."* ]]
}

@test "load-local enters a nested default context when no local context exists for a loaded context" {
  install_fake_shell
  mkdir -p "$HOME/.config/shell-context/contexts" "$BATS_TEST_TMPDIR/work"
  : >"$HOME/.config/shell-context/contexts/current.context-start"
  printf 'export PARENT_FLAG=cleaned-parent\nprintf cleaned >"$CLEANUP_MARKER"\n' >"$HOME/.config/shell-context/contexts/current.context-cleanup"
  local cleanup_marker="$BATS_TEST_TMPDIR/nested-default-cleanup.marker"

  run_in_test_shell \
    'export HOME="$1"; export PATH="$3:$PATH"; export SHELL_CONTEXT=current; export SHELL_CONTEXT_START_FILE="$HOME/.config/shell-context/contexts/current.context-start"; export SHELL_CONTEXT_DEPTH=1; export CLEANUP_MARKER="$5"; export FAKE_SHELL_INIT_START_SCRIPT="$2"; export PARENT_FLAG=original; cd "$4"; source "$2"; shell-context load-local 2>&1; printf "PARENT_FLAG=%s" "$PARENT_FLAG"' "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$BATS_TEST_TMPDIR/work" "$cleanup_marker"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No .shell-context file found. Entering nested default context."* ]]
  [[ "$output" == *"FAKE_SHELL CMD=$TEST_SHELL SHELL_CONTEXT= START= FINAL= PREVIOUS=current DEPTH=2"* ]]
  [[ "$output" == *"FAKE_INIT SHELL_CONTEXT= TITLE= PREVIOUS= DEPTH=2 TEST_FLAG="* ]]
  [[ "$output" == *"PARENT_FLAG=original"* ]]
  [ "$(cat "$cleanup_marker")" = "cleaned" ]
}

@test "load-local errors when the discovered .shell-context file is empty" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  : >"$BATS_TEST_TMPDIR/project/.shell-context"

  run_in_test_shell \
    'export HOME="$1"; source "$2"; cd "$3"; shell-context load-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/project"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Context file $BATS_TEST_TMPDIR/project/.shell-context is empty."* ]]
}

@test "load-local short-circuits when the requested context is already active" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.shell-context"

  run_in_test_shell \
    'export HOME="$1"; source "$2"; export SHELL_CONTEXT=demo; cd "$3"; shell-context load-local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/project"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Already in context 'demo'."* ]]
}

@test "load-local finds the nearest .shell-context file and launches that context in the current shell" {
  install_fake_shell
  mkdir -p "$HOME/.config/shell-context/contexts" "$BATS_TEST_TMPDIR/project/child"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.shell-context"
  : >"$HOME/.config/shell-context/contexts/demo.context-start"

  run_in_test_shell \
    'export HOME="$1"; export PATH="$3:$PATH"; source "$2"; cd "$4/project/child"; shell-context load-local 2>&1' "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Entering context 'demo'..."* ]]
  [[ "$output" == *"FAKE_SHELL CMD=$TEST_SHELL SHELL_CONTEXT=demo START=$HOME/.config/shell-context/contexts/demo.context-start FINAL= PREVIOUS= DEPTH=1"* ]]
}

@test "shell_context_auto_local reports the auto nesting limit when it blocks a context change" {
  install_fake_shell
  mkdir -p "$HOME/.config/shell-context/contexts" "$BATS_TEST_TMPDIR/project"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.shell-context"
  : >"$HOME/.config/shell-context/contexts/demo.context-start"

  run_in_test_shell \
    'export HOME="$1"; export PATH="$3:$PATH"; export SHELL_CONTEXT_AUTO=1; export SHELL_CONTEXT_DEPTH=1; export SHELL_CONTEXT_PREV_DIR="$4/elsewhere"; source "$2"; cd "$4/project"; shell_context_auto_local 2>&1' "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Shell Context: Not auto-loading context 'demo' beyond depth limit of 1."* ]]
  [[ "$output" != *"FAKE_SHELL CMD="* ]]
  [[ "$output" != *"Entering context"* ]]
}

@test "shell_context_auto_local reports the default context name when it blocks a nested default context" {
  run_in_test_shell \
    'export HOME="$1"; export SHELL_CONTEXT=current; export SHELL_CONTEXT_AUTO=1; export SHELL_CONTEXT_DEPTH=1; export SHELL_CONTEXT_PREV_DIR="$3/elsewhere"; source "$2"; mkdir -p "$3/project"; cd "$3/project"; shell_context_auto_local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Shell Context: Not auto-loading context '(default)' beyond depth limit of 1."* ]]
}

@test "shell_context_auto_local does not report the auto nesting limit when no local context applies" {
  run_in_test_shell \
    'export HOME="$1"; export SHELL_CONTEXT_AUTO=1; export SHELL_CONTEXT_DEPTH=1; export SHELL_CONTEXT_PREV_DIR="$3/elsewhere"; source "$2"; mkdir -p "$3/project"; cd "$3/project"; shell_context_auto_local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Shell Context: Not auto-loading context"* ]]
}

@test "shell_context_auto_local does not report the auto nesting limit when the requested context is already active" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.shell-context"

  run_in_test_shell \
    'export HOME="$1"; export SHELL_CONTEXT=demo; export SHELL_CONTEXT_AUTO=1; export SHELL_CONTEXT_DEPTH=1; export SHELL_CONTEXT_PREV_DIR="$3/elsewhere"; source "$2"; cd "$3/project"; shell_context_auto_local 2>&1' "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Shell Context: Not auto-loading context"* ]]
}

@test "shell_context_auto_local loads a context when below the auto nesting limit" {
  install_fake_shell
  mkdir -p "$HOME/.config/shell-context/contexts" "$BATS_TEST_TMPDIR/project"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.shell-context"
  : >"$HOME/.config/shell-context/contexts/demo.context-start"

  run_in_test_shell \
    'export HOME="$1"; export PATH="$3:$PATH"; export SHELL_CONTEXT_AUTO=2; export SHELL_CONTEXT_DEPTH=1; export SHELL_CONTEXT_PREV_DIR="$4/elsewhere"; source "$2"; cd "$4/project"; shell_context_auto_local 2>&1' "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Entering context 'demo'..."* ]]
  [[ "$output" == *"FAKE_SHELL CMD=$TEST_SHELL SHELL_CONTEXT=demo START=$HOME/.config/shell-context/contexts/demo.context-start FINAL= PREVIOUS= DEPTH=2"* ]]
}
