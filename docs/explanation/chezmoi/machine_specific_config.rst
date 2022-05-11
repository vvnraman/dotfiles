Machine Specific ``dotfiles`` Config
====================================

Machine specific dotfiles config is configured via :ref:`chezmoi-templates`. This
currently only applies to bashrc files.

We have a ``dot-bash/symlink_bashrc-custom-machine.tmpl`` template file in our
source directory. This file will exist in the desitnation directory as
a regular symlink named ``dot-bash/bashrc-custom-machine``.

This symlink is sourced in our ``dot-bash/profile`` as follows

.. code-block:: sh
   :caption: dot-bash/profile

   source_script "$HOME/dot-bash/bashrc-custom-machine"

The content of this template file determines where it points to. Currently it
contains the following template

.. code-block:: sh

   bashrc-custom-{{ .chezmoi.hostname }}_{{ .chezmoi.osRelease.id }}_{{ .chezmoi.osRelease.versionID }}

The symlink in the destination directory points to the resolved file name based
on the values of those template variables. On my personal laptop, inside WSL2
Ubuntu 20.04, this resolves to the following name::

  bashrc-custom-USH-LP19-RIX1_ubuntu_20.04

This means that we have the following link available on my personal laptop

.. code-block:: console

   $ ls -l dot-bash/bashrc-custom-machine
   lrwxrwxrwx 1 vvnraman vvnraman 40 May 10 22:04 dot-bash/bashrc-custom-machine -> bashrc-custom-USH-LP19-RIX1_ubuntu_20.04

This allows us to have custom configuration in this file without affecting how
the dotfiles affects the other machines where they get cloned.
