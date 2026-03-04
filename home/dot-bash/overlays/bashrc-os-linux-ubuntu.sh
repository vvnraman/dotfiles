# Ubuntu config

# shellcheck disable=SC1091
source "$HOME/dot-bash/bashrc-lib.sh" # common functions
source_script "${HOME}/dot-bash/overlays/bashrc-os-linux.sh"

# Load WSL2 config conditionally
if is_wsl2; then
  source_script "${HOME}/dot-bash/overlays/bashrc-wsl2.sh"
fi
