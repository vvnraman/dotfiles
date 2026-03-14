.. _explanation-python-publish-workflow:

Publish workflow module
=======================

``python/src/dotfiles/publish.py`` owns docs publish configuration resolution and
the GitHub Pages publish execution flow.

High-level structure
--------------------

.. code-block:: text

   publish.py
   |-- PublishArgs request model
   |-- config resolution
   |   |-- python/src/dotfiles/dotfiles-config.ini defaults
   |   |-- *_OVERRIDE environment overrides
   |   `-- CLI flag overrides
   `-- publish execution
       |-- clean worktree + branch checks
       |-- optional docs build
       `-- publish_docs
           |-- commit message generation
           `-- gh-pages push command plan

- ``publish_with_config`` resolves config and applies safety checks.
- ``publish_docs`` builds the publish command plan and executes it.
- ``dotfiles.git`` provides shared git helpers for branch/clean checks.

Execution order
---------------

1. ``main.publish`` builds a ``PublishArgs`` request from CLI flags.
2. ``publish_with_config`` resolves precedence: flag, env, ini default from
   ``python/src/dotfiles/dotfiles-config.ini``.
3. ``publish_with_config`` verifies clean worktree and branch policy.
4. For non-dry-run, docs are built before publish command execution.
5. ``publish_docs`` commits HTML output and pushes ``gh-pages``.
