.. _changelog-2026-03-mar-refine-mg-branch-worktree-lifecycle:

2026-03 mar - refine mg branch/worktree lifecycle
=================================================

2026-03-29 - Sunday
-------------------

Refined ``mg`` branch creation and worktree removal workflows, with updated aliases and completion behavior.

Change summary
--------------

- Updated ``new-branch`` to default its base to the current branch on non-bare worktrees and added ``--from <branch>`` override support.
- Updated command/completion metadata so ``new-branch --from`` completes local and remote-short branch names.
- Clarified ``switch`` help text to state it does not create new branch names.
- Added ``remove-worktree`` with ``rw`` alias for worktree-only deletion and success output after a completed remove.
- Updated ``remove-branch`` to accept branch names or worktree basenames, and narrowed its alias to ``rb`` only.
- Updated Bash and Fish wrappers/completions plus Bats coverage to match the new branch/worktree lifecycle behavior.

Related explanation
-------------------

- :ref:`Git workflow <explanation-git-workflow>`
- :ref:`Git scripts <explanation-git-scripts>`
