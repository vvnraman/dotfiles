.. _changelog-2022-05-may-configure-vim-install-tools:

2022-05 may - configure vim install tools
=========================================

2022-05-10 - Tuesday
--------------------

Configure vim install tools.

- Made vim to be provided by neovim.

  .. code-block:: sh

     sudo update-alternatives --install /usr/bin/vim vim /home/vvnraman/bin/nvim 100

  Also set ``$EDITOR`` to ``vim`` in ``.bashrc-custom`` so that :program:`git`
  uses it. :program:`vi` is still provided by ``vim.gtk``.

- Installed :program:`gitui`.

  .. code-block:: sh

     mkdir ~/cli-tools/downloads/gitui && cd ~/cli-tools/downloads/gitui
     mkdir v0.20.1 && cd v0.20.1
     curl --fail --location --remote-name \
        https://github.com/extrawurst/gitui/releases/download/v0.20.1/gitui-linux-musl.tar.gz
     tar --extract --file gitui-linux-musl.tar.gz
     ln -s $(readlink -f ./gitui) ~/bin/

- Installed :program:`nnn`.

  .. code-block:: sh

     mkdir ~/cli-tools/downloads/nnn/v4.5/
     cd ~/cli-tools/downloads/nnn/v4.5/
     curl --fail --location --remote-name \
        https://github.com/jarun/nnn/releases/download/v4.5/nnn-nerd-static-4.5.x86_64.tar.gz
     tar --extract --file nnn-nerd-static-4.5.x86_64.tar.gz
     ln -s $(readlink -f ./nnn-nerd-static) ~/bin/n
