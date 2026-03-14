.. _changelog-2022-04-apr-setup-neovim-dotfiles:

2022-04 apr - setup neovim dotfiles
===================================

2022-04-16 - Saturday
---------------------

Setup neovim dotfiles.

Setting up neovim with my dotfiles.

- For true colour support:

  - Removed the following from my ``.bashrc``:

    .. code-block:: sh

       export TERM="xterm-256color"

    This is not required as Windows Terminal already supports true colour by
    emulating the ``xterm-256color`` sequences.

  - Added the following in ``.tmux.conf``:

    .. code-block:: sh

       set-option -sa terminal-overrides ',xterm-256color:RGB'

    There was already the following line in there:

    .. code-block:: sh

       set-option -g default-terminal "screen-256color"

    This tells tmux that the terminal outside it supports true colour. This is
    important as this sets the right term variable for programs running within
    ``tmux``, notably our ``neovim`` instance.

  - Told ``neovim`` that true colour support is available:

    .. code-block:: sh

       vim.opt.termguicolors = true

  - Killed the tmux server and restarted for the changes to take effect.
