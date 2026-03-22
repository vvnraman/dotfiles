.. _explanation-git-scripts:

Git scripts
===========

``home/dot_local/bin/executable_mg`` and ``home/dot_local/bin/my-git`` implement the ``mg`` runtime.
This page documents code layout and dispatch behavior. For user-facing command usage, see
:ref:`Git workflow <explanation-git-workflow>`.

Runtime layout
--------------

- ``home/dot_local/bin/executable_mg``: entrypoint, dispatch table, dynamic loader, top-level ``mg --help`` aggregation.
- ``home/dot_local/bin/my-git/cmd-*.sh``: subcommand handlers and per-command ``_usage_*`` blocks.
- ``home/dot_local/bin/my-git/git-lib.sh``: shared git helpers (``gitlib_*``).
- ``home/dot_local/lib/bash-lib.sh``: shared generic helpers (``lib_*``).

How dispatch works
------------------

- Entrypoint is ``my_git_main()`` in ``home/dot_local/bin/executable_mg``.
- ``my_git_main()`` calls ``_run_subcommand "<name>" "$@"``.
- ``_run_subcommand()`` resolves and sources ``cmd-<name>.sh``, then calls ``_cmd_<name>``.
- Name transform rule: ``-`` in subcommand names maps to ``_`` in function names.
  - Example: ``self-branch`` -> ``cmd-self-branch.sh`` -> ``_cmd_self_branch``.

Why sourced files can share helpers
-----------------------------------

``source`` (``.``) executes files in the current shell process, so functions and variables are shared across sourced files.

- Command modules call shared helpers from ``git-lib.sh``.
- ``mg --help`` can aggregate per-command ``_usage_*`` functions after loading command scripts.

Bash wrapper runtime
--------------------

``home/dot-bash/bashrc.d/bashrc-git.sh`` defines ``mg`` as a shell function that resolves and sources
the installed ``mg`` script once, then calls ``my_git_main`` directly.

- ``git-*`` helper shell functions delegate to ``mg``.
- ``git-switch`` delegates to ``mg switch``.

Fish wrapper runtime
--------------------

``home/dot_config/fish/functions/mg.fish`` defines ``mg`` as a Fish function that resolves the script
path and invokes it through ``bash``.

- ``home/dot_config/fish/conf.d/git-config.fish`` exposes ``git-*`` wrappers that delegate to ``mg``.
- ``home/dot_config/fish/functions/mg.fish`` delegates command execution to bash ``mg`` and then, for
  ``switch``/``new-branch`` success paths, resolves ``mg path <branch>`` and applies ``cd`` in the current Fish shell.
- ``home/dot_config/fish/completions/mg.fish`` provides subcommand and option completions.

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

Relevant changelogs
-------------------

- :ref:`2026-03-mar - expand mg workflow commands <changelog-2026-03-mar-expand-mg-workflow-commands>`
