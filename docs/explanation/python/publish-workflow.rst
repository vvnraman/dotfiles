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
   |-- docs path resolver
   |   `-- DocsPaths via _docs_paths
   |-- config resolution
   |   |-- python/src/dotfiles/dotfiles-config.ini defaults
   |   |-- *_OVERRIDE environment overrides
   |   `-- CLI flag overrides
   `-- publish execution
        |-- clean worktree + branch checks
        |-- optional docs build
        `-- _publish_docs
            |-- commit message generation
            `-- gh-pages push command plan

- ``publish_with_config`` resolves config and applies safety checks.
- ``_docs_paths`` computes ``docs``/``_build``/``html`` once and shares it across build/publish steps.
- ``_publish_docs`` builds the publish command plan and executes it.
- ``dotfiles.git`` provides shared git helpers for branch/clean checks scoped to ``project_dir``.
- Docs build output for publish targets ``docs/_build/html``.

Execution order
---------------

1. ``main.publish`` builds a ``PublishArgs`` request from CLI flags.
2. ``publish_with_config`` resolves precedence: flag, env, ini default from
   ``python/src/dotfiles/dotfiles-config.ini``.
3. ``publish_with_config`` verifies clean worktree and branch policy.
4. For non-dry-run, docs are built before publish command execution.
5. ``_publish_docs`` commits HTML output and pushes ``gh-pages``.
