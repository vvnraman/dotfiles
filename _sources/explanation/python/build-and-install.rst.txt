.. _python-build-and-install:

############################
Build and install standalone
############################

This runbook explains how to install stable and editable ``dotfiles`` CLI
entrypoints.

Repo installer entrypoint
=========================

Install orchestration is repo-only and is not exposed as a ``dotfiles``
subcommand.

- Preferred entrypoints are ``make install`` and ``make install-dev``.
- The underlying script is ``python/scripts/install_tool.py``.
- This avoids self-reinstall behavior from an already-installed ``dotfiles``
  executable.

Build artifacts
===============

Run from repository root:

.. code-block:: console

   $ uv build --project python

This writes artifacts to ``python/dist/``:

- ``dotfiles-<version>.tar.gz``
- ``dotfiles-<version>-py3-none-any.whl``

Install stable entrypoint
=========================

Run from repository root on ``master`` with a clean worktree:

.. code-block:: console

   $ make install

This installs ``dotfiles`` via ``uv tool install .``.

The following should work from any directory after this:

.. code-block:: console

   $ dotfiles --help

Install editable dev entrypoint
===============================

Run from repository root on our current branch:

.. code-block:: console

   $ make install-dev

This installs editable ``dotfiles`` via ``uv tool install . --editable`` into
isolated uv tool directories and sets up a wrapper script at ``~/.local/bin/dotfiles-dev``.

The following should work from any directory after this:

.. code-block:: console

   $ dotfiles-dev --help

This should reflect changes in the code without needing to re-install ``--dev``.

Install mode behavior
=====================

- default mode requires clean worktree on branch ``master``
- default mode uses ``--dry-run`` unless ``--no-dry-run``
- ``--dev`` skips clean-worktree and branch checks
- ``--dev`` defaults to ``--no-dry-run``

Custom install path isolation
=============================

When the repo installer uses a custom non-default install path (with
``--dirty-install-path``), the tool install also uses an
isolated uv data directory.

That uv data directory is derived from a short SHA digest of the normalized
install path, so each custom install path gets a stable, unique uv tool home and does
not overwrite the default ``~/.local/share/uv/tools`` environment.

Relevant changelogs
-------------------

- :ref:`2026-03-mar - rework python installer and cli discovery <changelog-2026-03-mar-rework-python-installer-and-cli-discovery>`
