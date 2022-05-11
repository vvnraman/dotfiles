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


.. _`chezmoi`: https://github.com/twpayne/chezmoi
