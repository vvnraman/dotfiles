.. _changelog-2026-03-mar-rework-python-installer-and-cli-discovery:

2026-03 mar - rework python installer and cli discovery
=======================================================

2026-03-15 - Sunday
-------------------

Moved installer execution out of the packaged CLI and tightened source-root resolution behavior.

Change summary
--------------

- Removed ``install-tool`` from ``dotfiles`` CLI and introduced repo-only installer entrypoint at
  ``python/scripts/install_tool.py``.

- Added installer library orchestration in ``python/scripts/install_tool_lib.py`` with branch/worktree
  safety checks, dev install isolation, and dirty custom-path isolation.

- Updated docs command execution in ``python/src/dotfiles/main.py`` to use
  ``sys.executable -m sphinx`` and related module invocations so installed entrypoints and ``uv run``
  flows resolve tooling from the active interpreter.

- Updated source discovery logging in ``python/src/dotfiles/paths.py`` to include the config file path
  when reading ``[paths].git_root``.

- Updated CLI help snapshot generation in ``python/src/dotfiles/sphinxext/help_generator.py`` to invoke
  help via ``python -m dotfiles.main`` while preserving displayed ``dotfiles ...`` commands.

Related docs
------------

- :ref:`Build and install standalone <python-build-and-install>`
- :ref:`CLI entry module <explanation-python-cli-entry>`
- :ref:`dotfiles CLI help <reference-python-dotfiles-cli>`
