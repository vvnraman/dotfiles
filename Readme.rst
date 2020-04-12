vvnraman's dotfiles
###################

Usage guideline
***************

Basic overview
==============

- Use ``git`` to version files and directories present in ``$HOME`` folder,
  henceforth called ``dotfiles``.

- Use `chezmoi`_ to manage all the workflows involved.

  - Use ``chezmoi``'s templates to handle machine specific configuration.

- Current chezmoi source state as of ``Sun Apr 12 13:41:19 2020 EST``

  .. code-block:: sh

     ├── Readme.rst
     ├── dot-bash
     ├── dot-tmux
     ├── dot-vim
     ├── symlink_dot_bash_profile
     ├── symlink_dot_bashrc
     ├── symlink_dot_profile
     ├── symlink_dot_tmux.conf
     └── symlink_dot_vimrc

  - Get time in vim via ``:put =strftime('%c')``

  - Get directory tree via ``tree -L 1``

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

First time setup
================

- Install chezmoi

  .. code-block:: sh

     curl -sfL https://git.io/chezmoi | sh

  - Installs the correct binary for the current operating system & architecture
    and puts it with ``$HOME/bin``.

  - ``$HOME/bin`` is expected to already be in ``$PATH``.

  Visit https://github.com/twpayne/chezmoi/releases for pre-built packages.

- Let chezmoi take over

  .. code-block:: sh

     chezmoi init git@github:vvnraman/dotfiles.git
     # or
     chezmoi init /home/vvnraman/WinOneDrive/vvn/git/vvnraman/dotfiles.git/

  followed by

  .. code-block:: sh

     chezmoi diff     # optional to see the subsequent changes
     chezmoi apply

Concepts
********

chezmoi terminology
===================

``chezmoi``'s concepts -
https://github.com/twpayne/chezmoi/blob/master/docs/REFERENCE.md#concepts

- **source state** - declares the desired state of ``$HOME``, including
  templates and machine-specific configuration.

- **source directory** is where ``chezmoi`` stores the **source state**, by
  default ``$HOME/.local/share/chezmoi``

  Can be queried via ``chezmoi source-path``

- **target state** is the **source state** computed for the current machine.

- **destination directory** is the directory that ``chezmoi`` manages, by
  default ``$HOME``.

- **destination state** is the state of all the **targets** in the
  **destination directory**.

  where **targets** = file, directory or symlink in **destination directory**

- machine-specific configuration is present in a config file at
  ``$HOME/.config/chezmoi/chezmoi.toml``

Pre-requisites
**************

Operating Systems
=================

- Ubuntu, standalone or in WSL

- Windows - Git bash or msys2

Command line tools
==================

- bash

- git

- curl

.. _`chezmoi`: https://github.com/twpayne/chezmoi
