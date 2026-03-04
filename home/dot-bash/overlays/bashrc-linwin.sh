# vim: set ft=sh : */

# Keep this file agnostic to Linux/Windows.

# shellcheck disable=SC1091
source "$HOME/dot-bash/bashrc-lib.sh" # common functions

# make
if command -v nproc 1>/dev/null 2>&1; then
  export MAKEFLAGS=-j"$(($(nproc) + 1))"
fi

# neovim/editor
if command -v nvim 1>/dev/null 2>&1; then
  export VISUAL="nvim"
  export EDITOR="nvim"
else
  export VISUAL="vim"
  export EDITOR="vim"
fi

if command -v lsd 1>/dev/null 2>&1; then
  alias l=lsd
  alias ll="lsd --long"
  alias la="lsd --almost-all --long"
  alias lt="lsd --almost-all --tree"
else
  alias l=ls
  alias ll="ls --human-readable -l"
  alias la="ls --almost-all --human-readable -l"
  alias lt="tree --gitignore"
fi

# cmake
export CMAKE_GENERATOR=Ninja
export CMAKE_BUILD_PARALLEL_LEVEL=8
export CMAKE_EXPORT_COMPILE_COMMANDS=1

# toolchains
append_to_path "${HOME}/go/bin"
append_to_path "${HOME}/.cargo/bin"
append_to_path "${HOME}/.npm-packages/bin"

export PATH
