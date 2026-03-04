Lazygit configuration
=====================

The ``lazygit`` setup keeps base behavior in one template and keeps theme
variants as separate files.

Directory layout
----------------

.. dropdown:: Show layout

   .. literalinclude:: ../generated/lazygit-layout.txt
      :language: sh
      :caption: home/dot_config/lazygit

Load order
----------

``config.yml.tmpl`` is a template so that we can conditionally load ``delta`` config if its
available.

This would need to be updated to get it work in Windows as well.

Relevant changelogs
-------------------

- :doc:`2026-02-feb - add lazygit theme pagers </reference/project/2026-02-feb-add-lazygit-theme-pagers>`
