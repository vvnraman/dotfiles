# Generic Linux config.

# shellcheck disable=SC1091
source "$HOME/dot-bash/bashrc-lib.sh" # common functions

function f {
  /usr/bin/fish --login
}

function ovim {
  NVIM_APPNAME="neovim-config.git/master" /usr/bin/nvim_old "$@"
}

function mvim {
  NVIM_APPNAME="neovim-config.git/master" /usr/bin/nvim "$@"
}

function kvim {
  NVIM_APPNAME="kickstart.nvim" /usr/bin/nvim "$@"
}

# bat - https://github.com/sharkdp/bat
if command -v bat 1>/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"

  # https://github.com/sharkdp/bat/issues/652
  export MANROFFOPT="-c"
else
  export MANPAGER="$EDITOR +Man!"
fi

# cmake
append_to_path "/opt/cmake/"

# lua
append_to_path "${HOME}/.luarocks/bin/"

# python
export PYENV_ROOT="${HOME}/.pyenv"
PATH="${PATH}:${PYENV_ROOT}/bin"
mkdir -p "${HOME}/.cache/pyenv_cache"
export PYTHON_BUILD_CACHE_PATH="${HOME}/.cache/pyenv_cache"

if command -v "${PYENV_ROOT/bin/pyenv}" 1>/dev/null 2>&1; then
  eval "$(pyenv init - bash)"
fi

# golang
append_to_path "/usr/local/go/bin"
