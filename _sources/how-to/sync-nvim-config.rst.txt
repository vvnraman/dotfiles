.. _how-to-sync-nvim-config:

################
Sync nvim config
################

Preview sync impact
===================

.. code-block:: sh

   make nvim-info

Run dry-run sync
================

Sync with nvim config, dry-run by default

.. code-block:: sh

   make nvim-sync

The sync command validates that runtime nvim is on ``master`` unless an
override branch name is provided. If we're not on `master` at `~/.config/nvim/` (we're on `dev`
almost always)

.. code-block:: sh

   make nvim-sync args="--override-branch-name=dev"

Mimic sync run (destructive)
============================

Mimics the sync by copying the local `chezmoi` nvim config to a temp directory first and run the
real sync.

.. code-block:: sh

   make nvim-sync args="--override-branch-name=dev --mimic"

Run real sync (destructive)
===========================

.. code-block:: sh

   make nvim-sync args="--override-branch-name=dev --no-dry-run"
