# File: shell-context.sh

if [[ ! -d "$HOME/.config/shell-context/contexts" ]]; then
  mkdir -p "$HOME/.config/shell-context/contexts"
fi

function _shell_context_usage() {
  cat <<EOF
Usage: shell-context <subcommand> [arguments]
Usage: shell-context -h

This script is intended to be located in your ~/.local/lib/
directory and sourced from your shell startup file (for example
~/.bashrc, ~/.bash_profile, or ~/.zshrc). It provides the
shell-context function for managing your working context with the
Shell Context project.

Each context runs in a separate bash or zsh session with environment
variables set according to the particular context. The SHELL_CONTEXT
environment variable is set to the name of the current context, and
other environment variables can be set as needed by the context's
script files.

Context script files must be located in the
~/.config/shell-context/contexts/ directory and should be named
according to the following convention:
  <context-name>.context-start (required)
  <context-name>.context-finalize (optional)
  <context-name>.context-cleanup (optional)

That directory may also contain _default.context-start,
_default.context-finalize, and/or _default.context-cleanup files,
which will be sourced when no context is loaded (for the start and
finalize files) or when switching from the context to another but
there is no cleanup file for the current context (for the cleanup
file).

Put a call to `shell-context init-start" near the beginning of the
shell startup file and a call to `shell-context init-finalize` near
the end of the file.

For each context, there must be a <context-name>.context-start
file in the ~/.config/shell-context/contexts/ directory, which is
sourced by the call to `shell-context init-start`.  This file
should set environment variables needed for the context, and
optionally set `SHELL_CONTEXT_TITLE` to a string to be used instead
of the context name as the title of the context in the prompt.

Each context may also optionally have a
<context-name>.context-finalize file in the
~/.config/shell-context/contexts/ directory, which is sourced by the
call to `shell-context init-finalize`. This should perform any
actions that require access to executables and functions defined
previously in the startup, such as pyenv or nvm initialization.

Finally, each context may also optionally have a
<context-name>.context-cleanup file in the
~/.config/shell-context/contexts/ directory, which is sourced before
switching from the current context to another (but not when simply
uloading a context).

When a shell session is started with no context loaded, then any
files in ~/.config/shell-context/contexts/ naned 
_default.context-start or _default.context-finalize will be sourced
by the calls to `shell-context init-start` and/or
`shell-context init-finalize`, respectively.

If a cleanup file is applicable, and the PATH variable value should
be restored, then the cleanup file should use the
`SHELL_CONTEXT_PRE_PATH` environment variable to restore the `PATH`
variable to what it was before the current context was loaded.

A "local" context is defined as the presence of a .shell-context file
in a directory or any of its ancestors, which contains the name of a
context.

If you are using Git, then you should globally ignore .shell-context
files by adding the following line to your ~/.config/git/ignore
file:

  .shell-context

Subcommands:
  init-start      Initialize the Shell Context system.
  init-finalize   Finalize Shell Context initialization.
  prompt-title    Output the prompt title for the current context.
  use             Enter a named context.
  unload          Exit the current context shell.
  use-local       Use the nearest .shell-context file.

Run `shell-context <subcommand> -h` for subcommand-specific help.
EOF
  :
}

function shell-context() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _shell_context_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  local subcommand=$1
  shift || true

  case "$subcommand" in
    init-start) _shell_context_init_start "$@" ;;
    init-finalize) _shell_context_init_finalize "$@" ;;
    prompt-title) _shell_context_prompt_title "$@" ;;
    use) _shell_context_use "$@" ;;
    unload) _shell_context_unload "$@" ;;
    use-local) _shell_context_use_local "$@" ;;
    ""|-h|--help) _shell_context_usage ;;
    *)
      echo "Unknown subcommand: $subcommand" >&2
      _shell_context_usage >&2
      return 1
      ;;
  esac
}

function _shell_context_current_shell() {
  if [[ -n ${BASH_VERSION-} ]]; then
    printf '%s\n' "bash"
  elif [[ -n ${ZSH_VERSION-} ]]; then
    printf '%s\n' "zsh"
  else
    echo "Shell Context only supports being sourced from bash or zsh." >&2
    return 1
  fi
}

function _shell_context_confirm() {
  local prompt=$1 reply
  printf '%s' "$prompt" >&2
  if ! IFS= read -r reply; then
    return 1
  fi

  case $reply in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

function _shell_context_init_usage() {
  cat <<EOF
Usage: shell-context init-start
Usage: shell-context init-start -h

Initialize the Shell Context system. This should be called near the
start of your shell startup file (for example ~/.bashrc,
~/.bash_profile, or ~/.zshrc).

Options:
  -h  Show this usage output and return.
EOF
  :
}

function _shell_context_init_start() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _shell_context_init_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  if [[ -z $SHELL_CONTEXT_PRE_PATH ]]; then
    export SHELL_CONTEXT_PRE_PATH=$PATH
  fi

  export SHELL_CONTEXT_TITLE=

  if [[ -n "$SHELL_CONTEXT" ]]; then
    export PATH=$SHELL_CONTEXT_PRE_PATH
    . "$SHELL_CONTEXT_START_FILE"
    if [[ -z $SHELL_CONTEXT_TITLE ]]; then
      export SHELL_CONTEXT_TITLE="$SHELL_CONTEXT"
    fi
  else
    export SHELL_CONTEXT_START_FILE=
    export SHELL_CONTEXT_FINALIZE_FILE=
    if [[ -f "$HOME/.config/shell-context/contexts/_default.context-start" ]]; then
      export SHELL_CONTEXT_START_FILE="$HOME/.config/shell-context/contexts/_default.context-start"
      . "$SHELL_CONTEXT_START_FILE"
    fi
  fi
}

function _shell_context_finalize_usage() {
  cat <<EOF
Usage: shell-context init-finalize
Usage: shell-context init-finalize -h

Finalize the initialization of the Shell Context system. This should be
called near the end of your shell startup file (for example ~/.bashrc,
~/.bash_profile, or ~/.zshrc).

Options:
  -h  Show this usage output and return.
EOF
  :
}

function _shell_context_init_finalize() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _shell_context_finalize_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done
  if [[ -n "$SHELL_CONTEXT" && -f "$SHELL_CONTEXT_FINALIZE_FILE" ]]; then
    . "$SHELL_CONTEXT_FINALIZE_FILE"
  elif [[ -f "$HOME/.config/shell-context/contexts/_default.context-finalize" ]]; then
    . "$HOME/.config/shell-context/contexts/_default.context-finalize"
  fi
}

function _shell_context_prompt_title_usage() {
  cat <<EOF
Usage: shell-context prompt-title [format] [default_value]
Usage: shell-context prompt-title -h

Output the context title for use in the prompt. This should be called
from the PS1/PROMPT assignment in your shell startup file.

If SHELL_CONTEXT_TITLE is not set, and no default_value is provided, then
no output will be produced, so the prompt will not be modified.

Arguments:
  format:
    A printf format string to format the context title (default: '%s').
  default_value:
    A default value to use in place of SHELL_CONTEXT_TITLE if not set.

Options:
  -h  Show this usage output and return.
EOF
  :
}

function _shell_context_prompt_title() {
  local template=$1 default_value=$2 value
  if [[ -z "$template" ]]; then template="%s"; fi
  if [[ -n "$SHELL_CONTEXT_TITLE" ]]; then value=$SHELL_CONTEXT_TITLE; else value=$default_value; fi
  if [[ -z "$value" ]]; then return 0; fi

  # shellcheck disable=SC2059
  printf "$template" "$value"
}

function _shell_context_use_usage() {
  cat <<EOF
Usage: shell-context use <context_name>
Usage: shell-context use -h

Use the context with the given name. This will open a new bash or zsh
session matching the current shell, with the environment variables set
according to the context.

Limitations:
  - Does not unload the current context before switching to the new
    context, so any environment variables set by the current context
    will remain in the new context unless they are specifically unset
    or re-set by the new context's .context-start file.

Arguments:
  context_name:
    The name of the context to use. This should correspond to a
    <context_name>.context-start file in the
    ~/.config/shell-context/contexts/ directory.

Options:
  -h  Show this usage output and return.
EOF
  :
}

function _shell_context_use() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _shell_context_use_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  local context_name="$1"

  if [[ -z "$context_name" ]]; then
    _shell_context_use_usage >&2
    return 1
  fi

  local context_start_file=$HOME/.config/shell-context/contexts/"$context_name".context-start
  if [[ ! -f $context_start_file ]]; then
    echo "No context-start file found for '$context_name' at $context_start_file." >&2
    return 1
  fi

  local context_finalize_file=$HOME/.config/shell-context/contexts/"$context_name".context-finalize
  if [[ ! -f $context_finalize_file ]]; then
    context_finalize_file=
  fi

  local current_shell
  current_shell=$(_shell_context_current_shell) || return 1

  echo "Entering context '$context_name'..."
  if [[ -n "$SHELL_CONTEXT" ]]; then
    SHELL_CONTEXT="$context_name" SHELL_CONTEXT_START_FILE="$context_start_file" SHELL_CONTEXT_FINALIZE_FILE="$context_finalize_file" \
      exec "$current_shell"
  else
    SHELL_CONTEXT="$context_name" SHELL_CONTEXT_START_FILE="$context_start_file" SHELL_CONTEXT_FINALIZE_FILE="$context_finalize_file" \
      "$current_shell"
  fi
}

function _shell_context_unload_usage() {
  cat <<EOF
Usage: shell-context unload [-qy]
Usage: shell-context unload -h

Unload the current context (if any) by exiting the current shell
session. If SHELL_CONTEXT is not set, then this will do nothing.

Options:
  -q  Be less verbose.
  -y  Don't prompt for confirmation before unloading the current
      context.
  -h  Show this usage output and return.
EOF
  :
}

function _shell_context_unload() {
  local OPTIND=1 opt OPTARG
  local prompt_for_conf=1
  local be_less_verbose
  while getopts ":qyh" opt; do
    case $opt in
      q) be_less_verbose=1 ;;
      y) prompt_for_conf= ;;
      h) _shell_context_unload_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  if [[ -z "$SHELL_CONTEXT" ]]; then
    echo "No context currently loaded." >&2
    return 0
  fi

  if [[ $prompt_for_conf == 1 ]]; then
    if ! _shell_context_confirm "Unload current context '$SHELL_CONTEXT'? [Y/n] "; then
      echo "Aborting context unload." >&2
      return 1
    fi
  fi

  echo "Unloading context '$SHELL_CONTEXT'..."
  exit
}

function _shell_context_use_local_usage() {
  cat <<EOF
Usage: shell-context use-local [options]
Usage: shell-context use-local -h

By default, switches to the context specified by a .shell-context file
in the current working directory or any of its ancestors (in the
current logical path) or unloads any currently loaded context if no
.shell-context file is found. See the help for shell-context use for more
details about loading contexts.

Options:
  -y  Don't prompt for confirmation before switching contexts or
      unloading the current context.
  -p  Look for a .shell-context file in the physical path of the current
      working directory (dereferencing symlinks) instead of the
      logical path.
  -q  Be less verbose.
  -h  Show this usage output and return.
EOF
  :
}

function _shell_context_use_local() {
  local OPTIND=1 opt OPTARG
  local prompt_for_conf=1
  local use_physical_path
  local be_less_verbose
  while getopts ":ypqh" opt; do
    case $opt in
      y) prompt_for_conf= ;;
      p) use_physical_path=true ;;
      q) be_less_verbose=1 ;;
      h) _shell_context_use_local_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  local search_path
  if [[ "$use_physical_path" == true ]]; then
    search_path=$(pwd -P)
  else
    search_path=$(pwd)
  fi

  local context_file
  while [[ "$search_path" != "/" ]]; do
    if [[ -f "$search_path/.shell-context" ]]; then
      context_file="$search_path/.shell-context"
      break
    fi
    search_path=$(dirname "$search_path")
  done

  if [[ -n "$context_file" ]]; then
    local context_name
    context_name=$(<"$context_file")
    if [[ -z "$context_name" ]]; then
      echo "Context file $context_file is empty." >&2
      return 1
    fi
    if [[ "$context_name" == "$SHELL_CONTEXT" ]]; then
      if [[ $be_less_verbose != 1 ]]; then
        echo "Already in context '$context_name'." >&2
      fi
      return 0
    fi
    _shell_context_use "$context_name"
  else
    if [[ -n "$SHELL_CONTEXT" ]]; then
      if [[ $prompt_for_conf == 1 ]]; then
        if ! _shell_context_confirm "No .shell-context file found. Unload current context '$SHELL_CONTEXT'? [Y/n] "; then
          echo "Aborting context unload." >&2
          return 1
        fi
      fi
      _shell_context_unload -y ${be_less_verbose:+-q}
    else
      if [[ $be_less_verbose != 1 ]]; then
        echo "No .shell-context file found and no context currently loaded." >&2
      fi
      return 0
    fi
  fi
}
