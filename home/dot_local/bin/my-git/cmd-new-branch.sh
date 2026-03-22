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

function _usage_new_branch() {
  if [[ "${1:-}" == "--example" ]]; then
    cat <<'EOF'
Examples:
  mg new-branch feature
      Create a new local branch and sibling worktree.

  mg new-branch release/v1
      Create a namespaced branch with matching worktree path.

  mg new-branch spike && git -C ../spike status
      Create branch/worktree and inspect repository status there.
EOF
    return
  fi

  cat <<'EOF'
  new-branch <branch>
      Create a new branch worktree. Supports: --example.

EOF
}

function _cmd_new_branch() {
  if [[ "${1:-}" == "--example" ]]; then
    _usage_new_branch --example
    return 0
  fi

  if [[ $# -ne 1 ]]; then
    _usage_new_branch
    return 1
  fi

  local branch="${1}"
  local bare_dir
  local worktree_dir

  gitlib_require_valid_branch_name "${branch}" || return 1

  bare_dir="$(gitlib_require_bare_dir)" || return 1
  worktree_dir="$(gitlib_worktree_dir_for_branch "${bare_dir}" "${branch}")"

  gitlib_require_worktree_path_not_colliding "${worktree_dir}" || return 1

  if [[ -e "${worktree_dir}/.git" ]]; then
    echo "Worktree already exists: ${worktree_dir}"
    return 1
  fi

  if git -C "${bare_dir}" show-ref --verify --quiet "refs/heads/${branch}"; then
    echo "Branch already exists: ${branch}"
    return 1
  fi

  git -C "${bare_dir}" worktree add -b "${branch}" "../${branch}" || return 1
  cd "${worktree_dir}" || return 1
}
