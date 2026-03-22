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

function _usage_show_ignored() {
  if [[ "${1:-}" == "--example" ]]; then
    cat <<'EOF'
Examples:
  mg show-ignored
      List ignored files for the current worktree.

  printf '*.log\n' >> .gitignore && mg show-ignored
      Show files now ignored by updated ignore patterns.

  mg show-ignored | rg '\.cache$'
      Filter ignored entries to inspect a specific file type.
EOF
    return
  fi

  cat <<'EOF'
  show-ignored
      List ignored files. Supports: --example.

EOF
}

function _cmd_show_ignored() {
  if [[ "${1:-}" == "--example" ]]; then
    _usage_show_ignored --example
    return 0
  fi

  if [[ $# -ne 0 ]]; then
    _usage_show_ignored
    return 1
  fi

  git ls-files . --ignored --exclude-standard --others
}
