.. _changelog-2026-03-mar-document-mg-completions-and-help:

2026-03 mar - document mg completions and help
==============================================

2026-03-28 - Saturday
---------------------

Documented metadata-driven ``mg`` completions and refreshed short-help workflow snapshots.

Change summary
--------------

- Added generated ``docs/generated/mg-short-help.txt`` and included it directly under :ref:`Git workflow <explanation-git-workflow>` title.
- Renamed ``Defaults and env`` to ``Overview`` in ``git-workflow`` and documented branch completion behavior for branch-only and remote-plus-branch commands.
- Updated :ref:`Git scripts <explanation-git-scripts>` to describe the dedicated Bash completion file and metadata flow from ``__complete-metadata``.
- Documented wrapper simplification where Bash and Fish now use ``mg`` directly without ``git-*`` delegator functions.

Related explanation
-------------------

- :ref:`Git workflow <explanation-git-workflow>`
- :ref:`Git scripts <explanation-git-scripts>`
