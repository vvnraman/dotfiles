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

function _usage_switch() {
  if [[ "${1:-}" == "--example" ]]; then
    cat <<'EOF'
Examples:
  mg switch feature-existing
      Jump to existing feature worktree, or create one from origin/upstream.

  mg switch main
      Return to the default branch worktree.

  mg switch fix-login || mg new-branch fix-login
      Switch to an existing branch, or create a new one explicitly.
EOF
    return
  fi

  cat <<'EOF'
  switch <branch>
      Switch to an existing branch worktree, adding local/tracked worktrees when branch exists. Does not create new branches. Supports: --example.

EOF
}

function _cmd_switch() {
  if [[ "${1:-}" == "--example" ]]; then
    _usage_switch --example
    return 0
  fi

  if [[ $# -ne 1 ]]; then
    _usage_switch
    return 1
  fi

  local branch="${1}"
  local bare_dir
  local worktree_dir
  local existing_worktree_dir
  local remote_name

  gitlib_require_valid_branch_name "${branch}" || return 1

  bare_dir="$(gitlib_require_bare_dir)" || return 1
  existing_worktree_dir="$(gitlib_existing_worktree_dir_for_branch "${bare_dir}" "${branch}" 2>/dev/null || true)"

  if ! lib_is_blank "${existing_worktree_dir}"; then
    cd "${existing_worktree_dir}" || return 1
    return
  fi

  worktree_dir="$(gitlib_worktree_dir_for_branch "${bare_dir}" "${branch}")"
  gitlib_require_worktree_path_not_colliding "${worktree_dir}" || return 1

  if git -C "${bare_dir}" show-ref --verify --quiet "refs/heads/${branch}"; then
    gitlib_worktree_add_existing_local_branch "${bare_dir}" "${branch}" "${worktree_dir}" || return 1
    cd "${worktree_dir}" || return 1
    return
  fi

  for remote_name in origin upstream; do
    if ! gitlib_remote_exists "${bare_dir}" "${remote_name}"; then
      continue
    fi

    git -C "${bare_dir}" fetch "${remote_name}" --prune || return 1
    if ! git -C "${bare_dir}" show-ref --verify --quiet "refs/remotes/${remote_name}/${branch}"; then
      continue
    fi

    gitlib_worktree_add_tracked_branch "${bare_dir}" "${branch}" "${remote_name}/${branch}" "${worktree_dir}" || return 1
    cd "${worktree_dir}" || return 1
    return
  done

  echo "Branch not found locally or in origin/upstream: ${branch}"
  echo "Create it with: mg new-branch ${branch}"
  return 1
}
