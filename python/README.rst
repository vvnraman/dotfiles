***********************
python project workflow
***********************

This directory contains the Python CLI package that drives docs and sync workflows.

Useful docs links:

- `overview <../docs/intro/overview.rst>`_
- `getting-started <../docs/intro/getting-started.rst>`_

The docs publish host is configured via ``python/dotfiles-config.ini``
(``[publish].publish_host``) with builtin fallbacks.

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

  .. code-block:: console

     $ uv run --project "python" dotfiles install-tool

  Install ``dotfiles`` behavior (default):

  - installs ``dotfiles`` via ``uv tool install .``
  - requires a clean git worktree
  - requires branch ``master``
  - defaults to ``--dry-run``; pass ``--no-dry-run`` to execute

  Install ``dotfiles-dev`` behavior:

  .. code-block:: console

     $ uv run --project "python" dotfiles install-tool --dev

  - installs editable via ``uv tool install . --editable``
  - defaults to ``--no-dry-run``
  - installs into isolated uv tool dirs under ``~/.local/share/uv-dotfiles-dev/``
  - creates ``~/.local/bin/dotfiles-dev`` that executes that isolated editable tool
