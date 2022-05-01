****************
Chezmoi concepts
****************

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

.. _`chezmoi`: https://github.com/twpayne/chezmoi
