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

function _usage_remove_worktree() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg remove-worktree feature
      Remove worktree for local branch feature and keep the branch ref.

  mg remove-worktree default-demo
      Remove worktree by directory basename when it differs from branch name.

  mg remove-worktree --force scratch
      Force-remove dirty worktree while keeping scratch branch.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  remove-worktree [--force] <branch-or-worktree>
      Remove a worktree without deleting its branch. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: remove-worktree [--force] <branch-or-worktree>

Description:
  Remove a worktree by local branch name or worktree directory basename.
  The branch reference remains intact.

Arguments:
  <branch-or-worktree>  Local branch name or worktree directory basename.

Options:
  --force       Force removal when worktree has local changes.
  --help        Show this usage text.
  --example     Show example commands.
EOF
}

function _cmd_remove_worktree() {
  local selector
  local branch=""
  local bare_dir
  local worktree_dir=""
  local current_dir
  local force_remove=0

  if [[ "${1:-}" == "--help" ]]; then
    _usage_remove_worktree --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_remove_worktree --example
    return 0
  fi

  if [[ "${1:-}" == "--force" ]]; then
    force_remove=1
    shift
  fi

  if [[ $# -ne 1 ]]; then
    _usage_remove_worktree --full-usage
    return 1
  fi

  selector="${1}"
  bare_dir="$(gitlib_require_bare_dir)" || return 1

  if git check-ref-format --branch "${selector}" 1>/dev/null 2>&1 && git -C "${bare_dir}" show-ref --verify --quiet "refs/heads/${selector}"; then
    branch="${selector}"
    worktree_dir="$(gitlib_existing_worktree_dir_for_branch "${bare_dir}" "${selector}" 2>/dev/null || true)"
  fi

  if lib_is_blank "${worktree_dir}"; then
    worktree_dir="$(gitlib_worktree_dir_for_basename "${bare_dir}" "${selector}" || true)"
  fi

  if lib_is_blank "${worktree_dir}"; then
    echo "Worktree not found for branch or basename: ${selector}"
    return 1
  fi

  if lib_is_blank "${branch}"; then
    branch="$(gitlib_branch_for_worktree_basename "${bare_dir}" "$(basename "${worktree_dir}")" || true)"
    if lib_is_blank "${branch}"; then
      echo "Unable to determine branch for worktree: ${worktree_dir}"
      return 1
    fi
  fi

  if [[ ! -e "${worktree_dir}/.git" ]]; then
    echo "Worktree does not exist on disk: ${worktree_dir}"
    return 1
  fi

  current_dir="$(pwd -P)"
  if lib_has_prefix "${current_dir}/" "${worktree_dir}/"; then
    echo "Cannot remove worktree while current directory is inside it: ${worktree_dir}"
    return 1
  fi

  if [[ "${force_remove}" -eq 1 ]]; then
    git -C "${bare_dir}" worktree remove --force "${worktree_dir}" || return 1
  else
    git -C "${bare_dir}" worktree remove "${worktree_dir}" || return 1
  fi

  printf 'Deleted worktree for branch `%s` at `%s`.\n' "${branch}" "${worktree_dir}"
}
