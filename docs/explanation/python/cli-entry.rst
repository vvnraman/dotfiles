.. _explanation-python-cli-entry:

CLI entry module
================

``python/src/dotfiles/main.py`` defines the Typer app and exposes the
top-level ``dotfiles`` commands.

High-level structure
--------------------

.. code-block:: text

   main.py
   |-- app callback: configure logging
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

- Resolves repository paths once at import time using ``resolve_project_dir``.
- Exposes docs lifecycle commands that shell out to Sphinx tools.
- Exposes CLI entrypoint for publish and delegates execution to ``dotfiles.publish``.
- Delegates Neovim sync/info behavior to ``dotfiles.nvim`` using request dataclasses.

Command routing
---------------

1. ``app = typer.Typer(...)`` registers top-level commands.
2. ``nvim_app = typer.Typer(...)`` registers nested ``nvim`` commands.
3. ``app.add_typer(nvim_app, name="nvim")`` binds nested routing.
4. ``publish`` resolves flags then calls ``dotfiles.publish`` functions.
5. ``nvim`` commands build ``NvimSyncWithMimicArgs`` / ``NvimInfoArgs``.
6. ``dotfiles.nvim`` resolves runtime/local paths and executes sync/info flow.

Safety checks
-------------

- ``publish`` entrypoint delegates branch/worktree checks to ``dotfiles.publish``.
- ``nvim`` branch/worktree checks run in ``dotfiles.nvim`` before sync execution.
