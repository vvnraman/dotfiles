set --global fish_greeting
set --global fish_key_bindings fish_vi_key_bindings

# The order in which paths are being added is important as they're being
# prepended to the path. I would like the `~/bin` to come first.

# mise
if command -q mise
  mise activate fish | source
end

# golang
fish_add_path --path --prepend "/usr/local/go/bin"

# python/pyenv
set --universal --export PYENV_ROOT "$HOME/.pyenv"
fish_add_path --path --prepend "$PYENV_ROOT/bin"
pyenv init - fish | source

# cmake
fish_add_path --path --prepend "/opt/cmake/bin"

# custom binaries in `bin`
# Add other entries to path above.
fish_add_path --path --prepend "$HOME/bin"

if command -q nvim
  set --universal --export EDITOR nvim
  set --universal --export VISUAL nvim

  function ovim
    # Use the master branch of my config with the older version
    NVIM_APPNAME="neovim-config.git/master" /usr/bin/nvim_0.10.4 $argv
  end

  function mvim
    # Use the master branch of my config with the current version
    NVIM_APPNAME="neovim-config.git/master" /usr/bin/nvim $argv
  end

  function kvim
    # Use the minimal `kickstart.nvim` distro with the latest stable version
    NVIM_APPNAME="kickstart.nvim" /usr/bin/nvim_0.11.5 $argv
  end
end

if command -q fzf
  fzf --fish | source
end

function l --wraps=ls --description 'List contents of directory using long format'
  if command -q lsd
    lsd -al $argv
  else
    ls -lh $argv
  end
end

# bat - https://github.com/sharkdp/bat
if command -q bat
  # Use `bat` as the man pager for colorized man pages, if available.
  set --global --export MANPAGER "sh -c 'col -bx | bat -l man -p'"

  # https://github.com/sharkdp/bat/issues/652
  set --global --export MANROFFOPT "-c"

  # highlight `--help` messages
  abbr --add --position anywhere -- --help '--help | bat -plhelp'

  # `-h` may not always be for help.
  # abbr --add --position anywhere -- -h '-h | bat -plhelp'
end

abbr --add gl git log -1
abbr --add glm git log -10 --pretty=oneline
abbr --add gs git status
abbr --add gd git diff --name-status
abbr --add gdm git diff main --name-status
abbr --add gd1 git diff HEAD^1 --name-status
abbr --add cs chezmoi status
abbr --add ca chezmoi add

if command -q lazygit
  alias lg="lazygit"
end

# This is intentionally unconditional.
set --universal --export STARSHIP_CONFIG ~/.config/starship/starship.toml
if status is-interactive
    # Commands to run in interactive sessions can go here

    # starship
    if command -q starship
      starship init fish | source
    end
end

