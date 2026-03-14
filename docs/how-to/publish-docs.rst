.. _how-to-publish-docs:

############
Publish docs
############

Generate & publish commands
===========================

- Generate docs

   .. code-block:: sh

      make docs

      # or manually
      uv run --project python dotfiles docs

- Publish docs (dry run)

   .. code-block:: sh

      uv run --project python dotfiles publish --dry-run

- Optional publish overrides

   .. code-block:: sh

      uv run --project python dotfiles publish --dry-run --remote-name=public
      uv run --project python dotfiles publish --dry-run --dotfiles-repo=vvnraman/dotfiles
      uv run --project python dotfiles publish --dry-run --github-url=https://github.example.com

If flags are not provided, publish uses ``python/dotfiles-config.ini`` defaults,
then ``*_OVERRIDE`` environment variables.

Publish from current branch
===========================

.. code-block:: sh

   uv run --project python dotfiles publish --no-dry-run --override-branch=<branch-name>

The publish workflow requires a clean worktree and enforces branch checks.
