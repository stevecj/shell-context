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

This repository is centered on a single sourced shell library: `src/shell-context.sh`. It is not structured as a standalone executable. The file is meant to be sourced from a user's Bash or Zsh startup files (for example `~/.bashrc`, `~/.bash_profile`, or `~/.zshrc`), and it defines one public dispatcher function, `in-context`, which routes to subcommand-specific helpers.

The core model is environment-driven context switching:

- `init-start` prepares shell state at startup, captures the pre-context `PATH` in `INCONTEXT_PRE_PATH`, and loads either the active context's `*.context-start` file or `_default.context-start`.
- `init-finalize` runs late shell initialization by sourcing either the active context's `*.context-finalize` file or `_default.context-finalize`.
- `prompt-title` is a pure formatter that prints `INCONTEXT_TITLE` or a caller-provided fallback for prompt composition.
- `use` enters a named context by relaunching the current supported shell (`bash` or `zsh`) with `INCONTEXT`, `INCONTEXT_START_FILE`, and `INCONTEXT_FINALIZE_FILE` exported.
- `use-local` discovers the nearest `.incontext` file by walking upward from the current directory, then delegates to `use`; if no file is found, it unloads the active context or reports that none is loaded.
- `unload` exits the current context shell after optional confirmation.

Runtime configuration lives outside the repo under `~/.config/in-context/contexts/`. Context behavior is defined by `<name>.context-start`, optional `<name>.context-finalize`, and optional cleanup/default variants described in `src/shell-context.sh`.

The test suite in `test/shell-context.bats` treats the library as sourced shell code, not as a CLI binary. Tests create isolated `HOME` and temporary directories, and they inject a fake current-shell executable on `PATH` to verify how `use`/`use-local` relaunch the active shell and pass environment variables.

## Key conventions

- Keep the public surface on the `in-context` function and add behavior through private `_incontext-*` helpers plus matching `*-usage` helpers. The file consistently separates usage text from implementation.
- Each subcommand parses options with its own `getopts` loop and signals failures with return codes plus stderr output. Preserve that style when adding options or commands.
- The code assumes it is sourced into an interactive Bash or Zsh session. Avoid changes that make the main file behave like an executable script.
- Production code should infer the current shell from the running environment and support only `bash` and `zsh`; do not add a user-facing shell selector unless requirements change.
- Context state is carried through exported environment variables (`INCONTEXT`, `INCONTEXT_TITLE`, `INCONTEXT_START_FILE`, `INCONTEXT_FINALIZE_FILE`, `INCONTEXT_PRE_PATH`) rather than persisted files inside the repository.
- `use-local` defaults to the logical working directory (`pwd`) and only dereferences symlinks when `-p` is passed (`pwd -P`). Keep that distinction intact when changing local-context resolution.
- Tests should avoid mutating the real user environment. Follow the existing Bats pattern of overriding `HOME`, working in `BATS_TEST_TMPDIR`, and stubbing the current shell executable through a temporary `PATH`.
