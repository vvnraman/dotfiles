************************************
Setup ``chezmoi`` for the first time
************************************

Install chezmoi
===============

.. code-block:: sh

   curl -sfL https://git.io/chezmoi | sh

- Installs the correct binary for the current operating system & architecture
  and puts it with ``$HOME/bin``.

- ``$HOME/bin`` is expected to already be in ``$PATH``.

Visit https://github.com/twpayne/chezmoi/releases for pre-built packages.

Fetch dotfiles
==============

.. code-block:: sh

   chezmoi init git@github:vvnraman/dotfiles.git
   # or
   chezmoi init /home/vvnraman/WinOneDrive/vvn/git/vvnraman/dotfiles.git/

followed by

Let chezmoi take over
=====================

.. code-block:: sh

   chezmoi diff     # optional to see the subsequent changes
   chezmoi apply
