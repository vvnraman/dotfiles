.. _explanation-python-cli-entry:

CLI entry module
================

``python/src/dotfiles/main.py`` defines the Typer app and exposes the
top-level ``dotfiles`` commands.

High-level structure
--------------------

.. code-block:: text

   main.py
   |-- app callback: logging + source-root context
   |-- project path resolver
   |   `-- ProjectPaths via _project_paths
   |-- top-level commands
   |   |-- info
   |   |-- docs
   |   |-- live
   |   |-- clean
   |   |-- publish
   |   `-- init-docs
   `-- nvim subcommands
       |-- nvim sync
       `-- nvim info

- Resolves repository paths lazily via ``resolve_project_dir`` during command execution.
- Computes ``project_dir``/``docs``/``_build``/``html`` once via ``ProjectPaths``.
- Prefers runtime package ancestry for checkout-local execution before configured canonical fallback.
- Exposes docs lifecycle commands through ``sys.executable -m sphinx`` module invocations.
- Exposes CLI entrypoint for publish and delegates execution to ``dotfiles.publish``.
- Delegates Neovim sync/info behavior to ``dotfiles.nvim`` using request dataclasses.
- Handles source-root discovery diagnostics through ``--show-source-discovery``.

Command routing
---------------

1. ``app = typer.Typer(...)`` registers top-level commands.
2. ``nvim_app = typer.Typer(...)`` registers nested ``nvim`` commands.
3. ``app.add_typer(nvim_app, name="nvim")`` binds nested routing.
4. Callback wires ``--source-root`` override into path resolution context.
5. Path resolution tries runtime package ancestry before config and chezmoi fallbacks.
6. ``publish`` resolves flags then calls ``dotfiles.publish`` functions.
7. ``nvim`` commands build ``NvimSyncWithMimicArgs`` / ``NvimInfoArgs``.
8. ``dotfiles.nvim`` resolves runtime/local paths and executes sync/info flow.

Safety checks
-------------

- ``publish`` entrypoint delegates branch/worktree checks to ``dotfiles.publish``.
- ``nvim`` branch/worktree checks run in ``dotfiles.nvim`` before sync execution.
- Source-root resolution failures are surfaced as actionable CLI errors.

Relevant changelogs
-------------------

- :ref:`2026-03-mar - rework python installer and cli discovery <changelog-2026-03-mar-rework-python-installer-and-cli-discovery>`
- :ref:`2026-03-mar - refactor python cli config and nvim io <changelog-2026-03-mar-refactor-python-cli-config-and-nvim-io>`
