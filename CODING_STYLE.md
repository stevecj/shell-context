# Coding Style Guide

## Scope

This guide applies to source, tests, and documentation in this
repository.

## Shell script style

- Keep functions small and single-purpose when practical.
- Use clear, explicit names. Internal helpers should use the existing
  `_shell_context_*` naming pattern.
- Print user-facing errors to `stderr` and return non-zero on failure.
- Preserve Bash/Zsh compatibility for shell-runtime behavior.

## Help and usage output

- Wrap help output text for readability.
- Help output lines should not exceed **70 characters** where practical.
- Exceed 70 characters only when necessary (for example, preserving the
  integrity of a URL, command name, or path that should not be split).

## Test updates

- When changing command behavior, update or add Bats coverage in
  `test/shell-context.bats`.
