.. _changelog-2026-03-mar-expand-mg-workflow-commands:

2026-03 mar - expand mg workflow commands
=========================================

2026-03-22 - Sunday
-------------------

Refactored ``mg`` into modular command scripts and tightened branch-switch/remote handling semantics.

Change summary
--------------

- Split ``mg`` subcommands into ``home/dot_local/bin/my-git/cmd-*.sh`` modules, moved shared shell helpers to ``bash-lib.sh``/``git-lib.sh``, and switched dispatch to dynamic script loading.
- Moved per-command usage helpers into each subcommand file, keeping only top-level help aggregation in ``executable_mg``.
- Replaced global parsed-result state with bash nameref out-parameters for option/worktree outputs to reduce cross-file global coupling.
- Renamed helper namespaces and include guards for clarity (``gitlib_*``, ``_MG_INCLUDE_GUARD_*``, ``MG_INCLUDE_GUARD_*``).
- Simplified ``self-branch`` to require existing remotes (no ``--host`` or remote synthesis) and aligned ``alien-branch`` to explicitly enforce existing-remote checks.
- Updated ``switch`` to resolve missing local branches from ``origin`` first, then ``upstream``, and to fail with explicit guidance to ``mg new-branch <branch>`` when not found.
- Updated ``new-branch`` to ``cd`` into the newly created worktree, and refreshed wrappers/completions/tests/docs snapshots to match behavior.
- Moved implementation notes from ``home/dot_local/bin/my-git/README.md`` to :ref:`Git scripts <explanation-git-scripts>`.
- Split workflow vs implementation docs: ``git-workflow`` now embeds generated ``--example`` snapshots for core commands, and ``git-scripts`` now carries runtime/module internals.

2026-03-21 - Saturday
---------------------

Expanded ``mg`` workflows with stronger safety checks, richer usage docs, and new repository management commands.

Change summary
--------------

- Added safety preflight checks for branch-name validity, project/worktree path collisions, and remote/remote-branch checks.
- Clarified clone host-alias behavior, URL parsing semantics, and command usage output for ``--help`` and ``--example``.
- Added discovery commands: ``mg info`` and ``mg path``.
- Added branch lifecycle commands: ``mg remove-branch`` (merged-only removal) and ``mg prune``.
- Added local bare-path remote support for ``mg self-branch`` and ``mg alien-branch``.
- Added local bare-path source support and ``--dest`` destination override to ``mg clone``.
- Added ``MG_GIT_VERBOSE=1`` tracing mode to print executed shell commands.
- Updated Bash/Fish wrappers, Fish completions, and Bats coverage to align with new command behavior.

Related explanation
-------------------

- :ref:`Git workflow <explanation-git-workflow>`
- :ref:`Git scripts <explanation-git-scripts>`
