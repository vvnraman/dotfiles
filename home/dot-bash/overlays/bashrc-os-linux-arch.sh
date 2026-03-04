# Arch Linux config

# shellcheck disable=SC1091
source "$HOME/dot-bash/bashrc-lib.sh" # common functions
source_script "${HOME}/dot-bash/overlays/bashrc-os-linux.sh"

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
