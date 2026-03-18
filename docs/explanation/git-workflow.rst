.. _explanation-git-workflow:

Git workflow
============

``mg`` is the shared git workflow command installed at ``~/.local/bin/mg`` from
``home/dot_local/bin/executable_mg``. It manages the bare-plus-worktree layout used in this repo
and is called by both Bash and Fish wrappers.

mg command reference
--------------------

- ``mg update-commit-date`` amends ``HEAD`` with the current timestamp as author and committer date.
- ``mg init <project>`` creates ``<project>.git/bare``, adds default branch worktree, and creates an
  empty initial commit.
- ``mg clone [--host <host>] <org> <repo>`` creates ``<repo>.git/bare`` from ``<host>:<org>/<repo>``.
- ``mg clone [--host <host>] <url>`` parses host/org/repo from URL-like input.
- ``mg show-ignored`` lists ignored files in the current repository.
- ``mg show-untracked`` lists untracked files in the current repository.
- ``mg switch <branch>`` changes into ``<project>.git/<branch>`` worktree if present; if branch exists
  without worktree it creates that worktree; if branch does not exist it delegates to ``new-branch``.
- ``mg new-branch <branch>`` creates ``<project>.git/<branch>`` from current bare repository.
- ``mg branch-new-remote [--host <host>] [--url <remote-url>] <remote> <branch>`` ensures remote URL,
  then creates ``<project>.git/<remote>_<branch>`` tracked from ``<remote>/<branch>``.
- ``mg branch-existing-remote <remote> <branch>`` creates ``<project>.git/<remote>_<branch>`` from an
  already configured remote branch.

Defaults and env
^^^^^^^^^^^^^^^^

- ``VVN_DOTFILES_GITHUB_HOST`` sets default host for clone and derived remote URLs.
- If unset, default host is ``github``.

Bash wrapper
------------

``home/dot-bash/bashrc.d/bashrc-git.sh`` defines ``mg`` as a shell function that resolves and sources
the installed ``mg`` script once, then calls ``my_git_main`` directly for low per-command overhead.

- ``git-*`` helper functions (for example ``git-clone`` and ``git-new-branch``) delegate to ``mg``.
- ``git-switch`` delegates to ``mg switch``.

Fish wrapper
------------

``home/dot_config/fish/functions/mg.fish`` defines ``mg`` as a Fish function that resolves the script
path and invokes it through ``bash``.

- ``home/dot_config/fish/conf.d/git-config.fish`` exposes ``git-*`` wrappers that delegate to ``mg``.
- ``git-switch`` delegates to ``mg switch``.
- ``home/dot_config/fish/completions/mg.fish`` provides subcommand and option completions for ``mg``.

Relevant changelogs
-------------------

- :ref:`2026-03-mar - consolidate mg git workflow wrappers <changelog-2026-03-mar-consolidate-mg-git-workflow-wrappers>`
