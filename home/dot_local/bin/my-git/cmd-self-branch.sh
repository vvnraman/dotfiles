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

function _usage_self_branch() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg self-branch origin feature
      Use existing origin remote and create feature worktree.

  mg self-branch upstream gift-fixme
      Use existing upstream remote and create gift-fixme worktree.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  self-branch <remote> <branch>
      Use existing remote, then fetch and create tracked worktree branch <branch>. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: self-branch <remote> <branch>

Description:
  Use existing <remote>, then fetch and create tracked worktree branch
  <branch> from <remote>/<branch>.

Arguments:
  <remote>      Remote name/org (for example, upstream).
  <branch>      Remote branch name to track.

Options:
  --help              Show this usage text.
  --example           Show example commands.
EOF
}

function _cmd_self_branch() {
  local remote_spec
  local remote_name
  local branch
  local bare_dir
  local worktree_dir

  if [[ "${1:-}" == "--help" ]]; then
    _usage_self_branch --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_self_branch --example
    return 0
  fi

  if [[ $# -ne 2 ]]; then
    _usage_self_branch --full-usage
    return 1
  fi

  remote_spec="${1}"
  branch="${2}"

  if lib_is_blank "${remote_spec}"; then
    echo "<remote> name is not valid."
    return 1
  fi

  gitlib_require_valid_branch_name "${branch}" || return 1

  bare_dir="$(gitlib_require_bare_dir)" || return 1
  remote_name="${remote_spec}"

  if lib_is_blank "${remote_name}"; then
    echo "Unable to resolve remote target from: ${remote_spec}"
    return 1
  fi

  if ! gitlib_remote_exists "${bare_dir}" "${remote_name}"; then
    echo "Remote '${remote_name}' is not configured."
    echo "Add it with: git -C \"${bare_dir}\" remote add ${remote_name} <remote-url>"
    return 1
  fi

  gitlib_worktree_add_remote_branch "${bare_dir}" "${remote_name}" "${branch}" "${branch}" worktree_dir || return 1

  cd "${worktree_dir}" || return 1
}
