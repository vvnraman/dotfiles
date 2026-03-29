.. _changelog-2026-03-mar-consolidate-mg-git-workflow-wrappers:

2026-03 mar - consolidate mg git workflow wrappers
==================================================

2026-03-18 - Wednesday
----------------------

Consolidated Bash and Fish git workflow behavior behind a shared ``mg`` command.

Change summary
--------------

- Added shared ``mg`` command implementation at ``~/.local/bin/mg`` from ``executable_mg``.
- Switched Bash and Fish ``git-*`` helper functions to thin wrappers that delegate to ``mg``.
- Added ``mg switch <branch>`` workflow to move into existing worktrees or create branch worktrees.
- Added Fish completions for ``mg`` subcommands and ``--host``/``--url`` options.
- Added unified shell test coverage for Bash and Fish wrapper behavior via Bats.

Related explanation
-------------------

- :ref:`Git workflow <explanation-git-workflow>`
