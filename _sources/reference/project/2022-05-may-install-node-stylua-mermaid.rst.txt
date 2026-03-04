2022-05-01 - install node stylua mermaid
========================================

2022-05-01 - Sunday
-------------------

Install node stylua mermaid.

- I had setup ``fnm`` already from https://github.com/Schniz/fnm. This is a
  node version manager written in Rust.

  .. code-block:: sh

     readlink -f $(which fnm)
     # /home/vvnraman/cli-tools/downloads/fnm/fnm-v1.31.0/fnm

  Installed the latest node using it.

  .. code-block:: console

     $ fnm install --lts
     # Installed Node v16.15.0

  Node is needed for a few language servers installed using
  ``nvim-lsp-installer``.

- Installed mermaid cli for mermaid diagrams in sphinx docs (not directly
  related to ``neovim``).

  .. code-block:: sh

     npm install -g mermaid.cli

- Installed ``stylua`` for formatting the Lua codebase (neovim config).

  .. code-block:: sh

     curl --fail --location --remote-name https://github.com/JohnnyMorganz/StyLua/releases/download/v0.13.1/stylua-linux.zip
     unzip stylua-linux.zip
     chmod +x stylua
     ln -s $(readlink -f stylua) ~/bin/stylua
