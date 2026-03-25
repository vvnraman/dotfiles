.. _explanation-git-configuration:

Git configuration
=================

The git setup loads an OS base config, then a user config, then optional tool configs when the
tools are discoverable on that machine.

Directory layout
----------------

.. dropdown:: Show layout

   .. literalinclude:: ../generated/git-layout.txt
      :language: sh
      :caption: home/dot_config/git

Load order
----------

1. ``symlink_config.tmpl`` selects the OS-specific base file.

   .. literalinclude:: ../../home/dot_config/git/symlink_config.tmpl
      :language: text
      :lineno-match:
      :emphasize-lines: 1,2,3,4
      :caption: symlink_config.tmpl

2. The OS base file includes user config with a safe fallback to ``no-op.gitconfig``.

   .. tab-set::

      .. tab-item:: Linux

         .. literalinclude:: ../../home/dot_config/git/linux.gitconfig.tmpl
            :language: text
            :lines: 1-10
            :lineno-match:
            :emphasize-lines: 3,5,6,8
            :caption: linux.gitconfig.tmpl

      .. tab-item:: Windows

         .. literalinclude:: ../../home/dot_config/git/windows.gitconfig.tmpl
            :language: text
            :lines: 1-10
            :lineno-match:
            :emphasize-lines: 3,5,6,8
            :caption: windows.gitconfig.tmpl

3. The OS base file resolves executable search paths and conditionally includes tool snippets.
   Path data and expansion behavior are documented in :ref:`explanation-chezmoi-data` and
   :ref:`explanation-chezmoi-template-helpers`.

   .. tab-set::

      .. tab-item:: Linux

         .. literalinclude:: ../../home/dot_config/git/linux.gitconfig.tmpl
            :language: text
            :lines: 11-16
            :lineno-match:
            :emphasize-lines: 1,3
            :caption: linux.gitconfig.tmpl

      .. tab-item:: Windows

         .. literalinclude:: ../../home/dot_config/git/windows.gitconfig.tmpl
            :language: text
            :lines: 11-16
            :lineno-match:
            :emphasize-lines: 1,3
            :caption: windows.gitconfig.tmpl

See also:

- :ref:`explanation-chezmoi-data`
- :ref:`explanation-chezmoi-template-helpers`
- :ref:`explanation-chezmoi-machine-specific-config`

Relevant changelogs
-------------------

- :ref:`2026-02-feb - add cross platform git config <changelog-2026-02-feb-add-cross-platform-git-config>`
