.. _explanation-git-workflow:

Git workflow
============

.. literalinclude:: ../generated/mg-short-help.txt
   :language: text
   :caption: mg -h output

``mg`` is the shared git workflow command installed at ``~/.local/bin/mg`` from
``home/dot_local/bin/executable_mg``. It manages the bare-plus-worktree layout I use.

Overview
^^^^^^^^

- ``VVN_DOTFILES_GITHUB_HOST`` sets default host for ``mg clone`` org/repo form.
- If unset, default host is ``github``.
- ``mg`` detects repository layout automatically: ``default``, ``parent-bare-siblings``, ``bare-siblings.git``, and ``bare-siblings``.
- ``mg info`` prints ``Layout``, ``Parent``, ``Default worktree``, and ``New sample worktree`` so worktree placement is explicit before branch creation.
- ``switch`` moves to an existing branch worktree and does not create brand-new branch names.
- ``new-branch`` defaults its base to the current branch on non-bare worktrees; use ``--from <branch>`` to override.
- ``remove-branch`` (alias ``rb``) removes merged branch/worktree state and accepts branch names or worktree basenames.
- ``remove-worktree`` (alias ``rw``) removes only the worktree and keeps the local branch ref.
- ``switch``, ``new-branch``, ``path``, ``remove-branch``, and ``remove-worktree`` complete branch names from local branches plus remote-short names.
- ``new-branch --from`` completes base branch names.
- ``self-branch`` and ``alien-branch`` complete the second argument from branches that exist on the selected remote.

Common command examples
-----------------------

.. dropdown:: Show ``mg init --example`` output

   .. literalinclude:: ../generated/mg-init-example.txt
      :language: text
      :caption: mg init --example output

.. dropdown:: Show ``mg clone --example`` output

   .. literalinclude:: ../generated/mg-clone-example.txt
      :language: text
      :caption: mg clone --example output

.. dropdown:: Show ``mg switch --example`` output

   .. literalinclude:: ../generated/mg-switch-example.txt
      :language: text
      :caption: mg switch --example output

.. dropdown:: Show ``mg new-branch --example`` output

   .. literalinclude:: ../generated/mg-new-branch-example.txt
      :language: text
      :caption: mg new-branch --example output

.. dropdown:: Show ``mg self-branch --example`` output

   .. literalinclude:: ../generated/mg-self-branch-example.txt
      :language: text
      :caption: mg self-branch --example output

.. dropdown:: Show ``mg alien-branch --example`` output

   .. literalinclude:: ../generated/mg-alien-branch-example.txt
      :language: text
      :caption: mg alien-branch --example output

mg command help
---------------

.. dropdown:: Show ``mg --help`` output

   .. literalinclude:: ../generated/mg-help.txt
      :language: text
      :caption: mg --help output

Implementation details
----------------------

- ``<host-alias>`` refers to our SSH alias in ``~/.ssh/config``.
- ``MG_GIT_VERBOSE=1`` enables shell tracing for ``mg`` command execution.
- See :ref:`Git scripts <explanation-git-scripts>` for runtime dispatch, include guards, and wrapper internals.

Relevant changelogs
-------------------

- :ref:`2026-03-mar - add mg layout aware worktrees <changelog-2026-03-mar-add-mg-layout-aware-worktrees>`
- :ref:`2026-03-mar - refine mg branch/worktree lifecycle <changelog-2026-03-mar-refine-mg-branch-worktree-lifecycle>`
- :ref:`2026-03-mar - document mg completions and help <changelog-2026-03-mar-document-mg-completions-and-help>`
- :ref:`2026-03-mar - expand mg workflow commands <changelog-2026-03-mar-expand-mg-workflow-commands>`
- :ref:`2026-03-mar - consolidate mg git workflow wrappers <changelog-2026-03-mar-consolidate-mg-git-workflow-wrappers>`
