# Arch Linux config

# shellcheck disable=SC1091
source "$HOME/dot-bash/bashrc-lib.sh" # common functions

# shellcheck disable=SC1090
[[ -f "${HOME}/dot-bash/overlays/bashrc-os-linux.sh" ]] && source "${HOME}/dot-bash/overlays/bashrc-os-linux.sh"

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
