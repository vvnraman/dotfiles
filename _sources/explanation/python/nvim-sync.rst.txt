.. _explanation-python-nvim-sync:

Neovim sync module
==================

``python/src/dotfiles/nvim.py`` computes sync plans and applies runtime Neovim
state into ``home/dot_config/nvim``.

High-level structure
--------------------

.. code-block:: text

   nvim.py
   |-- snapshot models
   |   |-- NvimPathPair
   |   |-- NvimLuaSubdirManifest
   |   |-- NvimSubdirManifest
   |   `-- NvimSyncPlan / NvimSyncInfoCounts
   |-- abstractions
   |   |-- ShellOp (writes)
   |   `-- DiskAccessor (reads)
   |-- request models
   |   |-- NvimSyncWithMimicArgs
   |   `-- NvimInfoArgs
   |-- plan and diff helpers
   `-- orchestration
       |-- nvim_sync
       |-- nvim_sync_with_mimic
       `-- nvim_info

- Builds a snapshot plan from runtime and local manifests.
- Splits file changes into add, update, unchanged buckets.
- Removes missing runtime entries and copies changed runtime entries.
- Computes managed-surface counts for ``dotfiles nvim info``.
- Resolves runtime/local paths and branch/worktree prechecks in one place.

Sync flow
---------

1. ``nvim_sync_with_mimic`` resolves runtime/local paths from request args.
2. It validates runtime git cleanliness and branch policy.
3. ``nvim_sync`` resolves ``ShellOp`` from ``dry_run`` and builds sync plan.
4. Removes explicit top-level targets except ``lua``.
5. Prunes missing runtime files/directories from local ``lua``.
6. Copies non-``lua`` base targets and changed top-level files.
7. Copies changed ``lua`` files while preserving protected templates.

Info flow
---------

- ``nvim_collect_sync_info_counts`` computes totals and add/update/remove counts
  from the same plan model used by sync.
- ``nvim_info`` logs those counts and returns the structured summary.

Mimic flow
----------

- ``nvim_sync_with_mimic`` can run sync against a temporary copy of local nvim.
- It then runs ``nvim_info`` against the mimicked directory to verify no pending
  managed-surface changes remain.
