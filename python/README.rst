***********************
python project workflow
***********************

This directory contains the Python CLI package that drives docs and sync workflows.

Useful docs links:

- `overview <../docs/intro/overview.rst>`_
- `getting-started <../docs/intro/getting-started.rst>`_

The docs publish host is configured via ``python/src/dotfiles/dotfiles-config.ini``
(``[publish].publish_host``) with builtin fallbacks.

Source root resolution
======================

Global options on ``dotfiles``:

- ``--source-root``: explicit dotfiles git root override.
- ``--show-source-discovery``: print source-root resolution steps and exit.

Resolution precedence:

1. ``--source-root``
2. runtime package path walk-up to ``.chezmoiroot`` / ``.git``
3. ``[paths].git_root`` from ``python/src/dotfiles/dotfiles-config.ini``
4. ``chezmoi source-path`` walk-up to ``.chezmoiroot`` / ``.git``
5. ``CHEZMOI_DOTFILES_PATH_OVERRIDE``

If ``--source-root`` is provided and invalid, resolution stops and exits with an
error.

This allows ``uv run --project python dotfiles ...`` to resolve the checkout
where it is executed, while installed ``dotfiles`` can still fall back to
configured canonical paths.

- Install dependencies:

  .. code-block:: console

     $ uv sync --project "python"

- Build docs:

  .. code-block:: console

     $ uv run --project "python" dotfiles docs

- Live docs server:

  .. code-block:: console

     $ uv run --project "python" dotfiles live

- Neovim sync command help:

  .. code-block:: console

     $ uv run --project "python" dotfiles nvim --help

- Neovim sync only copies runtime Neovim config state into local chezmoi source;
  it does not sync docs or Python project files.

- Install uv tool entrypoints with branch/worktree mode detection:

  The installer is repo-only (``python/scripts/install_tool.py``) and is not
  exposed as a ``dotfiles`` subcommand.

  .. code-block:: console

     $ make install

  Install ``dotfiles`` behavior (default):

  - installs ``dotfiles`` via ``uv tool install .``
  - requires a clean git worktree
  - requires branch ``master``
  - defaults to ``--dry-run``; pass ``--no-dry-run`` to execute
  - optional dirty custom path mode:

    .. code-block:: console

       $ make install args='--dirty-install-path /tmp/dotfiles-bin --no-dry-run'

  Install ``dotfiles-dev`` behavior:

  .. code-block:: console

     $ make install-dev

  - installs editable via ``uv tool install . --editable``
  - defaults to ``--no-dry-run``
  - installs into isolated uv tool dirs under ``~/.local/share/uv-dotfiles-dev/``
  - creates ``~/.local/bin/dotfiles-dev`` that executes that isolated editable tool
