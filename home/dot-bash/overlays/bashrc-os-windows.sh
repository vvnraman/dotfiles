# Git Bash / MSYS2 specific config.

# shellcheck disable=SC1091
source "$HOME/dot-bash/bashrc-lib.sh" # common functions

PRE_PATH="/C/Windows/System32/OpenSSH"
PRE_PATH+=":/C/Program Files/Git/bin"
PRE_PATH+=":/C/Program Files/Neovim/bin"
PRE_PATH+=":/C/Users/vvnra/AppData/Local/Microsoft/WinGet/Links"
export PATH="${PRE_PATH}:${PATH}"
export PATH="${PATH}:/C/Program Files/WezTerm"
export PATH="${PATH}:/C/Program Files/Neovide"
export PATH="${PATH}:/C/Program Files/ImageMagick-7.1.2-Q16-HDRI"
