# shellcheck shell=bash
# vim: set filetype=sh : */

alias gl="git log -1"
alias glm="git log -10 --pretty=oneline"
alias gs="git status"
alias gd="git diff --name-status"
alias gdm="git diff main --name-status"
alias gd1="git diff HEAD^1 --name-status"
alias cs="chezmoi status"
alias ca="chezmoi add"
alias cr="chezmoi re-add"

if command -v lazygit 1>/dev/null 2>&1; then
  alias lg="lazygit"
fi

function _mg_script_path() {
  if [[ -n "${BATS_TEST_MG_SCRIPT_PATH:-}" ]]; then
    printf '%s\n' "${BATS_TEST_MG_SCRIPT_PATH}"
    return
  fi

  if [[ -f "${HOME}/.local/bin/mg" ]]; then
    printf '%s\n' "${HOME}/.local/bin/mg"
    return
  fi

  if type -P mg 1>/dev/null 2>&1; then
    type -P mg
    return
  fi

  echo "mg not found in PATH or ${HOME}/.local/bin"
  return 1
}

function _mg_ensure_loaded() {
  local script_path
  script_path="$(_mg_script_path)" || return 1

  if [[ "${_MG_INCLUDE_GUARD_SCRIPT_PATH:-}" != "${script_path}" ]]; then
    # shellcheck source=/dev/null
    . "${script_path}" || return 1
    _MG_INCLUDE_GUARD_SCRIPT_PATH="${script_path}"
  fi

  if ! declare -F my_git_main 1>/dev/null 2>&1; then
    echo "mg script did not define my_git_main"
    return 1
  fi
}

function mg() {
  _mg_ensure_loaded || return 1
  my_git_main "$@"
}

_mg_bashrc_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_mg_bashrc_dir}/../completions/mg.bash" ]]; then
  # shellcheck source=/dev/null
  . "${_mg_bashrc_dir}/../completions/mg.bash"
fi
