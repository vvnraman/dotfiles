# vim: set filetype=sh : */

if [[ -z "${_MG_BIN_DIR:-}" ]]; then
  _MG_BIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if [[ -z "${_MG_HOME_DIR:-}" ]]; then
  _MG_HOME_DIR="$(dirname "${_MG_BIN_DIR}")"
fi

# shellcheck source=/dev/null
. "${_MG_HOME_DIR}/lib/bash-lib.sh"
# shellcheck source=/dev/null
. "${_MG_BIN_DIR}/my-git/git-lib.sh"

function _usage_show_untracked() {
  if [[ "${1:-}" == "--example" ]]; then
    cat <<'EOF'
Examples:
  mg show-untracked
      List untracked files for the current worktree.

  touch notes.txt && mg show-untracked
      Confirm newly created files are currently untracked.

  mg show-untracked | rg '^docs/'
      Filter untracked output to a specific directory.
EOF
    return
  fi

  cat <<'EOF'
  show-untracked
      List untracked files. Supports: --example.

EOF
}

function _cmd_show_untracked() {
  if [[ "${1:-}" == "--example" ]]; then
    _usage_show_untracked --example
    return 0
  fi

  if [[ $# -ne 0 ]]; then
    _usage_show_untracked
    return 1
  fi

  git ls-files . --exclude-standard --others
}
