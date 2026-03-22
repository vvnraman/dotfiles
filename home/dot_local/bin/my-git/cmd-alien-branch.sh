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

function _usage_alien_branch() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg alien-branch alien gift-fixme
      Fetch alien/gift-fixme and create local alien_gift-fixme worktree.

  git -C myproject.git/bare remote add alien git@github.com:alien/myproject && mg alien-branch alien gift-fixme
      Add alien remote manually, then create prefixed local branch/worktree.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  alien-branch <remote> <branch>
      Fetch existing remote and create tracked worktree branch <remote>_<branch>. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: alien-branch <remote> <branch>

Description:
  Fetch existing <remote> and create tracked worktree branch <remote>_<branch>
  from <remote>/<branch>.

Arguments:
  <remote>      Existing remote name.
  <branch>      Remote branch name to track.

Options:
  --help        Show this usage text.
  --example     Show example commands.

EOF
}

function _cmd_alien_branch() {
  local remote_spec
  local remote_name
  local worktree_dir

  if [[ "${1:-}" == "--help" ]]; then
    _usage_alien_branch --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_alien_branch --example
    return 0
  fi

  if [[ $# -ne 2 ]]; then
    _usage_alien_branch --full-usage
    return 1
  fi

  remote_spec="${1}"
  local branch="${2}"
  local bare_dir

  if lib_is_blank "${remote_spec}"; then
    echo "<remote> name is not valid."
    return 1
  fi

  gitlib_require_valid_branch_name "${branch}" || return 1

  bare_dir="$(gitlib_require_bare_dir)" || return 1

  if lib_is_absolute_path "${remote_spec}"; then
    echo "<remote> must be a remote name, not an absolute path."
    return 1
  fi

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

  gitlib_worktree_add_remote_branch "${bare_dir}" "${remote_name}" "${branch}" "${remote_name}_${branch}" worktree_dir || return 1

  cd "${worktree_dir}" || return 1
}
