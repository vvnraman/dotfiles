# Ubuntu config

# shellcheck disable=SC1091
source "$HOME/dot-bash/bashrc-lib.sh" # common functions

# shellcheck disable=SC1090
[[ -f "${HOME}/dot-bash/overlays/bashrc-os-linux.sh" ]] && source "${HOME}/dot-bash/overlays/bashrc-os-linux.sh"

# Load WSL2 config conditionally
if is_wsl2; then
  # shellcheck disable=SC1090
  [[ -f "${HOME}/dot-bash/overlays/bashrc-wsl2.sh" ]] && source "${HOME}/dot-bash/overlays/bashrc-wsl2.sh"
fi
