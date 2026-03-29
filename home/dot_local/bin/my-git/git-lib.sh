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

function gitlib_repo_layout_kind() {
  local git_common_dir="${1}"
  local common_name
  local parent_dir
  local parent_name
  local is_bare

  if [[ ! -d "${git_common_dir}" ]]; then
    return 1
  fi

  is_bare="$(git -C "${git_common_dir}" rev-parse --is-bare-repository 2>/dev/null || true)"
  if [[ "${is_bare}" != "true" ]]; then
    printf '%s\n' "default"
    return 0
  fi

  common_name="$(basename "${git_common_dir}")"
  parent_dir="$(dirname "${git_common_dir}")"
  parent_name="$(basename "${parent_dir}")"

  if [[ "${common_name}" == "bare" ]] && lib_has_suffix "${parent_name}" ".git"; then
    printf '%s\n' "parent-bare-siblings"
    return 0
  fi

  if lib_has_suffix "${common_name}" ".git"; then
    printf '%s\n' "bare-siblings.git"
    return 0
  fi

  printf '%s\n' "bare-siblings"
}

function gitlib_computed_worktree_dir_for_branch() {
  local git_common_dir="${1}"
  local branch="${2}"
  local layout_kind
  local project_dir
  local project_parent_dir
  local project_name
  local default_branch
  local default_worktree_dir
  local worktree_parent_dir

  layout_kind="$(gitlib_repo_layout_kind "${git_common_dir}")" || return 1

  case "${layout_kind}" in
  default)
    project_dir="$(dirname "${git_common_dir}")"
    default_branch="$(gitlib_default_local_branch_from_bare "${git_common_dir}" 2>/dev/null || true)"
    if ! lib_is_blank "${default_branch}" && [[ "${branch}" == "${default_branch}" ]]; then
      printf '%s\n' "${project_dir}"
      return 0
    fi

    project_parent_dir="$(dirname "${project_dir}")"
    project_name="$(basename "${project_dir}")"
    printf '%s/%s-worktrees/%s\n' "${project_parent_dir}" "${project_name}" "${branch}"
    ;;
  parent-bare-siblings | bare-siblings.git | bare-siblings)
    default_branch="$(gitlib_default_local_branch_from_bare "${git_common_dir}" 2>/dev/null || true)"
    if ! lib_is_blank "${default_branch}"; then
      default_worktree_dir="$(gitlib_existing_worktree_dir_for_branch "${git_common_dir}" "${default_branch}" 2>/dev/null || true)"
      if ! lib_is_blank "${default_worktree_dir}"; then
        worktree_parent_dir="$(dirname "${default_worktree_dir}")"
        printf '%s/%s\n' "${worktree_parent_dir}" "${branch}"
        return 0
      fi
    fi

    case "${layout_kind}" in
    parent-bare-siblings | bare-siblings.git)
      printf '%s/%s\n' "$(dirname "${git_common_dir}")" "${branch}"
      ;;
    bare-siblings)
      printf '%s/%s\n' "${git_common_dir}" "${branch}"
      ;;
    esac
    ;;
  *)
    return 1
    ;;
  esac
}

function gitlib_worktree_parent_dir() {
  local git_common_dir="${1}"
  local layout_kind
  local default_branch
  local default_worktree_dir
  local project_dir

  layout_kind="$(gitlib_repo_layout_kind "${git_common_dir}")" || return 1

  case "${layout_kind}" in
  default)
    project_dir="$(dirname "${git_common_dir}")"
    printf '%s\n' "$(dirname "${project_dir}")"
    return 0
    ;;
  parent-bare-siblings | bare-siblings.git | bare-siblings)
    default_branch="$(gitlib_default_local_branch_from_bare "${git_common_dir}" 2>/dev/null || true)"
    if ! lib_is_blank "${default_branch}"; then
      default_worktree_dir="$(gitlib_existing_worktree_dir_for_branch "${git_common_dir}" "${default_branch}" 2>/dev/null || true)"
      if ! lib_is_blank "${default_worktree_dir}"; then
        printf '%s\n' "$(dirname "${default_worktree_dir}")"
        return 0
      fi
    fi

    case "${layout_kind}" in
    parent-bare-siblings | bare-siblings.git)
      printf '%s\n' "$(dirname "${git_common_dir}")"
      ;;
    bare-siblings)
      printf '%s\n' "${git_common_dir}"
      ;;
    esac
    ;;
  *)
    return 1
    ;;
  esac
}

function gitlib_worktree_dir_for_branch() {
  local bare_dir="${1}"
  local branch="${2}"
  local existing_worktree_dir

  existing_worktree_dir="$(gitlib_existing_worktree_dir_for_branch "${bare_dir}" "${branch}" 2>/dev/null || true)"
  if ! lib_is_blank "${existing_worktree_dir}"; then
    printf '%s\n' "${existing_worktree_dir}"
    return 0
  fi

  gitlib_computed_worktree_dir_for_branch "${bare_dir}" "${branch}"
}

function gitlib_worktree_add_existing_local_branch() {
  local bare_dir="${1}"
  local branch="${2}"
  local worktree_dir="${3}"

  mkdir -p "$(dirname "${worktree_dir}")" || return 1
  git -C "${bare_dir}" worktree add "${worktree_dir}" "${branch}"
}

function gitlib_worktree_add_new_local_branch() {
  local bare_dir="${1}"
  local branch="${2}"
  local worktree_dir="${3}"

  mkdir -p "$(dirname "${worktree_dir}")" || return 1
  git -C "${bare_dir}" worktree add -b "${branch}" "${worktree_dir}"
}

function gitlib_worktree_add_new_local_branch_from_base() {
  local bare_dir="${1}"
  local branch="${2}"
  local base_branch="${3}"
  local worktree_dir="${4}"

  mkdir -p "$(dirname "${worktree_dir}")" || return 1
  git -C "${bare_dir}" worktree add -b "${branch}" "${worktree_dir}" "${base_branch}"
}

function gitlib_worktree_add_tracked_branch() {
  local bare_dir="${1}"
  local local_branch="${2}"
  local remote_ref="${3}"
  local worktree_dir="${4}"

  mkdir -p "$(dirname "${worktree_dir}")" || return 1
  git -C "${bare_dir}" worktree add --track -b "${local_branch}" "${worktree_dir}" "${remote_ref}"
}

function gitlib_existing_worktree_dir_for_branch() {
  local bare_dir="${1}"
  local branch="${2}"
  local target_ref="refs/heads/${branch}"
  local current_worktree=""
  local line

  while IFS= read -r line; do
    if lib_has_prefix "${line}" "worktree "; then
      current_worktree="${line#worktree }"
      continue
    fi

    if [[ "${line}" == "branch ${target_ref}" ]]; then
      if ! lib_is_blank "${current_worktree}"; then
        printf '%s\n' "${current_worktree}"
        return 0
      fi
    fi

    if lib_is_blank "${line}"; then
      current_worktree=""
    fi
  done < <(git -C "${bare_dir}" worktree list --porcelain)

  return 1
}

function gitlib_worktree_dir_for_basename() {
  local bare_dir="${1}"
  local worktree_basename="${2}"
  local current_worktree=""
  local current_is_bare=0
  local line
  local match_count=0
  local matched_worktree=""

  while IFS= read -r line; do
    if lib_has_prefix "${line}" "worktree "; then
      current_worktree="${line#worktree }"
      current_is_bare=0
      continue
    fi

    if [[ "${line}" == "bare" ]]; then
      current_is_bare=1
      continue
    fi

    if lib_is_blank "${line}"; then
      if [[ -n "${current_worktree}" ]] && [[ "${current_is_bare}" -ne 1 ]] && [[ "$(basename "${current_worktree}")" == "${worktree_basename}" ]]; then
        match_count=$((match_count + 1))
        matched_worktree="${current_worktree}"
      fi
      current_worktree=""
      current_is_bare=0
    fi
  done < <(git -C "${bare_dir}" worktree list --porcelain)

  if [[ -n "${current_worktree}" ]] && [[ "${current_is_bare}" -ne 1 ]] && [[ "$(basename "${current_worktree}")" == "${worktree_basename}" ]]; then
    match_count=$((match_count + 1))
    matched_worktree="${current_worktree}"
  fi

  if [[ "${match_count}" -eq 1 ]]; then
    printf '%s\n' "${matched_worktree}"
    return 0
  fi

  if [[ "${match_count}" -gt 1 ]]; then
    echo "Worktree basename is ambiguous: ${worktree_basename}" 1>&2
    return 1
  fi

  return 1
}

function gitlib_branch_for_worktree_basename() {
  local bare_dir="${1}"
  local worktree_basename="${2}"
  local current_worktree=""
  local current_branch=""
  local current_is_bare=0
  local line
  local match_count=0
  local matched_branch=""
  local matched_worktree=""

  while IFS= read -r line; do
    if lib_has_prefix "${line}" "worktree "; then
      current_worktree="${line#worktree }"
      current_branch=""
      current_is_bare=0
      continue
    fi

    if [[ "${line}" == "bare" ]]; then
      current_is_bare=1
      continue
    fi

    if lib_has_prefix "${line}" "branch refs/heads/"; then
      current_branch="${line#branch refs/heads/}"
      continue
    fi

    if lib_is_blank "${line}"; then
      if [[ -n "${current_worktree}" ]] && [[ "${current_is_bare}" -ne 1 ]] && [[ "$(basename "${current_worktree}")" == "${worktree_basename}" ]]; then
        if lib_is_blank "${current_branch}"; then
          echo "Worktree has no local branch: ${current_worktree}" 1>&2
          return 1
        fi

        match_count=$((match_count + 1))
        matched_branch="${current_branch}"
        matched_worktree="${current_worktree}"
      fi
      current_worktree=""
      current_branch=""
      current_is_bare=0
    fi
  done < <(git -C "${bare_dir}" worktree list --porcelain)

  if [[ -n "${current_worktree}" ]] && [[ "${current_is_bare}" -ne 1 ]] && [[ "$(basename "${current_worktree}")" == "${worktree_basename}" ]]; then
    if lib_is_blank "${current_branch}"; then
      echo "Worktree has no local branch: ${current_worktree}" 1>&2
      return 1
    fi

    match_count=$((match_count + 1))
    matched_branch="${current_branch}"
    matched_worktree="${current_worktree}"
  fi

  if [[ "${match_count}" -eq 1 ]]; then
    printf '%s\n' "${matched_branch}"
    return 0
  fi

  if [[ "${match_count}" -gt 1 ]]; then
    echo "Worktree basename is ambiguous: ${worktree_basename}" 1>&2
    echo "Use the full branch name instead of: ${worktree_basename}" 1>&2
    echo "One matching worktree is: ${matched_worktree}" 1>&2
    return 1
  fi

  return 1
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
    gitlib_worktree_add_existing_local_branch "${bare_dir}" "${local_branch}" "${resolved_worktree_dir}"
    return
  fi

  gitlib_worktree_add_tracked_branch "${bare_dir}" "${local_branch}" "${remote}/${remote_branch}" "${resolved_worktree_dir}"
}

MG_INCLUDE_GUARD_GIT_LIB_LOADED=1
