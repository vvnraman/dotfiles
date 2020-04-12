vvnraman's dotfiles
###################

Usage guideline
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

chezmoi docs
************

chezmoi misc
============

- Version

  .. code-block:: sh

     chezmoi --version
     chezmoi version 1.7.19, commit c4dd79633ab5d7263146128847f2b429f0603c55, built at 2020-04-06T21:58:02Z, built by goreleaser

- Upgrade

  .. code-block:: sh

     chezmoi upgrade

- Completion script

  .. code-block:: sh

     chezmoi completion bash > ~/chezmoi-completion.bash
     sudo mv ~/chezmoi-completion.bash /etc/bash_compltion.d/

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

chezmoi templates
=================

Visit
https://github.com/twpayne/chezmoi/blob/master/docs/REFERENCE.md#template-variables
for latest info.

- Use ``chezmoi execute-template`` to see the result for the current machine,
  eg:

  .. code-block:: sh

     chezmoi execute-template '{{ .chezmoi.sourceDir }}'
     chezmoi execute-template '{{ .chezmoi.os }}' / '{{ .chezmoi.arch }}'

- The following is a json snapshot indicating the valid template fields as of
  ``Sun Apr 12 15:07:57 2020 EST``

  .. code-block:: json

     {
       "chezmoi": {
         "arch": "amd64",
         "fullHostname": "USH-LP19-RIX1",
         "group": "vvnraman",
         "homedir": "/home/vvnraman",
         "hostname": "USH-LP19-RIX1",
         "kernel": {
           "osrelease": "4.19.84-microsoft-standard",
           "ostype": "Linux",
           "version": "#1 SMP Wed Nov 13 11:44:37 UTC 2019"
         },
         "os": "linux",
         "osRelease": {
           "bugReportURL": "https://bugs.launchpad.net/ubuntu/",
           "homeURL": "https://www.ubuntu.com/",
           "id": "ubuntu",
           "idLike": "debian",
           "name": "Ubuntu",
           "prettyName": "Ubuntu 18.04.4 LTS",
           "privacyPolicyURL": "https://www.ubuntu.com/legal/terms-and-policies/privacy-policy",
           "supportURL": "https://help.ubuntu.com/",
           "ubuntuCodename": "bionic",
           "version": "18.04.4 LTS (Bionic Beaver)",
           "versionCodename": "bionic",
           "versionID": "18.04"
         },
         "sourceDir": "/home/vvnraman/.local/share/chezmoi",
         "username": "vvnraman"
       }
     }

  - Created via ``chezmoi data``

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
