.. _getting-started:

***************
Getting Started
***************

Basic overview
==============

- Use ``git`` to version files and directories present in ``$HOME`` folder,
  henceforth called ``dotfiles``.

- Use `chezmoi`_ to manage all the workflows involved.

  Use `chezmoi's templates <#chezmoi-templates>`_ to handle machine specific
  configuration.

Update workflow
===============

See the `chezmoi's terms <#chezmoi-terminology>`_ section for explanations of
any terms below.

- Use ``cd $(chezmoi source-path)`` to navigate to the **source directory**.

  This is currently ``$HOME/.local/share/chezmoi``.

- Use ``chezmoi edit $HOME/<target>`` to edit the corresponding ``<target>`` as
  present in the **source directory**.

- Use a git branch for significant changes to **source state**

  - ``git branch -b updates``

  - ``chezmoi diff`` to see what will change

  - ``chezmoi apply`` to update **destination state** in ``$HOME``

  - ``git checkout master`` to reset everything back in case of disaster.

- Use ``-n|--dry-run`` and ``-v|--verbose`` after ``chezmoi`` in the above
  commands if scared.

- For any of the symlinks, ``chezmoi dump ~/<target>`` to see what ``chezmoi``
  is modelling it as. eg:

  .. code-block:: sh

     $ chezmoi dump ~/.bash_profile
     [
       {
         "type": "symlink",
         "sourcePath": "/home/vvnraman/.local/share/chezmoi/symlink_dot_bash_profile",
         "targetPath": ".bash_profile",
         "template": false,
         "linkname": "dot-bash/bash_profile"
       }
     ]


  Avoid using this for non-symlinks, as the output is either json or yaml and
  not human readable.

.. _`chezmoi`: https://github.com/twpayne/chezmoi
