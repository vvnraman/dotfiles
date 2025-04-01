###################
vvnraman's dotfiles
###################

This repo contains my dotfiles, managed via `chezmoi`_.

.. _`chezmoi`: https://github.com/twpayne/chezmoi

Visit the `overview`_ page for the high level structure.

Visit the `getting-started`_ on a steady state workflow with ``chezmoi``.

.. _`overview`: https://vvnraman.github.io/dotfiles/intro/overview.html
.. _getting-started: http://vvnraman.github.io/dotfiles/intro/getting-started.html

***********************
python project workflow
***********************

This is also a python project for generating docs, publish to github pages,
etc..

- ``uv sync`` to install python dependencies for generating docs.

- ``make docs``

  Runs ``uv run dotfiles docs`` to genrate docs

- ``make live``

  Runs ``uv run dotfiles live`` to for live docs as we're updating them.

- Copy nvim config into dotfiles.

  .. code-block:: console

     $ uv run dotfiles nvim --help
     Usage: dotfiles nvim [OPTIONS]

     Options:
       --dry-run / --no-dry-run     [default: dry-run]
       --nvim-config-dir TEXT       [default: /home/vvnraman/.config/nvim]
       --override-nvim-branch TEXT
       --help                       Show this message and exit.

  Only copies the lua configs, not the docs/python stuff.
