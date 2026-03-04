Fish configuration
==================

``fish`` is our interative shell set in ``tmux`` and the terminals.

- Apart from ``config.fish``, we have separate files for setting various pices of config such that
  the separate scripts "look" similar in structure to our ``bash`` counterparts.

- Machine-specific customization is overlayed via os and user sepcific files.

- Exactly which os and which user file gets included is determined via ``chezmoi`` generated
  symlinks.

Directory layout
----------------

.. dropdown:: Show layout

   .. literalinclude:: ../generated/fish-layout.txt
      :language: sh
      :caption: home/dot_config/fish

Load order
----------

Implicit Fish startup behavior

1. First ``fish`` auto-loads ``conf.d/*.fish`` scripts

2. Then it loads ``config.fish`` as the main startup file.

3. ``config.fish`` explicitly loads os and user specific config files.

   .. literalinclude:: ../../home/dot_config/fish/config.fish
      :language: fish
      :lines: 10-17
      :lineno-match:
      :emphasize-lines: 6,7
      :caption: config.fish

4. Linux distro agnostic config is present in ``dot_config/fish/linux-config.fish``, which is loaded
   by distro specific configs

   .. tab-set::

      .. tab-item:: Arch

         .. literalinclude:: ../../home/dot_config/fish/linux-arch-config.fish
            :language: ini
            :lineno-match:
            :emphasize-lines: 2
            :caption: linux-arch-config.fish

      .. tab-item:: Ubuntu

         .. literalinclude:: ../../home/dot_config/fish/linux-ubuntu-config.fish
            :language: ini
            :lineno-match:
            :emphasize-lines: 2
            :caption: linux-ubuntu-config.fish

Relevant changelogs
-------------------

- :doc:`2026-02-feb - restructure fish config modules </reference/project/2026-02-feb-restructure-fish-config-modules>`
