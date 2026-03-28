.. _explanation-git-scripts:

Git scripts
===========

``home/dot_local/bin/executable_mg`` and ``home/dot_local/bin/my-git`` implement the ``mg`` runtime.
This page documents runtime layout and completion integration. For user-facing command usage, see
:ref:`Git workflow <explanation-git-workflow>`.

Runtime layout
--------------

- ``home/dot_local/bin/executable_mg``: entrypoint, alias resolution, dynamic command loading, top-level help, and ``__complete-metadata`` output for shell completions.
- ``home/dot_local/bin/my-git/cmd-*.sh``: subcommand handlers and per-command ``_usage_*`` blocks.
- ``home/dot_local/bin/my-git/git-lib.sh``: shared git helpers (``gitlib_*``).
- ``home/dot_local/lib/bash-lib.sh``: shared generic helpers (``lib_*``).
- ``home/dot-bash/bashrc.d/bashrc-git.sh``: aliases and ``mg`` loader function for Bash.
- ``home/dot-bash/completions/mg.bash``: metadata-driven Bash completions for commands/options/remotes/branches.
- ``home/dot_config/fish/functions/mg.fish``: Fish wrapper that executes the Bash ``mg`` script and handles ``cd`` follow-up behavior.
- ``home/dot_config/fish/completions/mg.fish``: metadata-driven Fish completion registration.

How dispatch works
------------------

- Entrypoint is ``my_git_main()`` in ``home/dot_local/bin/executable_mg``.
- ``my_git_main()`` resolves single-letter aliases (``u``, ``c``, ``s``, ``n``, ``b``, ``i``, ``r``).
- ``_run_subcommand()`` loads ``cmd-<name>.sh`` on demand and dispatches to ``_cmd_<name>``.
- Name transform rule: ``-`` in subcommand names maps to ``_`` in function names.
  - Example: ``self-branch`` -> ``cmd-self-branch.sh`` -> ``_cmd_self_branch``.

Completion metadata flow
------------------------

- ``home/dot_local/bin/executable_mg`` exposes ``__complete-metadata`` with command names, aliases, options, and argument-position hints.
- ``home/dot-bash/completions/mg.bash`` reads that metadata and applies Bash completion behavior.
- ``home/dot_config/fish/completions/mg.fish`` reads the same metadata and registers Fish completions.
- ``switch``, ``new-branch``, ``path``, and ``remove-branch`` complete branch names from local branches plus remote-short names.
- ``self-branch`` and ``alien-branch`` complete a remote first, then branch names filtered to that remote.

Why sourced files can share helpers
-----------------------------------

``source`` (``.``) executes files in the current shell process, so functions and variables are shared across sourced files.

- Command modules call shared helpers from ``git-lib.sh``.
- ``mg --help`` can aggregate per-command ``_usage_*`` functions after loading command scripts.

Bash wrapper runtime
--------------------

``home/dot-bash/bashrc.d/bashrc-git.sh`` defines ``mg`` as a shell function that resolves and sources
the installed ``mg`` script once, then calls ``my_git_main`` directly.

- ``home/dot-bash/bashrc.d/bashrc-git.sh`` keeps shell aliases plus script-loading logic.
- ``home/dot-bash/completions/mg.bash`` provides completion behavior and is sourced by the Bash wrapper file.

Fish wrapper runtime
--------------------

``home/dot_config/fish/functions/mg.fish`` defines ``mg`` as a Fish function that resolves the script
path and invokes it through ``bash``.

- ``home/dot_config/fish/conf.d/git-config.fish`` provides abbreviations and the ``lg`` alias.
- ``home/dot_config/fish/functions/mg.fish`` delegates command execution to bash ``mg`` and then, for
  ``switch``/``new-branch`` success paths, resolves ``mg path <branch>`` and applies ``cd`` in the current Fish shell.
- ``home/dot_config/fish/completions/mg.fish`` loads metadata from ``mg`` and registers completions.

Include guards
--------------

``mg`` uses include-guard variables to avoid re-sourcing files.

- ``home/dot_local/lib/bash-lib.sh`` uses ``MG_INCLUDE_GUARD_BASH_LIB_LOADED``.
- ``home/dot_local/bin/my-git/git-lib.sh`` uses ``MG_INCLUDE_GUARD_GIT_LIB_LOADED``.
- ``home/dot_local/bin/executable_mg`` uses ``_MG_INCLUDE_GUARD_SUBCOMMAND_SCRIPTS`` (associative array keyed by subcommand).

Naming assumptions
------------------

Loader conventions:

- File names: ``cmd-<subcommand>.sh``
- Handler functions: ``_cmd_<subcommand-with-underscores>``
- Usage functions: ``_usage_<subcommand-with-underscores>``
- Shared git helper names: ``gitlib_<name>``

Prefix meaning in command scripts:

- ``gitlib_*``: shared helpers from ``git-lib.sh``
- ``lib_*``: generic string/path helpers from ``home/dot_local/lib/bash-lib.sh``
- ``_cmd_*`` and ``_usage_*``: subcommand-local interface

When adding a subcommand
------------------------

- Add ``cmd-<subcommand>.sh`` in ``home/dot_local/bin/my-git``.
- Define ``_cmd_<subcommand-with-underscores>`` and ``_usage_<subcommand-with-underscores>``.
- Register script mapping in ``_subcommand_script_path()`` in ``home/dot_local/bin/executable_mg``.
- Add metadata rows in ``_print_completion_metadata()`` for ``cmd``, ``opts``, and any ``branch``/``remote`` hints used by completion.

Relevant changelogs
-------------------

- :ref:`2026-03-mar - document mg completions and help <changelog-2026-03-mar-document-mg-completions-and-help>`
- :ref:`2026-03-mar - expand mg workflow commands <changelog-2026-03-mar-expand-mg-workflow-commands>`
