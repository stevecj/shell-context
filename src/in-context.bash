# File: in-context.bash

# This script is intended to be located in your ~/.local/lib/
# directory and sourced from near the start of your ~/.bashrc or
# ~/.bash_profile. It provides the in-context function for managing
# your working context with the In Context project.
#
# Each context runs in a separate bash session with environment
# variables set according to the particular context. The INCONTEXT
# environment variable is set to the name of the current context, and
# other environment variables can be set as needed by the context.
#
# For each context, there should be a <context-name>.context-start
# file in the ~/.config/in-context/contexts/ directory, which is
# sourced near the beginning of the .bashrc or .bash_profile of the
# context's bash session. This file should set any environment
# variables needed for the context, and optionally set
# INCONTEXT_TITLE to a string to be used instead of the context name
# as the title of the context in the prompt.
#
# Each context may also optionally have a
# <context-name>.context-finalize file in the
# ~/.config/in-context/contexts/ directory, which is sourced near the
# end of the .bashrc or .bash_profile of the context's bash session.
# This should perform any actions that require access to executables
# and functions defined in the .bashrc or .bash_profile, such as pyenv
# or nvm initialization.
#
# Each context may also optionally have a
# <context-name>.context-cleanup file in the
# ~/.config/in-context/contexts/ directory, which is sourced before
# switching from one context to another.
#
# If there is a file named _default.context-start in the
# ~/.config/in-context/contexts/ directory, then it will be sourced
# when no context is loaded. Similarly, if there is a file named
# _default.context-finalize in the ~/.config/in-context/contexts/
# directory, then it will be sourced when no context is loaded.
#
# If there is a file named _default.context-cleanup in the
# ~/.config/in-context/contexts/ directory, then it will be sourced
# before switching from one context to another. If no cleanup file
# is applicable, then the cleanup will consist of restoring the PATH
# environment variable to what it was just before the current
# context was loaded (from the INCONTEXT_PRE_PATH environment
# variable).
#
# If a cleanup file is applicable, and the PATH variable value should
# be restored, then the cleanup file should use the
# INCONTEXT_PRE_PATH environment variable to restore the PATH variable
# to what it was before the current context was loaded.
#
# A "local" context is defined by the presence of a .incontext file in
# the current directory or any of its ancestors, which contains the
# name of a context.
#
# If you are using Git, then you should globally ignore .incontext
# files by adding the following line to your ~/.config/git/ignore
# file:
#
#   .incontext
#
# Invoke the system through the in-context function and one of its
# subcommands.

if [[ ! -d "$HOME/.config/in-context/contexts" ]]; then
  mkdir -p "$HOME/.config/in-context/contexts"
fi

function _incontext-init-usage() {
  cat <<EOF
Usage: in-context init-start
Usage: in-context init-start -h

Initialize the In Context system. This should be called near the
start of your .bashrc or .bash_profile.

Options:
  -h  Show this usage output and return.
EOF
  :
}

function _incontext-init-start() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _incontext-init-usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  if [[ -z $INCONTEXT_PRE_PATH ]]; then
    export INCONTEXT_PRE_PATH=$PATH
  fi

  export INCONTEXT_TITLE=

  if [[ -n "$INCONTEXT" ]]; then
    export PATH=$INCONTEXT_PRE_PATH
    . "$INCONTEXT_START_FILE"
    if [[ -z $INCONTEXT_TITLE ]]; then
      export INCONTEXT_TITLE="$INCONTEXT"
    fi
  else
    export INCONTEXT_START_FILE=
    export INCONTEXT_FINALIZE_FILE=
    if [[ -f "$HOME/.config/in-context/contexts/_default.context-start" ]]; then
      export INCONTEXT_START_FILE="$HOME/.config/in-context/contexts/_default.context-start"
      . "$INCONTEXT_START_FILE"
    fi
  fi
}

function _incontext-finalize-usage() {
  cat <<EOF
Usage: in-context init-finalize
Usage: in-context init-finalize -h

Finalize the initialization of the In Context system. This should be
called near the end of your .bashrc or .bash_profile.

Options:
  -h  Show this usage output and return.
EOF
  :
}

function _incontext-init-finalize() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _incontext-finalize-usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done
  if [[ -n "$INCONTEXT" && -f "$INCONTEXT_FINALIZE_FILE" ]]; then
    . "$INCONTEXT_FINALIZE_FILE"
  elif [[ -f "$HOME/.config/in-context/contexts/_default.context-finalize" ]]; then
    . "$HOME/.config/in-context/contexts/_default.context-finalize"
  fi
}

function _incontext-in-prompt-title-usage() {
  cat <<EOF
Usage: in-context prompt-title [format] [default_value]
Usage: in-context prompt-title -h

Output the context title for use in the prompt. This should be called
from the PS1 variable assignment in your .bashrc or .bash_profile.

If INCONTEXT_TITLE is not set, and no default_value is provided, then
no output will be produced, so the prompt will not be modified.

Arguments:
  format:
    A printf format string to format the context title (default: '%s').
  default_value:
    A default value to use in place of INCONTEXT_TITLE if not set.

Options:
  -h  Show this usage output and return.
EOF
  :
}

function _incontext-prompt-title() {
  local template=$1 default_value=$2 value
  if [[ -z "$template" ]]; then template="%s"; fi
  if [[ -n "$INCONTEXT_TITLE" ]]; then value=$INCONTEXT_TITLE; else value=$default_value; fi
  if [[ -z "$value" ]]; then return 0; fi

  # shellcheck disable=SC2059
  printf "$template" "$value"
}

function _use-incontext-usage() {
  cat <<EOF
Usage: in-context use <context_name>
Usage: in-context use -h

Use the context with the given name. This will open a new bash session
with the environment variables set according to the context.

Limitations:
  - Does not unload the current context before switching to the new
    context, so any environment variables set by the current context
    will remain in the new context unless they are specifically unset
    or re-set by the new context's .context-start file.

Arguments:
  context_name:
    The name of the context to use. This should correspond to a
    <context_name>.context-start file in the
    ~/.config/in-context/contexts/ directory.

Options:
  -h  Show this usage output and return.
EOF
  :
}

function _incontext-use() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _use-incontext-usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  local context_name="$1"

  if [[ -z "$context_name" ]]; then
    _use-incontext-usage >&2
    return 1
  fi

  local context_start_file=$HOME/.config/in-context/contexts/"$context_name".context-start
  if [[ ! -f $context_start_file ]]; then
    echo "No context-start file found for '$context_name' at $context_start_file." >&2
    return 1
  fi

  local context_finalize_file=$HOME/.config/in-context/contexts/"$context_name".context-finalize
  if [[ ! -f $context_finalize_file ]]; then
    context_finalize_file=
  fi

  echo "Entering context '$context_name'..."
  if [[ -n "$INCONTEXT" ]]; then
    INCONTEXT="$context_name" INCONTEXT_START_FILE="$context_start_file" INCONTEXT_FINALIZE_FILE="$context_finalize_file" \
      exec bash
  else
    INCONTEXT="$context_name" INCONTEXT_START_FILE="$context_start_file" INCONTEXT_FINALIZE_FILE="$context_finalize_file" \
      bash
  fi
}

function _unload-incontext-usage() {
  cat <<EOF
Usage: in-context unload [-qy]
Usage: in-context unload -h

Unload the current context (if any) by exiting the current bash
session. If INCONTEXT is not set, then this will do nothing.

Options:
  -q  Be less verbose.
  -y  Don't prompt for confirmation before unloading the current
      context.
  -h  Show this usage output and return.
EOF
  :
}

function _incontext-unload() {
  local OPTIND=1 opt OPTARG
  local prompt_for_conf=1
  local be_less_verbose
  local reply
  while getopts ":qyh" opt; do
    case $opt in
      q) be_less_verbose=1 ;;
      y) prompt_for_conf= ;;
      h) _unload-incontext-usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done

  if [[ -z "$INCONTEXT" ]]; then
    echo "No context currently loaded." >&2
    return 0
  fi

  if [[ $prompt_for_conf == 1 ]]; then
    read -p "Unload current context '$INCONTEXT'? [Y/n] " -n 1 -r reply
    echo
    if [[ ! $reply =~ ^[Yy]$ ]]; then
      echo "Aborting context unload." >&2
      return 1
    fi
  fi

  echo "Unloading context '$INCONTEXT'..."
  exit
}

function _use-local-incontext-usage() {
  cat <<EOF
Usage: in-context use-local [options]
Usage: in-context use-local -h

By default, switches to the context specified by a .incontext file
in the current working directory or any of its ancestors (in the
current logical path) or unloads any currently loaded context if no
.incontext file is found. See the help for in-context use for more
details about loading contexts.

Options:
  -y  Don't prompt for confirmation before switching contexts or
      unloading the current context.
  -p  Look for a .incontext file in the physical path of the current
      working directory (dereferencing symlinks) instead of the
      logical path.
  -q  Be less verbose.
  -h  Show this usage output and return.
EOF
  :
}

function _incontext-use-local() {
  local OPTIND=1 opt OPTARG
  local prompt_for_conf=1
  local use_physical_path
  local be_less_verbose
  local reply
  while getopts ":ypqh" opt; do
    case $opt in
      y) prompt_for_conf= ;;
      p) use_physical_path=true ;;
      q) be_less_verbose=1 ;;
      h) _use-local-incontext-usage; return 0 ;;
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
    if [[ -f "$search_path/.incontext" ]]; then
      context_file="$search_path/.incontext"
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
    if [[ "$context_name" == "$INCONTEXT" ]]; then
      if [[ $be_less_verbose != 1 ]]; then
        echo "Already in context '$context_name'." >&2
      fi
      return 0
    fi
    _incontext-use "$context_name"
  else
    if [[ -n "$INCONTEXT" ]]; then
      if [[ $prompt_for_conf == 1 ]]; then
        read -p "No .incontext file found. Unload current context '$INCONTEXT'? [Y/n] " -n 1 -r reply
        echo
        if [[ ! $reply =~ ^[Yy]$ ]]; then
          echo "Aborting context unload." >&2
          return 1
        fi
      fi
      _incontext-unload -y ${be_less_verbose:+-q}
    else
      if [[ $be_less_verbose != 1 ]]; then
        echo "No .incontext file found and no context currently loaded." >&2
      fi
      return 0
    fi
  fi
}

function _incontext-usage() {
  cat <<EOF
Usage: in-context <subcommand> [arguments]
Usage: in-context -h

This script is intended to be located in your ~/.local/lib/
directory and sourced from near the start of your ~/.bashrc or
~/.bash_profile. It provides the in-context function for managing
your working context with the In Context project.

Each context runs in a separate bash session with environment
variables set according to the particular context. The INCONTEXT
environment variable is set to the name of the current context, and
other environment variables can be set as needed by the context.

For each context, there should be a <context-name>.context-start
file in the ~/.config/in-context/contexts/ directory, which is
sourced near the beginning of the .bashrc or .bash_profile of the
context's bash session. This file should set any environment
variables needed for the context, and optionally set
INCONTEXT_TITLE to a string to be used instead of the context name
as the title of the context in the prompt.

Each context may also optionally have a
<context-name>.context-finalize file in the
~/.config/in-context/contexts/ directory, which is sourced near the
end of the .bashrc or .bash_profile of the context's bash session.
This should perform any actions that require access to executables
and functions defined in the .bashrc or .bash_profile, such as pyenv
or nvm initialization.

Each context may also optionally have a
<context-name>.context-cleanup file in the
~/.config/in-context/contexts/ directory, which is sourced before
switching from one context to another.

If there is a file named _default.context-start in the
~/.config/in-context/contexts/ directory, then it will be sourced
when no context is loaded. Similarly, if there is a file named
_default.context-finalize in the ~/.config/in-context/contexts/
directory, then it will be sourced when no context is loaded.

If there is a file named _default.context-cleanup in the
~/.config/in-context/contexts/ directory, then it will be sourced
before switching from one context to another. If no cleanup file
is applicable, then the cleanup will consist of restoring the PATH
environment variable to what it was just before the current
context was loaded (from the INCONTEXT_PRE_PATH environment
variable).

If a cleanup file is applicable, and the PATH variable value should
be restored, then the cleanup file should use the
INCONTEXT_PRE_PATH environment variable to restore the PATH variable
to what it was before the current context was loaded.

A "local" context is defined by the presence of a .incontext file in
the current directory or any of its ancestors, which contains the
name of a context.

If you are using Git, then you should globally ignore .incontext
files by adding the following line to your ~/.config/git/ignore
file:

  .incontext

Subcommands:
  init-start      Initialize the In Context system.
  init-finalize   Finalize In Context initialization.
  prompt-title    Output the prompt title for the current context.
  use             Enter a named context.
  unload          Exit the current context shell.
  use-local       Use the nearest .incontext file.

Run "in-context <subcommand> -h" for subcommand-specific help.
EOF
  :
}

function in-context() {
  local OPTIND=1 opt OPTARG
  while getopts ":h" opt; do
    case $opt in
      h) _incontext-usage; return 0 ;;
      \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  local subcommand=$1
  shift || true

  case "$subcommand" in
    init-start) _incontext-init-start "$@" ;;
    init-finalize) _incontext-init-finalize "$@" ;;
    prompt-title) _incontext-prompt-title "$@" ;;
    use) _incontext-use "$@" ;;
    unload) _incontext-unload "$@" ;;
    use-local) _incontext-use-local "$@" ;;
    ""|-h|--help) _incontext-usage ;;
    *)
      echo "Unknown subcommand: $subcommand" >&2
      _incontext-usage >&2
      return 1
      ;;
  esac
}
