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

function _usage_remove_branch() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg remove-branch feature
      Remove merged feature branch worktree and local branch ref.

  mg remove-branch --force feature
      Remove worktree and local branch even when feature is not merged.

  mg remove-branch gift-fixme
      Remove merged alien branch after integration.

  mg remove-branch default-demo
      Remove by worktree basename when it maps to a local branch.

  mg switch main && mg remove-branch feature
      Leave target worktree, then safely remove merged branch.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  remove-branch [--force] <branch-or-worktree>
      Remove merged branch worktree and local branch. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: remove-branch [--force] <branch-or-worktree>

Description:
  Remove worktree and local branch for <branch>, but only when <branch>
  is fully merged into the repository default local branch.

Arguments:
  <branch-or-worktree>  Branch name or worktree basename to remove.

Options:
  --force       Allow removing unmerged branch/worktree.
  --help        Show this usage text.
  --example     Show example commands.
EOF
}

function _cmd_remove_branch() {
  local selector
  local branch
  local bare_dir
  local worktree_dir
  local default_branch
  local current_dir
  local force_remove=0

  if [[ "${1:-}" == "--help" ]]; then
    _usage_remove_branch --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_remove_branch --example
    return 0
  fi

  if [[ "${1:-}" == "--force" ]]; then
    force_remove=1
    shift
  fi

  if [[ $# -ne 1 ]]; then
    _usage_remove_branch --full-usage
    return 1
  fi

  selector="${1}"

  bare_dir="$(gitlib_require_bare_dir)" || return 1

  if git check-ref-format --branch "${selector}" 1>/dev/null 2>&1 && git -C "${bare_dir}" show-ref --verify --quiet "refs/heads/${selector}"; then
    branch="${selector}"
  else
    branch="$(gitlib_branch_for_worktree_basename "${bare_dir}" "${selector}" || true)"
    if lib_is_blank "${branch}"; then
      echo "Branch not found: ${selector}"
      return 1
    fi
  fi

  gitlib_require_valid_branch_name "${branch}" || return 1

  default_branch="$(gitlib_default_local_branch_from_bare "${bare_dir}" 2>/dev/null || true)"
  if lib_is_blank "${default_branch}"; then
    echo "Unable to determine default branch for merge safety check."
    return 1
  fi

  if [[ "${branch}" == "${default_branch}" ]]; then
    echo "Refusing to remove default branch: ${branch}"
    return 1
  fi

  if [[ "${force_remove}" -ne 1 ]] && ! git -C "${bare_dir}" merge-base --is-ancestor "refs/heads/${branch}" "refs/heads/${default_branch}" 1>/dev/null 2>&1; then
    echo "Branch '${branch}' is not fully merged into '${default_branch}'."
    echo "Merge it first, then retry remove-branch."
    return 1
  fi

  worktree_dir="$(gitlib_worktree_dir_for_branch "${bare_dir}" "${branch}")"
  gitlib_require_worktree_path_not_colliding "${worktree_dir}" || return 1

  if [[ -e "${worktree_dir}/.git" ]]; then
    current_dir="$(pwd -P)"
    if lib_has_prefix "${current_dir}/" "${worktree_dir}/"; then
      echo "Cannot remove branch while current directory is inside its worktree: ${worktree_dir}"
      return 1
    fi

    if [[ "${force_remove}" -eq 1 ]]; then
      git -C "${bare_dir}" worktree remove --force "${worktree_dir}" || return 1
    else
      git -C "${bare_dir}" worktree remove "${worktree_dir}" || return 1
    fi
  fi

  if [[ "${force_remove}" -eq 1 ]]; then
    git -C "${bare_dir}" branch -D "${branch}"
  else
    git -C "${bare_dir}" branch -d "${branch}"
  fi
}
