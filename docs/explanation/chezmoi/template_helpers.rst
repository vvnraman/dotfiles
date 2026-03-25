.. _explanation-chezmoi-template-helpers:

Chezmoi template helpers
========================

This page documents helper templates used across multiple rendered files.

expand-executable-paths.tmpl
----------------------------

- Input: full template context (``.``).
- Behavior: reads ``.executable_paths`` for ``.chezmoi.os``, prepends ``.chezmoi.homeDir`` for
  ``home_relative`` entries, appends ``absolute`` entries, returns JSON.
- Output: JSON array intended for ``fromJson`` at call sites.

.. literalinclude:: ../../../home/.chezmoitemplates/expand-executable-paths.tmpl
   :language: text
   :lineno-match:
   :emphasize-lines: 2,3,5,6,8,9,11
   :caption: expand-executable-paths.tmpl

dotfiles-profile.tmpl
---------------------

- Input: ``VVN_DOTFILES_PROFILE`` environment variable.
- Behavior: normalizes to lowercase, allows ``minimal`` or ``standard``, falls back to ``standard``.
- Output: selected profile name as plain text.

.. literalinclude:: ../../../home/.chezmoitemplates/dotfiles-profile.tmpl
   :language: text
   :lineno-match:
   :emphasize-lines: 2,3,4,6
   :caption: dotfiles-profile.tmpl
