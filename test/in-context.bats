#!/usr/bin/env bats

SCRIPT_PATH="$BATS_TEST_DIRNAME/../src/in-context.bash"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export FAKE_BIN="$BATS_TEST_TMPDIR/bin"

  mkdir -p "$HOME" "$FAKE_BIN"
}

install_fake_bash() {
  cat >"$FAKE_BIN/bash" <<'EOF'
#!/bin/bash
printf 'FAKE_BASH INCONTEXT=%s START=%s FINAL=%s\n' \
  "${INCONTEXT-}" "${INCONTEXT_START_FILE-}" "${INCONTEXT_FINALIZE_FILE-}"
EOF
  chmod +x "$FAKE_BIN/bash"
}

@test "top-level help is available" {
  run bash -lc 'source "$1"; in-context -h' _ "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: in-context <subcommand> [arguments]"* ]]
}

@test "unknown subcommands fail with usage output" {
  run bash -lc 'source "$1"; in-context unknown 2>&1' _ "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown subcommand: unknown"* ]]
  [[ "$output" == *"Usage: in-context <subcommand> [arguments]"* ]]
}

@test "prompt-title uses the explicit title value" {
  run bash -lc 'source "$1"; INCONTEXT_TITLE=dev; in-context prompt-title "[%s]" fallback' _ "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[dev]" ]
}

@test "prompt-title falls back to the provided default value" {
  run bash -lc 'source "$1"; unset INCONTEXT_TITLE; in-context prompt-title "[%s]" fallback' _ "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "[fallback]" ]
}

@test "init-start loads the default context-start file" {
  mkdir -p "$HOME/.config/in-context/contexts"
  printf 'export TEST_FLAG=loaded\n' >"$HOME/.config/in-context/contexts/_default.context-start"

  run bash -lc 'export HOME="$1"; source "$2"; unset INCONTEXT TEST_FLAG; INCONTEXT_PRE_PATH=/usr/bin:/bin; in-context init-start; printf "%s|%s" "$TEST_FLAG" "$INCONTEXT_START_FILE"' _ "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [ "$output" = "loaded|$HOME/.config/in-context/contexts/_default.context-start" ]
}

@test "use rejects missing named contexts" {
  run bash -lc 'export HOME="$1"; source "$2"; in-context use missing 2>&1' _ "$HOME" "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"No context-start file found for 'missing'"* ]]
}

@test "use-local reports when no local context exists" {
  mkdir -p "$BATS_TEST_TMPDIR/work"

  run bash -lc 'export HOME="$1"; source "$2"; cd "$3"; in-context use-local 2>&1' _ "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No .incontext file found and no context currently loaded."* ]]
}

@test "use-local errors when the discovered .incontext file is empty" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  : >"$BATS_TEST_TMPDIR/project/.incontext"

  run bash -lc 'export HOME="$1"; source "$2"; cd "$3"; in-context use-local 2>&1' _ "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/project"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Context file $BATS_TEST_TMPDIR/project/.incontext is empty."* ]]
}

@test "use-local short-circuits when the requested context is already active" {
  mkdir -p "$BATS_TEST_TMPDIR/project"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.incontext"

  run bash -lc 'export HOME="$1"; source "$2"; export INCONTEXT=demo; cd "$3"; in-context use-local 2>&1' _ "$HOME" "$SCRIPT_PATH" "$BATS_TEST_TMPDIR/project"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Already in context 'demo'."* ]]
}

@test "use-local finds the nearest .incontext file and launches that context" {
  install_fake_bash
  mkdir -p "$HOME/.config/in-context/contexts" "$BATS_TEST_TMPDIR/project/child"
  printf 'demo\n' >"$BATS_TEST_TMPDIR/project/.incontext"
  : >"$HOME/.config/in-context/contexts/demo.context-start"

  run bash -lc 'export HOME="$1"; export PATH="$3:$PATH"; source "$2"; cd "$4/project/child"; in-context use-local 2>&1' _ "$HOME" "$SCRIPT_PATH" "$FAKE_BIN" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Entering context 'demo'..."* ]]
  [[ "$output" == *"FAKE_BASH INCONTEXT=demo START=$HOME/.config/in-context/contexts/demo.context-start FINAL="* ]]
}
