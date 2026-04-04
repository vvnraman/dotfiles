function b
  /usr/bin/bash --login -i
end

if command --query nvim
  set --universal --export EDITOR nvim
  set --universal --export VISUAL nvim

  function ovim
    NVIM_APPNAME="neovim-config.git/master" /usr/bin/nvim_0.10.4 $argv
  end

  function mvim
    NVIM_APPNAME="neovim-config.git/master" /usr/bin/nvim $argv
  end

  function kvim
    NVIM_APPNAME="kickstart.nvim" /usr/bin/nvim $argv
  end

  function lvim
    NVIM_APPNAME="lazyvim" /usr/bin/nvim $argv
  end
else
  set --universal --export EDITOR vim
  set --universal --export VISUAL vim
end

if command --query lsd
  abbr --add l lsd
  abbr --add ll lsd --long
  abbr --add la lsd --almost-all --long
  abbr --add lt lsd --almost-all --tree
else
  abbr --add l ls
  abbr --add ll ls --human-readable -l
  abbr --add la ls --almost-all --human-readable -l
  abbr --add lt tree --gitignore
end

# bat - https://github.com/sharkdp/bat
if command --query bat
  set --global --export MANPAGER "sh -c 'col -bx | bat -l man -p'"

  # https://github.com/sharkdp/bat/issues/652
  set --global --export MANROFFOPT "-c"

  abbr --add --position anywhere -- --help '--help | bat -plhelp'
else
  set --universal --export MANPAGER "$EDITOR +Man!"
end

# cmake
fish_add_path --path --append "/opt/cmake/bin"
set --universal --export CMAKE_GENERATOR Ninja
set --universal --export CMAKE_BUILD_PARALLEL_LEVEL (nproc)
set --universal --export CMAKE_EXPORT_COMPILE_COMMANDS 1

# lua
fish_add_path --path --append "$HOME/.luarocks/bin/"

# python/pyenv
set --universal --export PYENV_ROOT "$HOME/.pyenv"
fish_add_path --path --append "$PYENV_ROOT/bin"
mkdir -p "$HOME/.cache/pyenv_cache"
set --universal --export PYTHON_BUILD_CACHE_PATH "$HOME/.cache/pyenv_cache"
if command --query "$PYENV_ROOT/bin/pyenv"
  pyenv init - fish | source
end

# mise
if command --query mise
  mise activate fish | source
end

# golang
fish_add_path --path --append "/usr/local/go/bin"

set --universal --export QT_QPA_PLATFORMTHEME hyprqt6engine
