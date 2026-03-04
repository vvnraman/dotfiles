2022-05-09 - refactor neovim lua config
=======================================

2022-05-09 - Monday
-------------------

Refactor neovim lua config.

Refactored standalone neovim configuration in Lua to be more modular.

Next step was to subsume it in the dotfiles repo managed by
:program:`chezmoi`. I planned to keep the standalone repo alive as well.

Installed a few more command line tools for ``null-ls``.

.. code-block:: sh

   pipx install black
   pipx install isort
   pipx install flake8

There were a couple of command line tools left to be installed.
