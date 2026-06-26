# Copilot Instructions for `shell_context`

## Build, test, and lint

There is no checked-in build step or lint entrypoint in this repository. The main validation path is the Bats test suite.

```bash
# Run the full test suite against every installed supported shell (bash/zsh)
test/run.bash

# Run the suite for one shell only
test/run.bash --shell bash
test/run.bash --shell zsh

# Run the single checked-in test file
test/run.bash --shell bash test/shell-context.bats

# Run one test by name
test/run.bash --shell zsh test/shell-context.bats --filter 'prompt-title uses the explicit title value'

# Equivalent direct Bats invocation for a specific shell
TEST_SHELL=bash bats test
```

`test/run.bash` is the preferred wrapper because it checks for `bats`, auto-detects installed supported shells, and runs one pass per shell.

## High-level architecture

This repository is centered on a single sourced shell library: `src/shell-context.sh`. It is not structured as a standalone executable. The file is meant to be sourced from a user's Bash or Zsh startup files (for example `~/.bashrc`, `~/.bash_profile`, or `~/.zshrc`), and it defines a public dispatcher function, `shell-context`, plus a public hook function, `shell_context_auto_local`.

The core model is environment-driven context switching:

- `init-start` prepares shell state at startup, captures the pre-context `PATH` in `SHELL_CONTEXT_PRE_PATH`, and loads either the active context's `*.context-start` file or `_default.context-start`.
- `init-start` also performs cleanup for `SHELL_CONTEXT_PREVIOUS_CONTEXT` in the newly started shell before loading the next context, which preserves the parent shell when nested contexts exit.
- `init-finalize` runs late shell initialization by sourcing either the active context's `*.context-finalize` file or `_default.context-finalize`. When `SHELL_CONTEXT_AUTO` is a positive integer, it also installs the `shell_context_auto_local` prompt hook.
- `prompt-title` is a pure formatter that prints `SHELL_CONTEXT_TITLE` or a caller-provided fallback for prompt composition, and can append formatted depth information derived from `SHELL_CONTEXT_DEPTH`.
- `load` enters a named context by launching a new nested instance of the current supported shell (`bash` or `zsh`) with `SHELL_CONTEXT`, `SHELL_CONTEXT_START_FILE`, `SHELL_CONTEXT_FINALIZE_FILE`, `SHELL_CONTEXT_PREVIOUS_CONTEXT`, and `SHELL_CONTEXT_DEPTH` exported.
- `load-local` discovers the nearest `.shell-context` file by walking upward from the current directory, then delegates to `load`; if no file is found while a named context is active, it launches a nested default-context shell instead of unloading.
- `shell_context_auto_local` is the public hook function used by Bash `PROMPT_COMMAND` and Zsh `precmd`. It reuses local-context resolution logic and respects the numeric `SHELL_CONTEXT_AUTO` nesting limit.
- `unload` exits the current context shell after optional confirmation.

Runtime configuration lives outside the repo under `~/.config/shell-context/contexts/`. Context behavior is defined by `<name>.context-start`, optional `<name>.context-finalize`, and optional cleanup/default variants described in `src/shell-context.sh`.

The test suite in `test/shell-context.bats` treats the library as sourced shell code, not as a CLI binary. Tests create isolated `HOME` and temporary directories, and they inject a fake current-shell executable on `PATH` to verify how `load`/`load-local` relaunch the active shell and pass `SHELL_CONTEXT*` environment variables, including previous-context and depth handoff.

## Key conventions

- Keep the public surface focused on `shell-context` plus the intentionally public `shell_context_auto_local` hook function, and add other behavior through private `_shell_context_*` helpers plus matching `*_usage` helpers. The file consistently separates usage text from implementation.
- Each subcommand parses options with its own `getopts` loop and signals failures with return codes plus stderr output. Preserve that style when adding options or commands.
- The code assumes it is sourced into an interactive Bash or Zsh session. Avoid changes that make the main file behave like an executable script.
- Production code should infer the current shell from the running environment and support only `bash` and `zsh`; do not add a user-facing shell selector unless requirements change.
- Context state is carried through exported environment variables (`SHELL_CONTEXT`, `SHELL_CONTEXT_TITLE`, `SHELL_CONTEXT_START_FILE`, `SHELL_CONTEXT_FINALIZE_FILE`, `SHELL_CONTEXT_PRE_PATH`, `SHELL_CONTEXT_PREVIOUS_CONTEXT`, `SHELL_CONTEXT_DEPTH`, `SHELL_CONTEXT_AUTO`) rather than persisted files inside the repository.
- `load-local` defaults to the logical working directory (`pwd`) and only dereferences symlinks when `-p` is passed (`pwd -P`). Keep that distinction intact when changing local-context resolution.
- `SHELL_CONTEXT_AUTO` is a non-negative integer, not a boolean. Values `1+` install the auto-local hook and also cap how deeply automatic nesting may go; `0`, blank, or unset disable automatic hook installation.
- Tests should avoid mutating the real user environment. Follow the existing Bats pattern of overriding `HOME`, working in `BATS_TEST_TMPDIR`, and stubbing the current shell executable through a temporary `PATH`.
