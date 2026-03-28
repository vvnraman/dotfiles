.. _changelog-2026-03-mar-add-mg-layout-aware-worktrees:

2026-03 mar - add mg layout aware worktrees
===========================================

2026-03-28 - Saturday
---------------------

Added layout-aware worktree path resolution in ``mg`` so branch creation and switching follow repository structure automatically.

Change summary
--------------

- Added layout detection in ``git-lib.sh`` for ``default``, ``parent-bare-siblings``, ``bare-siblings.git``, and ``bare-siblings``.
- Added centralized worktree path resolution helpers that preserve repo-root default branch behavior in ``default`` layout and route new branches under ``<repo>-worktrees``.
- Updated bare sibling handling to place new worktrees as siblings of the default branch worktree parent, including cases where that parent is the bare repo directory itself.
- Replaced hardcoded relative ``git worktree add`` targets in command handlers with shared ``gitlib_worktree_add_*`` helpers.
- Updated ``mg info`` inventory output to include layout and path guidance fields (``Layout``, ``Parent``, ``Default worktree``, ``New sample worktree``).
- Split shell integration tests by layout into separate Bats files and added layout-specific assertions for path placement and inventory output.

Related explanation
-------------------

- :ref:`Git workflow <explanation-git-workflow>`
- :ref:`Git scripts <explanation-git-scripts>`
