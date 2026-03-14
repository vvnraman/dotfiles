.. _changelog-2026-03-mar-refactor-python-cli-config-and-nvim-io:

2026-03 mar - refactor python cli config and nvim io
====================================================

2026-03-13 - Friday
-------------------

Updated nvim sync internals and CLI publish configuration defaults.

Change summary
--------------

- Added ``DiskAccessor`` read abstraction in ``python/src/dotfiles/nvim.py`` to make orchestration
  testing deterministic without filesystem monkeypatching.

- Added publish configuration resolution and execution split between ``python/src/dotfiles/main.py``
  and ``python/src/dotfiles/publish.py`` with CLI flags, ini defaults, and ``*_OVERRIDE``
  environment fallbacks.

- Added repo-level publish defaults in ``python/dotfiles-config.ini`` for remote name, dotfiles
  repo, and github base URL.

- Updated CLI help snapshot generation in ``python/src/dotfiles/sphinxext/help_generator.py`` to
  generate both top-level and ``nvim`` help outputs.

Related docs
------------

- :ref:`Neovim sync module <explanation-python-nvim-sync>`
- :ref:`CLI entry module <explanation-python-cli-entry>`
- :ref:`Publish workflow module <explanation-python-publish-workflow>`
- :ref:`Sync nvim config <how-to-sync-nvim-config>`
- :ref:`Publish docs <how-to-publish-docs>`
- :ref:`dotfiles CLI help <reference-python-dotfiles-cli>`
