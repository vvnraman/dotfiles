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

function _usage_path() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg path feature
      Print the expected worktree path for branch feature.

  mg path main
      Print the default branch worktree path.

  target=$(mg path gift-fixme)
      Capture computed worktree path for scripting.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  path <branch>
      Print worktree path for <branch>. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: path <branch>

Description:
  Print the managed worktree path for <branch> without changing directory.

Arguments:
  <branch>      Branch name to resolve into a worktree path.

Options:
  --help        Show this usage text.
  --example     Show example commands.
EOF
}

function _cmd_path() {
  local branch
  local bare_dir

  if [[ "${1:-}" == "--help" ]]; then
    _usage_path --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_path --example
    return 0
  fi

  if [[ $# -ne 1 ]]; then
    _usage_path --full-usage
    return 1
  fi

  branch="${1}"
  gitlib_require_valid_branch_name "${branch}" || return 1

  bare_dir="$(gitlib_require_bare_dir)" || return 1
  gitlib_worktree_dir_for_branch "${bare_dir}" "${branch}"
}
