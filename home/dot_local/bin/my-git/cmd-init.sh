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

function _default_init_branch() {
  local default_branch

  default_branch="$(git config --get init.defaultBranch)"
  if lib_is_blank "${default_branch}"; then
    default_branch="master"
  fi

  printf '%s\n' "${default_branch}"
}

function _usage_init() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg init myproject
      Create myproject.git with bare repo and default-branch worktree.

  mkdir sandbox && cd sandbox && mg init myproject
      Create myproject.git inside a dedicated parent folder.

  mg init myproject && cd myproject.git && ls
      Initialize the layout, then inspect bare/ and branch worktree directories.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  init <project>
      Create a bare+worktree repository layout for <project>. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: init <project>

Description:
  Create <project>.git/bare, add default-branch worktree, and create an
  initial empty commit.

Arguments:
  <project>  Project name used for <project>.git parent layout.

Options:
  --help     Show this usage text.
  --example  Show example commands.

EOF
}

function _cmd_init() {
  if [[ "${1:-}" == "--help" ]]; then
    _usage_init --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_init --example
    return 0
  fi

  gitlib_require_outside_parent_layout "init" || return 1

  if [[ $# -ne 1 ]]; then
    _usage_init --full-usage
    return 1
  fi

  local project="${1}"
  local project_dir="${project}.git"
  local bare_dir="${project_dir}/bare"
  local default_branch
  local worktree_dir

  if lib_is_blank "${project}"; then
    echo "<project> name is not valid."
    return 1
  fi

  gitlib_require_project_dir_available "init" "${project_dir}" || return 1

  default_branch="$(_default_init_branch)"
  worktree_dir="${project_dir}/${default_branch}"

  mkdir "${project_dir}" &&
    git init --bare "${bare_dir}" &&
    git -C "${bare_dir}" worktree add -b "${default_branch}" "../${default_branch}" &&
    git -C "${worktree_dir}" commit --allow-empty --message "Initial commit."
}
