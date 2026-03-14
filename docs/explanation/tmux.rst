.. _explanation-tmux-configuration:

Tmux configuration
==================

The ``tmux`` setup is structured to keep OS-specific terminal color wiring
explicit and override-friendly.

Directory layout
----------------

.. dropdown:: Show layout

   .. literalinclude:: ../generated/tmux-layout.txt
      :language: sh
      :caption: home/dot-tmux

Load order
----------

This is primarily useful to avoid explicit conditional logic within ``tmux.conf`` (we do have an
``if``), but keep it somewhat declarative and isolated to the OS environment we're in.

By default we use ``terminal-colors-linux.conf``, otherwise we switch as per the setup below:

1. ``symlink_terminal-colors-config.conf.tmpl`` selects the OS/environment target

   .. literalinclude:: ../../home/dot-tmux/symlink_terminal-colors-config.conf.tmpl
      :language: ini
      :lineno-match:
      :emphasize-lines: 4
      :caption: symlink_terminal-colors-config.conf.tmpl

2. ``tmux.conf`` sources the selected config, otherwise uses Linux fallback

   .. literalinclude:: ../../home/dot-tmux/tmux.conf
      :language: text
      :lines: 21-24
      :lineno-match:
      :emphasize-lines: 3
      :caption: tmux.conf

Relevant changelogs
-------------------

- :ref:`2026-02-feb - update tmux shell clipboard <changelog-2026-02-feb-update-tmux-shell-clipboard>`
