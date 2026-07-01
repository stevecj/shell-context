# File: shell-context.sh

if [[ ! -d "$HOME/.config/shell-context/contexts" ]]; then
  mkdir -p "$HOME/.config/shell-context/contexts"
fi

function _shell_context_usage() {
  cat <<'EOF'
Usage: shell-context <subcommand> [arguments]
Usage: shell-context -h
Usage: shell-context -v|version

Options:
  -h  Show this usage output and exit.
  -v  Show the version of Shell Context and exit.

Subcommands:
  init-start      Initialize the Shell Context system.
  init-finalize   Finalize Shell Context initialization.
  prompt-title    Output the prompt title for the current context.
  load            Enter a named context.
  unload          Exit the current context shell.
  load-local      Load  context named in nearest .shell-context file.
  auto-local      Load context from nearest .shell-context file on
                  directory change.
  version         Show the version of Shell Context and exit.

Run `shell-context <subcommand> -h` for subcommand-specific help.
EOF
  :
}

function shell-context() {
  local version="1.0.1"

  local OPTIND=1 opt OPTARG
  while getopts ":vh" opt; do
    case $opt in
      h) _shell_context_usage; return 0 ;;
      v) echo "$version"; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  local subcommand=$1
  shift || true

  if [[ $subcommand == "version" ]]; then
    echo "$version"
    return 0
  fi

  if [[ -f "$HOME/.config/shell-context/DISABLED" ]]; then
    case "$subcommand" in
      ""|-h|--help) ;;
      *)
        if ! _shell_context_subcommand_help_requested "$@"; then
          echo "Shell Context is disabled."
	  echo "Remove the \"$HOME/.config/shell-context/DISABLED\" file to re-enable Shell Context." >&2
          return 1
        fi
        ;;
    esac
  fi

  case "$subcommand" in
    init-start)    _shell_context_init_start "$@" ;;
    init-finalize) _shell_context_init_finalize "$@" ;;
    prompt-title)  _shell_context_prompt_title "$@" ;;
    load)          _shell_context_load "$@" ;;
    unload)        _shell_context_unload "$@" ;;
    load-local)    _shell_context_load_local "$@" ;;
    auto-local)    shell_context_auto_local "$@" ;;
    ""|-h|--help)  _shell_context_usage ;;
    *)
      echo "Unknown subcommand: $subcommand" >&2
      _shell_context_usage >&2
      return 1
      ;;
  esac
}

function _shell_context_subcommand_help_requested() {
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "-h" ]]; then
      return 0
    fi
  done

  return 1
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

function _shell_context_current_depth() {
  if [[ -z ${SHELL_CONTEXT_DEPTH+x} || -z "$SHELL_CONTEXT_DEPTH" ]]; then
    printf '%s\n' 0
    return 0
  fi

  if [[ "$SHELL_CONTEXT_DEPTH" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$SHELL_CONTEXT_DEPTH"
    return 0
  fi

  echo "SHELL_CONTEXT_DEPTH must be a non-negative integer, got '$SHELL_CONTEXT_DEPTH'." >&2
  return 1
}

function _shell_context_auto_limit() {
  if [[ -z ${SHELL_CONTEXT_AUTO+x} || -z "$SHELL_CONTEXT_AUTO" ]]; then
    return 0
  fi

  if [[ "$SHELL_CONTEXT_AUTO" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$SHELL_CONTEXT_AUTO"
    return 0
  fi

  echo "SHELL_CONTEXT_AUTO must be a non-negative integer, got '$SHELL_CONTEXT_AUTO'." >&2
  return 1
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

function _shell_context_source_context_cleanup() {
  local context_name=$1
  local context_cleanup_file=

  if [[ -n "$context_name" ]]; then
    context_cleanup_file=$HOME/.config/shell-context/contexts/"$context_name".context-cleanup
    if [[ -f $context_cleanup_file ]]; then
      . "$context_cleanup_file" || return 1
    elif [[ -f "$HOME/.config/shell-context/contexts/_default.context-cleanup" ]]; then
      . "$HOME/.config/shell-context/contexts/_default.context-cleanup" || return 1
    fi
  fi
}

function _shell_context_launch_shell() {
  local context_name=$1
  local context_start_file=$2
  local context_finalize_file=$3
  local previous_context_name=$4
  local current_shell current_depth next_depth

  current_shell=$(_shell_context_current_shell) || return 1
  current_depth=$(_shell_context_current_depth) || return 1
  next_depth=$((current_depth + 1))

  SHELL_CONTEXT="$context_name" SHELL_CONTEXT_START_FILE="$context_start_file" SHELL_CONTEXT_FINALIZE_FILE="$context_finalize_file" SHELL_CONTEXT_PREVIOUS_CONTEXT="$previous_context_name" SHELL_CONTEXT_DEPTH="$next_depth" \
   "$current_shell"
}

function _shell_context_init_usage() {
  cat <<'EOF'
Usage: shell-context init-start
Usage: shell-context init-start -h

Initialize the Shell Context system. This should be called near the
start of your shell startup file, e.g. example ~/.bashrc,
~/.bash_profile, or ~/.zshrc .

Options:
  -h  Show this usage output and exit.

Environment variables used:
  SHELL_CONTEXT
    The name of the context being initialized, if any.
  SHELL_CONTEXT_DEPTH
    The nested depth of the current shell. If set, it must be a
    non-negative integer.
  SHELL_CONTEXT_PRE_PATH
    The original PATH value from before context-specific PATH changes
    were applied. If already set, PATH is restored from this value
    before the new context-start file is sourced.
  SHELL_CONTEXT_PREVIOUS_CONTEXT
    The name of the previous/parent context, if any. Its cleanup file
    is sourced before the new context is initialized.
  SHELL_CONTEXT_START_FILE
    The path to the context-start file for the current named context,
    if any.

Environment variables assigned:
  PATH
    Restored from SHELL_CONTEXT_PRE_PATH before sourcing a named
    context's context-start file if no cleaup file was sourced (or
    possibly by the sourced cleanup file).
  SHELL_CONTEXT_TITLE
    Reset before initialization, then left for the context-start file to
    optionally set.  After initialization, it is set to the context name
    if not assigned yet.
  SHELL_CONTEXT_PRE_PATH
    If previously unset or blank, set to the shell's current PATH before
    any cleanup or new context-start file is applied.
  SHELL_CONTEXT_DEPTH
    The nested context depth of the current shell, set to 0 if previously
    unset.
  SHELL_CONTEXT_START_FILE
    Cleared when no named context is being initialized, or set to
    ~/.config/shell-context/contexts/_default.context-start if that
    file exists.
  SHELL_CONTEXT_FINALIZE_FILE
    Cleared when no named context is being initialized.
EOF
  :
}

function _shell_context_init_start() {
  local OPTIND=1 opt OPTARG
  local current_depth
  while getopts ":h" opt; do
    case $opt in
      h) _shell_context_init_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  current_depth=$(_shell_context_current_depth) || return 1
  export SHELL_CONTEXT_DEPTH=$current_depth

  if [[ -z $SHELL_CONTEXT_PRE_PATH ]]; then
    export SHELL_CONTEXT_PRE_PATH=$PATH
  fi

  if [[ -n "$SHELL_CONTEXT_PREVIOUS_CONTEXT" ]]; then
    _shell_context_source_context_cleanup "$SHELL_CONTEXT_PREVIOUS_CONTEXT" || return 1
    unset SHELL_CONTEXT_PREVIOUS_CONTEXT
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
  cat <<'EOF'
Usage: shell-context init-finalize
Usage: shell-context init-finalize -h

Finalize the initialization of the Shell Context system. This should be
called near the end of your shell startup file, e.g. example ~/.bashrc,
~/.bash_profile, or ~/.zshrc .

Options:
  -h  Show this usage output and exit.

Environment variables used:
  SHELL_CONTEXT
    The name of the current context, if any.
  SHELL_CONTEXT_FINALIZE_FILE
    The path to the context-finalize file for the current context, if
    any.
  SHELL_CONTEXT_AUTO
    If set, it must be a non-negative integer. Values 1 and larger
    install the shell_context_auto_local prompt hook and set the maximum
    nesting depth for automatic context loading. Values 0, blank, or
    unset disable automatic hook installation.

Environment variables assigned:
  Does not directly assign any environment variables,
EOF
  :
}

function _shell_context_init_finalize() {
  local OPTIND=1 opt OPTARG
  local auto_limit
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

  auto_limit=$(_shell_context_auto_limit) || return 1
  if [[ -n "$auto_limit" && "$auto_limit" -ge 1 ]]; then
    local current_shell
    current_shell=$(_shell_context_current_shell) || return 1
    if [[ $current_shell == "bash" ]]; then
      if [[ -n "$PROMPT_COMMAND" ]]; then
	PROMPT_COMMAND="shell_context_auto_local; $PROMPT_COMMAND"
      else
	PROMPT_COMMAND="shell_context_auto_local"
      fi
    elif [[ $current_shell == "zsh" ]]; then
      autoload -U add-zsh-hook
      add-zsh-hook precmd shell_context_auto_local
    fi
  fi
}

function _shell_context_prompt_title_usage() {
  cat <<'EOF'
Usage: shell-context prompt-title [-n format] [-d depth_format] [-D minimum_depth] [default_value]
Usage: shell-context prompt-title -h

Output the context title for use in the prompt. This should be called
from the PS1/PROMPT assignment in your shell startup file.

If SHELL_CONTEXT_TITLE is not set, and no default_value is provided,
then no output will be produced, so the prompt will not be modified.

Options:
  -n format
      A printf format string to format the context title (default:
      '%s').
  -d depth_format
      A printf format string to append the current context depth to the
      title when the depth meets the minimum threshold (default:
      ' (%s)').
  -D minimum_depth
      The minimum SHELL_CONTEXT_DEPTH at which the formatted depth will
      be appended (default: 2).
  -h  Show this usage output and exit.

Arguments:
  default_value:
    A default value to use in place of SHELL_CONTEXT_TITLE if not set,
    meaning no context is loaded.

Tip:
  You may want to define a function in your shell startup file to call
  this subcommand with your preferred options, and then call that
  function in your PS1/PROMPT assignment

Environment variables used:
  SHELL_CONTEXT_TITLE
    The current context title, if any. This is used unless it is blank, and a
    default_value argument is provided.
  SHELL_CONTEXT_DEPTH
    The nested context depth of the current shell. If set, it must be a
    non-negative integer.

Environment variables assigned:
  Does not directly assign any environment variables,
EOF
  :
}

function _shell_context_prompt_title() {
  local OPTIND=1 opt OPTARG
  local template="%s"
  local depth_template=" (%s)"
  local minimum_depth=2
  while getopts ":n:d:D:h" opt; do
    case $opt in
      n) template=$OPTARG ;;
      d) depth_template=$OPTARG ;;
      D)
        if [[ ! "$OPTARG" =~ ^[0-9]+$ ]]; then
          echo "Option -D requires a non-negative integer argument." >&2
          return 1
        fi
        minimum_depth=$OPTARG
        ;;
      h) _shell_context_prompt_title_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
      :) echo "Option -$OPTARG requires an argument." >&2; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  local default_value=$1 value depth
  if [[ -z "$template" ]]; then template="%s"; fi
  if [[ -n "$SHELL_CONTEXT_TITLE" ]]; then value=$SHELL_CONTEXT_TITLE; else value=$default_value; fi
  if [[ -z "$value" ]]; then return 0; fi
  depth=$(_shell_context_current_depth) || return 1
  if (( depth >= minimum_depth )); then
    # shellcheck disable=SC2059
    value+=$(printf "$depth_template" "$depth")
  fi

  # shellcheck disable=SC2059
  printf "$template" "$value"
}

function _shell_context_load_usage() {
  cat <<'EOF'
Usage: shell-context load <context_name>
Usage: shell-context load -h

Use the context with the given name. This will open a new bash or zsh
session matching the current shell, with the environment variables set
according to the context.

Shell Context exports SHELL_CONTEXT_DEPTH to track context nesting. The
first context loaded from a non-context shell starts at depth 1, and
each nested context shell increments that depth by 1.

When switching from one context to another, the new shell session runs
the previous context's .context-cleanup file during initialization if
one exists. If the previous context does not have a .context-cleanup
file, then _default.context-cleanup will be sourced instead if it
exists.

Each call to shell-context load opens a new nested shell. When a
context is loaded from inside another context, SHELL_CONTEXT_DEPTH is
incremented and the parent shell remains unchanged after the nested
shell exits.

Arguments:
  context_name:
    The name of the context to load. This should correspond to a
    <context_name>.context-start file in the
    ~/.config/shell-context/contexts/ directory.

Options:
  -h  Show this usage output and exit.

Environment variables used:
  SHELL_CONTEXT
    The name of the current context, if any. When set, it becomes the
    previous/parent context for the newly launched shell.
  SHELL_CONTEXT_DEPTH
    The nested context depth of the current shell. If set, it must be a
    non-negative integer.

Environment variables assigned:
  SHELL_CONTEXT
    Set in the newly launched shell to the requested context name.
  SHELL_CONTEXT_START_FILE
    Set in the newly launched shell to the selected
    <context_name>.context-start file.
  SHELL_CONTEXT_FINALIZE_FILE
    Set in the newly launched shell to the selected
    <context_name>.context-finalize file, if one exists.
  SHELL_CONTEXT_PREVIOUS_CONTEXT
    Set in the newly launched shell to the current context name, if any.
  SHELL_CONTEXT_DEPTH
    Set in the newly launched shell to the current shell depth plus 1.
EOF
  :
}

function _shell_context_load() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _shell_context_load_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  local context_name="$1"

  if [[ -z "$context_name" ]]; then
    _shell_context_load_usage >&2
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

  local previous_context_name=
  if [[ -n "$SHELL_CONTEXT" ]]; then
    previous_context_name=$SHELL_CONTEXT
  fi

  echo "Entering context '$context_name'..."
  _shell_context_launch_shell \
    "$context_name" \
    "$context_start_file" \
    "$context_finalize_file" \
    "$previous_context_name"
}

function _shell_context_load_default() {
  local previous_context_name=
  if [[ -n "$SHELL_CONTEXT" ]]; then
    previous_context_name=$SHELL_CONTEXT
  fi

  _shell_context_launch_shell "" "" "" "$previous_context_name"
}

function _shell_context_unload_usage() {
  cat <<'EOF'
Usage: shell-context unload [-qy]
Usage: shell-context unload -h

Unload the current context (if any) by exiting the current shell
session. If SHELL_CONTEXT is not set, then this will do nothing.

Options:
  -q  Be less verbose.
  -y  Don't prompt for confirmation before unloading the current
      context.
  -h  Show this usage output and exit.

Environment variables used:
  SHELL_CONTEXT
    The name of the current context. If blank or unset, unload does
    nothing.

Environment variables assigned:
  Does not directly assign any environment variables,
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

function _shell_context_load_local_usage() {
  cat <<'EOF'
Usage: shell-context load-local [options]
Usage: shell-context load-local -h

By default, loads the context specified by a .shell-context file
in the current working directory or any of its ancestors (in the
current logical path. If no .shell-context file is found while a named
context is currently loaded, then a nested default context will be
loaded instead. See the help for shell-context load for more details
about loading contexts.

Options:
  -l  Look for a .shell-context file in the logical path of the
      current working directory, following any symlinks.
      This is the default behavior if neither -l nor -p is specified
      and SHELL_CONTEXT_PATH_SEARCH_MODE is not set.
  -p  Look for a .shell-context file in the physical path of the
      current working directory, dereferencing any symlinks.
  -q  Be less verbose.
  -y  Accepted for compatibility; currently has no effect.
  -h  Show this usage output and exit.

Environment variables used:
  SHELL_CONTEXT
    The name of the current context, if any. If no .shell-context file
    is found and SHELL_CONTEXT is set, a nested default context is
    loaded instead of doing nothing.
  SHELL_CONTEXT_PATH_SEARCH_MODE
    If set to "logical", then the -l option will be used by default.
    If set to "physical", then the -p option will be used by default.
    If blank or unset, the default is "logical".

Environment variables assigned:
  Does not directly assign any environment variables,
EOF
  :
}

function _shell_context_resolve_local_context() {
  local path_search_mode=$1
  local search_path
  if [[ $path_search_mode == logical ]]; then
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
      printf 'already-active\t%s\n' "$context_name"
      return 0
    fi
    printf 'load-context\t%s\n' "$context_name"
  else
    if [[ -n "$SHELL_CONTEXT" ]]; then
      printf '%s\n' 'load-default'
    else
      printf '%s\n' 'noop'
    fi
  fi
}

function _shell_context_apply_local_context_resolution() {
  local resolution=$1
  local be_less_verbose=$2
  local action context_name

  IFS=$'\t' read -r action context_name <<<"$resolution"
  case $action in
    load-context)
      _shell_context_load "$context_name"
      ;;
    load-default)
      if [[ $be_less_verbose != 1 ]]; then
        echo "No .shell-context file found. Entering nested default context." >&2
      fi
      _shell_context_load_default
      ;;
    already-active)
      if [[ $be_less_verbose != 1 ]]; then
        echo "Already in context '$context_name'." >&2
      fi
      return 0
      ;;
    noop)
      if [[ $be_less_verbose != 1 ]]; then
        echo "No .shell-context file found and no context currently loaded." >&2
      fi
      return 0
      ;;
    *)
      echo "Unexpected local context resolution: $resolution" >&2
      return 1
      ;;
  esac
}

function _shell_context_load_local() {
  local OPTIND=1 opt OPTARG
  local path_search_mode=${SHELL_CONTEXT_PATH_SEARCH_MODE:-logical}
  local be_less_verbose resolution
  while getopts ":lpqyh" opt; do
    case $opt in
      l) path_search_mode=logical ;;
      p) path_search_mode=physical ;;
      q) be_less_verbose=1 ;;
      y) ;;
      h) _shell_context_load_local_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  resolution=$(_shell_context_resolve_local_context "$path_search_mode") || return 1
  _shell_context_apply_local_context_resolution "$resolution" "$be_less_verbose"
}

function _shell_context_auto_local_usage() {
  cat <<'EOF'
Usage: shell-context auto-local
Usage: shell-context auto-local -h
Usage: shell_context_auto_local
Usage: shell_context_auto_local -h

Automatically load the context specified by a .shell-context file in
the current working directory or any of its ancestors if the current
directory has changed since the last time this was checked.

If SHELL_CONTEXT_AUTO is set to a positive integer, that value limits
how deeply this command/function will automatically nest contexts.
When a context change would otherwise occur, and SHELL_CONTEXT_DEPTH is
the same as or greater than the configured limit, it will do nothing.

Options:
  -h  Show this usage output and exit.

Environment variables used:
  SHELL_CONTEXT_AUTO
    If set, it must be a non-negative integer. Values 1 and larger limit
    how deeply automatic context loading may nest. Values 0, blank, or
    unset disable depth-limit checks.
  SHELL_CONTEXT_DEPTH
    The nested context depth of the current shell. If set, it must be a
    non-negative integer. It is compared with SHELL_CONTEXT_AUTO before
    an automatic load occurs.
  SHELL_CONTEXT_PATH_SEARCH_MODE
    Controls whether local context lookup uses the logical or physical
    working-directory path. If blank or unset, the default is "logical".
  SHELL_CONTEXT_PREV_DIR
    The previous working directory used to detect whether the current
    directory has changed since the last check.

Environment variables assigned:
  SHELL_CONTEXT_PREV_DIR
    Set to the current working directory the first time this function
    runs, and updated whenever the current working directory changes.
EOF
  :
}

function shell_context_auto_local() {
  local auto_limit current_depth resolution action target_context_name
  while getopts ":h" opt; do
    case $opt in
      h) _shell_context_auto_local_usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  auto_limit=$(_shell_context_auto_limit) || return 1

  if [[ -z $SHELL_CONTEXT_PREV_DIR ]]; then
    # Intentionally not exported.
    SHELL_CONTEXT_PREV_DIR=$(pwd)
    return 0
  fi

  if [[ "$SHELL_CONTEXT_PREV_DIR" != "$(pwd)" ]]; then
    # Intentionally not exported.
    SHELL_CONTEXT_PREV_DIR=$(pwd)
    resolution=$(_shell_context_resolve_local_context "${SHELL_CONTEXT_PATH_SEARCH_MODE:-logical}") || return 1
    IFS=$'\t' read -r action target_context_name <<<"$resolution"
    if [[ -n "$auto_limit" && "$auto_limit" -ge 1 ]]; then
      current_depth=$(_shell_context_current_depth) || return 1
      if (( current_depth >= auto_limit )); then
        case $action in
          load-context)
            echo "Shell Context: Not auto-loading context '$target_context_name' beyond depth limit of $auto_limit." >&2
            ;;
          load-default)
            echo "Shell Context: Not auto-loading context '(default)' beyond depth limit of $auto_limit." >&2
            ;;
        esac
        return 0
      fi
    fi
    _shell_context_apply_local_context_resolution "$resolution" 1
  fi
  :
}
