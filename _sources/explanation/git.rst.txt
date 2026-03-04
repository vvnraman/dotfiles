Git configuration
=================

The ``git`` setup consists of 3 parts

1. The OS specifc config contains the base structure.

   This exists primary for windows and linux so that we can look for the presence of tools in
   `$PATH` in the OS native locations trivially.

2. User specific config to specify basic git info

3. Optional tool integrations if they are available

Directory layout
----------------

.. dropdown:: Show layout

   .. literalinclude:: ../generated/git-layout.txt
      :language: sh
      :caption: home/dot_config/git

Load order
----------

1. ``symlink_config.tmpl`` - Chezmoi symlink template which resolves to an os specific config.

   .. literalinclude:: ../../home/dot_config/git/symlink_config.tmpl
      :language: ini
      :lineno-match:
      :emphasize-lines: 2,4
      :caption: symlink_config.tmpl

   Linux and Windows base behavior is defined as follows:

   .. tab-set::

      .. tab-item:: Linux

         .. literalinclude:: ../../home/.chezmoitemplates/linux-config.tmpl
            :language: ini
            :lineno-match:
            :emphasize-lines: 2,4,6,9
            :caption: linux-config.tmpl

      .. tab-item:: Windows

         .. literalinclude:: ../../home/dot_config/git/windows.gitconfig.tmpl
            :language: ini
            :lines: 1-9
            :lineno-match:
            :emphasize-lines: 3,5,8
            :caption: windows.gitconfig.tmpl

2. ``user-vvnraman.gitconfig`` - gets included by the os config 

   The os specific config resolve the user config file using ``user-config.tmpl`` template.

   .. literalinclude:: ../../home/.chezmoitemplates/user-config.tmpl
      :language: ini
      :lineno-match:
      :emphasize-lines: 2
      :caption: user-config.tmpl

3. Tool configs if they're present.

   - ``tool-delta.gitconfig``

   - ``tool-kdiff3.gitconfig``

Relevant changelogs
-------------------

- :doc:`2026-02-feb - add cross platform git config </reference/project/2026-02-feb-add-cross-platform-git-config>`
