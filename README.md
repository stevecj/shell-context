# Shell Context

A tool to load shell sessions configured for different projects.


## Description

When you work on several projects that each need different working
environments, Shell Context provides a simple way to manage that.

This is inpired by other tools such as direnv, but strives for
simplicity of implementation and fexibility in how it may be used
at the expense of some conveniences and security measures, though
Shell Context does have its own security advantages.

In order to properly support situations in which the project's
directory is available in 2 different environments such as a host
system and a container of 2 different containers where the working
environments should differ, the configuration instructions are stored
outside of the directory that specifies the context name.

As a nice side effect of this design, the context configuration files
cannot be accidentally committed to version control, possibly exposing
secrets or causing conflicts between collaborators.

Shell Context supports either bash or zsh shell types and no others at
this time.


## Usage

After Shell Context has been installed and configured, you can create a
new context by creating a new file in `~/.config/shell-context/contexts`
with the name of the context and a `.context-start` suffix. For example,
to create a context named `work`, create the file
`~/.config/shell-context/contexts/work.context-start` and add the
environment changes needed for that context. If you want the prompt to
display a label different from the context name, then also set
`SHELL\_CONTEXT\_TITLE` there.

For each context, you may also create a `\*.context-finalize` file for
context-specific setup that should run after the rest of the shell startup
has finished, such as commands that depend on tools or functions (e.g.
from `pyenv` or `nvm`) initialized elsewhere in your shell configuration.

All actions performed by Shell Context are invoked via the `shell-context`
command. At any time, you can run `shell-context -h` for a list of
available commands or `shell-context <command> -h` for details on a
specific command.

If there is cleanup that needs te be performed when switching from one
context to another, create a `\*.context-cleanup` file for that context.
If no cleanup file is defined for a context, then `PATH` will be
restored from `SHELL\_CONTEXT\_PRE\_PATH` as the default cleanup behavior.

Load a context with:

```bash
shell-context load work
```

That always launches a new nested shell session with the selected
context loaded, even if another context is already active. To leave that
context (exit the subshell) later, run the following, or just exit the
shell as you normally would:

```bash
shell-context unload
```

Shell Context also supports directory-local selection through a
`.shell-context` file. Place a file with a context name in a project
directory:

```text
work
```

Then, while in the project directory, run:

```bash
shell-context load-local
```

That command searches the current directory and its ancestors for the
nearest `.shell-context` file and loads the named context. If no local
context file applies while you are already in a named context, Shell
Context opens a nested default-context shell instead of unloading the
current shell session. If you use Git, add `.shell-context` to your
global ignore file so that project-local selections do not get
committed accidentally. See the help (using the `-h` option) for
`shell-context load-local` for more usage details.


## Installation and Configuration

Clone this repository to a location of your choice, such as
`~/.local/lib/shell-context`.

Create a symbolic link to the `src/shell-context.sh` file in a location
that your shell startup files can source, such as 
~/.local/lib/shell-context.sh`:

```bash
ln -s ~/.local/lib/shell-context/src/shell-context.sh ~/.local/lib/shell-context.sh
```

Then update your shell startup file:

* Bash interactive shells commonly use `~/.bashrc`
* Login shells may use `~/.bash\_profile`
* Zsh commonly uses `~/.zshrc`

Source the library near the beginning of the file, call
`shell-context init-start` immediately after it, and call
`shell-context init-finalize` near the end:

```bash
# early in ~/.bashrc, ~/.bash_profile, or ~/.zshrc
. "$HOME/.local/lib/shell-context.sh"
shell-context init-start

# the rest of your normal shell setup goes here

# near the end of the file
shell-context init-finalize
```

This split is intentional:

* `init-start` runs before the rest of your shell setup and loads the
  active context's `\*.context-start` file
* `init-finalize` runs after the rest of your startup and loads the
  active context's `\*.context-finalize` file, which is useful for
  context-specific setup that depends on tools initialized later in the
  startup sequence

Optionally, before sourcing the library, set and export...
* `SHELL\_CONTEXT\_AUTO` and/or `SHELL\_CONTEXT\_PATH\_SEARCH\_MODE` to
  customize the behavior of Shell Context.
* `SHELL\_CONTEXT\_AUTO` to a positive integer to enable automatic
 'local-context loading when you `cd` into a directory and to specify
 its maximum depth of context nesting.
* `SHELL\_CONTEXT\_PATH\_SEARCH\_MODE` to "physical" to have Shell
 Context search the physical path (with symlinks resolved) instead of
 the logical path when searching for `.shell-context` files.  See the
 help for `shell-context load-local` for more details.

Next, create the configuration directory:

```bash
mkdir -p ~/.config/shell-context/contexts
```

To temporarily disable Shell Context without removing your
configuration, create a file named `~/.config/shell-context/DISABLED`.
When that file exists, Shell Context will refuse all non-help commands
until you remove it.

Context behavior is defined by shell files in that directory. For a
context named `work`, the supported files are:

* `work.context-start` (required)
* `work.context-finalize` (optional)
* `work.context-cleanup` (optional)

You may also define `\_default.context-start`,
`\_default.context-finalize`, and/or `\_default.context-cleanup` files to
apply when no named context is active or when a context does not supply
its own cleanup behavior.

The `\*.context-start` file should contain the environment changes needed
for that context. If you want the prompt to display a label different
from the context name, then also set `SHELL\_CONTEXT\_TITLE` there.

The `\*.context-finalize` file is for context-specific setup that should
run after the rest of the shell startup has finished, such as commands
that depend on tools or functions initialized elsewhere in your shell
configuration.

Shell Context also exports `SHELL\_CONTEXT\_DEPTH` so nested context
shells can detect how deeply nested they are. A shell with no loaded
context initializes it to `0`, the first loaded context runs at depth
`1`, and each additional nested context shell increments it by `1`.

The `\*.context-cleanup` file runs in the newly started shell while it
is initializing after switching away from a context. If your context
modifies `PATH`, restore it from
`SHELL\_CONTEXT\_PRE\_PATH` in that cleanup file before applying the next
context's changes. If no cleanup file is defined for a context, then
`PATH` will be resored from `SHELL\_CONTEXT\_PRE\_PATH` automatically.

For example:

```bash
# ~/.config/shell-context/contexts/work.context-start
export PROJECT_ROOT=$HOME/src/work
export PATH=$PROJECT_ROOT/bin:$PATH
export SHELL_CONTEXT_TITLE=work
```

```bash
# ~/.config/shell-context/contexts/work.context-cleanup
export PATH=$SHELL_CONTEXT_PRE_PATH
export PYENV_VERSION=
```

If you want the current context to appear in your prompt, call
`shell-context prompt-title` from your prompt configuration. For
example, in Bash:

```bash
PS1='$(shell-context prompt-title -n "[%s] ")'"$PS1"
```

By default, `prompt-title` appends the current context depth when
`SHELL\_CONTEXT\_DEPTH` is 2 or greater, using the format ` (%s)`. Use
`-d` to change that depth suffix format or `-D` to change the minimum
depth at which it appears.


## Contact

Steve Jorgensen - stevej@stevej.name

Project Link: (none yet)

## Version History

No actual version history yet.

Example version history:
* 0.2
    * Various bug fixes and optimizations
    * See [commit change]() or See [release history]()
* 0.1
    * Initial Release

## License

This project is licensed under the MIT License - see the LICENSE.md file
for details

## Acknowledgments
* [direnv](https://direnv.net/)
