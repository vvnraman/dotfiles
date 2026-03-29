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
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg new-branch feature
      Create a new branch from the current branch and add sibling worktree.

  mg new-branch release/v1
      Create a namespaced branch with matching worktree path.

  mg new-branch --from main hotfix/login
      Create hotfix/login from main, regardless of current branch.

  mg new-branch spike && git -C ../spike status
      Create branch/worktree and inspect repository status there.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  new-branch [--from <branch>] <branch>
      Create a new branch worktree. Defaults base branch to current branch when on a non-bare worktree. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: new-branch [--from <branch>] <branch>

Description:
  Create a new local branch and worktree.
  Default base branch is the current branch when invoked from a non-bare
  repository worktree with attached HEAD.

Arguments:
  <branch>      New branch name to create.

Options:
  --from <branch>  Override the base branch.
  --help           Show this usage text.
  --example        Show example commands.

EOF
}

function _cmd_new_branch() {
  local branch
  local bare_dir
  local worktree_dir
  local base_branch=""
  local current_branch
  local is_bare_repository
  local -a positional_args=()

  if [[ "${1:-}" == "--help" ]]; then
    _usage_new_branch --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_new_branch --example
    return 0
  fi

  while [[ $# -gt 0 ]]; do
    case "${1}" in
    --from)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Missing value for --from."
        _usage_new_branch --full-usage
        return 1
      fi
      base_branch="${1}"
      shift
      ;;
    --)
      shift
      positional_args+=("$@")
      break
      ;;
    --example)
      _usage_new_branch --example
      return 0
      ;;
    --help)
      _usage_new_branch --full-usage
      return 0
      ;;
    -* )
      echo "Unknown option: ${1}"
      _usage_new_branch --full-usage
      return 1
      ;;
    *)
      positional_args+=("${1}")
      shift
      ;;
    esac
  done

  if [[ "${#positional_args[@]}" -ne 1 ]]; then
    _usage_new_branch --full-usage
    return 1
  fi

  branch="${positional_args[0]}"

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

  if lib_is_blank "${base_branch}"; then
    is_bare_repository="$(git rev-parse --is-bare-repository 2>/dev/null || true)"
    if [[ "${is_bare_repository}" != "true" ]]; then
      current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
      if ! lib_is_blank "${current_branch}"; then
        base_branch="${current_branch}"
      fi
    fi
  fi

  if ! lib_is_blank "${base_branch}"; then
    gitlib_require_valid_branch_name "${base_branch}" "base branch" || return 1
    if ! git -C "${bare_dir}" show-ref --verify --quiet "refs/heads/${base_branch}"; then
      echo "Base branch not found: ${base_branch}"
      return 1
    fi

    gitlib_worktree_add_new_local_branch_from_base "${bare_dir}" "${branch}" "${base_branch}" "${worktree_dir}" || return 1
  else
    gitlib_worktree_add_new_local_branch "${bare_dir}" "${branch}" "${worktree_dir}" || return 1
  fi

  cd "${worktree_dir}" || return 1
}
