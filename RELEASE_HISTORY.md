# Release History

## 1.0.3 (2026-07-23)

- Added `run` subcommand to execute a command in a named context without
  opening an interactive context shell. Includes `--` separator support
  so command arguments (such as `-h`) are passed through correctly.
- Added `ls` subcommand to list available context names, with optional
  `-v` output including resolved titles.
- Added `show` subcommand to display resolved context details, including
  title and effective start/finalize/cleanup files. When no
  `context_name` is provided, `show` uses the current context (including
  `_default` when default context-start is active).
- Added optional shell completion registration during
  `shell-context init-finalize`, with `SHELL_CONTEXT_COMPLETIONS=0` to
  disable it.
- Suppressed repeated auto-load depth-limit warnings when the same
  context is blocked in consecutive `shell_context_auto_local` checks.

## 1.0.2

- Improved documentation.
- Improved help output from functions.

## 1.0.1

- Improved documentation.

## 1.0.0

- Initial release.
