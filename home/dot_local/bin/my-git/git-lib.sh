# vim: set filetype=sh : */

if [[ -n "${MG_INCLUDE_GUARD_GIT_LIB_LOADED:-}" ]]; then
  return 0
fi

if [[ -z "${_MG_BIN_DIR:-}" ]]; then
  _MG_BIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if [[ -z "${_MG_HOME_DIR:-}" ]]; then
  _MG_HOME_DIR="$(dirname "${_MG_BIN_DIR}")"
fi

# shellcheck source=/dev/null
. "${_MG_HOME_DIR}/lib/bash-lib.sh"

function gitlib_default_git_host() {
  if ! lib_is_blank "${VVN_DOTFILES_GITHUB_HOST}"; then
    printf '%s\n' "${VVN_DOTFILES_GITHUB_HOST}"
    return
  fi

  printf '%s\n' "github"
}

function gitlib_remote_exists() {
  local bare_dir="${1}"
  local remote="${2}"

  git -C "${bare_dir}" remote get-url "${remote}" 1>/dev/null 2>&1
}

function gitlib_is_parent_layout_dir() {
  local dir_path="${1}"
  local base_name

  if [[ ! -d "${dir_path}" ]]; then
    return 1
  fi

  base_name="$(basename "${dir_path}")"
  lib_has_suffix "${base_name}" ".git" && [[ -d "${dir_path}/bare" ]]
}

function gitlib_find_parent_layout_dir() {
  local current_dir

  current_dir="$(pwd -P)"

  while [[ "${current_dir}" != "/" ]]; do
    if gitlib_is_parent_layout_dir "${current_dir}"; then
      printf '%s\n' "${current_dir}"
      return 0
    fi

    current_dir="$(dirname "${current_dir}")"
  done

  return 1
}

function gitlib_require_outside_parent_layout() {
  local command_name="${1}"
  local parent_layout_dir

  parent_layout_dir="$(gitlib_find_parent_layout_dir)" || return 0

  echo "Cannot run ${command_name} inside managed parent directory: ${parent_layout_dir}"
  return 1
}

function gitlib_require_project_dir_available() {
  local command_name="${1}"
  local project_dir="${2}"

  if [[ ! -e "${project_dir}" ]]; then
    return 0
  fi

  if gitlib_is_parent_layout_dir "${project_dir}"; then
    echo "${command_name} target already exists: ${project_dir}"
    return 1
  fi

  echo "${command_name} target path exists and is not a managed parent layout: ${project_dir}"
  return 1
}

function gitlib_require_valid_branch_name() {
  local branch_name="${1}"
  local label="${2:-branch}"

  if lib_is_blank "${branch_name}"; then
    echo "<${label}> name is not valid."
    return 1
  fi

  if ! git check-ref-format --branch "${branch_name}" 1>/dev/null 2>&1; then
    echo "Invalid ${label} name: ${branch_name}"
    return 1
  fi
}

function gitlib_require_worktree_path_not_colliding() {
  local worktree_dir="${1}"

  if [[ -e "${worktree_dir}" && ! -e "${worktree_dir}/.git" ]]; then
    echo "Worktree path exists and is not a git worktree: ${worktree_dir}"
    return 1
  fi
}

function gitlib_require_remote_configured() {
  local bare_dir="${1}"
  local remote="${2}"

  if gitlib_remote_exists "${bare_dir}" "${remote}"; then
    return 0
  fi

  echo "Remote '${remote}' is not configured."
  echo "Add it with: git -C \"${bare_dir}\" remote add ${remote} <remote-url>"
  echo "Or use: mg self-branch ${remote} <branch>"
  return 1
}

function gitlib_require_bare_dir() {
  local bare_dir

  bare_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  if [[ -z "${bare_dir}" ]]; then
    echo "Not inside a git repository."
    return 1
  fi

  printf '%s\n' "${bare_dir}"
}

function gitlib_worktree_dir_for_branch() {
  local bare_dir="${1}"
  local branch="${2}"
  local project_dir

  project_dir="$(dirname "${bare_dir}")"
  printf '%s/%s\n' "${project_dir}" "${branch}"
}

function gitlib_default_branch_from_bare() {
  local bare_dir="${1}"
  local default_branch

  default_branch="$(git -C "${bare_dir}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
  default_branch="$(lib_strip_prefix "${default_branch}" "origin/")"

  if lib_is_blank "${default_branch}"; then
    default_branch="$(git -C "${bare_dir}" branch --format='%(refname:short)' --list main master | head -n 1)"
  fi

  if lib_is_blank "${default_branch}"; then
    return 1
  fi

  printf '%s\n' "${default_branch}"
}

function gitlib_default_local_branch_from_bare() {
  local bare_dir="${1}"
  local default_branch

  default_branch="$(git -C "${bare_dir}" symbolic-ref --short HEAD 2>/dev/null)"

  if lib_is_blank "${default_branch}"; then
    default_branch="$(gitlib_default_branch_from_bare "${bare_dir}" 2>/dev/null || true)"
  fi

  if lib_is_blank "${default_branch}"; then
    default_branch="$(git -C "${bare_dir}" branch --format='%(refname:short)' --list main master | head -n 1)"
  fi

  if lib_is_blank "${default_branch}"; then
    return 1
  fi

  printf '%s\n' "${default_branch}"
}

function gitlib_worktree_add_remote_branch() {
  local bare_dir="${1}"
  local remote="${2}"
  local remote_branch="${3}"
  local local_branch="${4}"
  local -n out_worktree_dir="${5}"
  local resolved_worktree_dir

  out_worktree_dir=""

  gitlib_require_valid_branch_name "${remote_branch}" "remote-branch" || return 1
  gitlib_require_valid_branch_name "${local_branch}" "local-branch" || return 1
  gitlib_require_remote_configured "${bare_dir}" "${remote}" || return 1

  git -C "${bare_dir}" fetch "${remote}" --prune || return 1

  if ! git -C "${bare_dir}" show-ref --verify --quiet "refs/remotes/${remote}/${remote_branch}"; then
    echo "Remote branch not found: ${remote}/${remote_branch}"
    echo "Inspect remote branches with: git -C \"${bare_dir}\" branch -r"
    return 1
  fi

  resolved_worktree_dir="$(gitlib_worktree_dir_for_branch "${bare_dir}" "${local_branch}")"
  out_worktree_dir="${resolved_worktree_dir}"
  gitlib_require_worktree_path_not_colliding "${resolved_worktree_dir}" || return 1

  if [[ -e "${resolved_worktree_dir}/.git" ]]; then
    echo "Worktree already exists: ${resolved_worktree_dir}"
    return 0
  fi

  if git -C "${bare_dir}" show-ref --verify --quiet "refs/heads/${local_branch}"; then
    git -C "${bare_dir}" worktree add "../${local_branch}" "${local_branch}"
    return
  fi

  git -C "${bare_dir}" worktree add --track -b "${local_branch}" \
    "../${local_branch}" \
    "${remote}/${remote_branch}"
}

MG_INCLUDE_GUARD_GIT_LIB_LOADED=1
