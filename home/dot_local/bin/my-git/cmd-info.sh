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

function _print_remote_branch_tracking() {
  local bare_dir="${1}"
  local -a remote_refs=()
  local -a tracked_lines=()
  local -a untracked_lines=()
  local remote_ref
  local remote_name
  local remote_branch
  local candidate_local
  local prefixed_candidate_local
  local local_branch
  local tracking_locals=""
  local line

  mapfile -t remote_refs < <(git -C "${bare_dir}" for-each-ref --format='%(refname:short)' refs/remotes)

  for remote_ref in "${remote_refs[@]}"; do
    if [[ "${remote_ref}" == */HEAD ]]; then
      continue
    fi

    if ! lib_has_path_separator "${remote_ref}"; then
      continue
    fi

    remote_name="${remote_ref%%/*}"
    remote_branch="${remote_ref#*/}"
    if [[ "${remote_name}" != "origin" && "${remote_name}" != "upstream" ]]; then
      continue
    fi

    tracking_locals=""

    candidate_local="${remote_branch}"
    prefixed_candidate_local="${remote_name}_${remote_branch}"

    if git -C "${bare_dir}" show-ref --verify --quiet "refs/heads/${candidate_local}"; then
      local_branch="${candidate_local}"
      tracking_locals="${local_branch}"
    fi

    if [[ "${prefixed_candidate_local}" != "${candidate_local}" ]] && git -C "${bare_dir}" show-ref --verify --quiet "refs/heads/${prefixed_candidate_local}"; then
      local_branch="${prefixed_candidate_local}"
      if lib_is_blank "${tracking_locals}"; then
        tracking_locals="${local_branch}"
      else
        tracking_locals="${tracking_locals},${local_branch}"
      fi
    fi

    if lib_is_blank "${tracking_locals}"; then
      untracked_lines+=("  ${remote_ref} -> (none)")
      continue
    fi

    tracked_lines+=("  ${remote_ref} -> ${tracking_locals}")
  done

  if [[ ${#tracked_lines[@]} -eq 0 && ${#untracked_lines[@]} -eq 0 ]]; then
    printf '  (none)\n'
    return
  fi

  for line in "${tracked_lines[@]}"; do
    printf '%s\n' "${line}"
  done

  for line in "${untracked_lines[@]}"; do
    printf '%s\n' "${line}"
  done
}

function _print_repo_inventory() {
  local bare_dir="${1}"
  local project_dir
  local default_branch
  local -a remotes=()
  local remote
  local remote_url
  local have_worktrees=0

  project_dir="$(dirname "${bare_dir}")"
  default_branch="$(gitlib_default_local_branch_from_bare "${bare_dir}" 2>/dev/null || true)"

  printf 'Parent: %s\n' "${project_dir}"
  printf 'Bare: %s\n' "${bare_dir}"
  if lib_is_blank "${default_branch}"; then
    printf 'Default branch: (unknown)\n'
  else
    printf 'Default branch: %s\n' "${default_branch}"
  fi

  printf 'Remotes:\n'
  mapfile -t remotes < <(git -C "${bare_dir}" remote)
  if [[ ${#remotes[@]} -eq 0 ]]; then
    printf '  (none)\n'
  else
    for remote in "${remotes[@]}"; do
      remote_url="$(git -C "${bare_dir}" remote get-url "${remote}" 2>/dev/null || true)"
      if lib_is_blank "${remote_url}"; then
        printf '  %s\n' "${remote}"
      else
        printf '  %s %s\n' "${remote}" "${remote_url}"
      fi
    done
  fi

  printf 'Worktrees:\n'
  while IFS= read -r line; do
    if lib_is_blank "${line}"; then
      continue
    fi
    printf '  %s\n' "${line}"
    have_worktrees=1
  done < <(git -C "${bare_dir}" worktree list)

  if [[ "${have_worktrees}" -eq 0 ]]; then
    printf '  (none)\n'
  fi

  printf 'Remote branches for origin or upstream:\n'
  _print_remote_branch_tracking "${bare_dir}"
}

function _usage_info() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg info
      Show parent layout, default branch, remotes, and worktrees.

  cd myproject.git/feature && mg info
      Inspect repository inventory from any worktree directory.

  mg info | rg '^(Default branch|  origin)'
      Filter key inventory lines for quick checks.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  info
      Show layout, remotes, remote branches, tracking locals, and worktrees. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: info

Description:
  Show repository inventory for the current managed layout, including
  parent directory, bare path, default branch, remotes, remote branches,
  local tracking branches, and worktrees.

Options:
  --help        Show this usage text.
  --example     Show example commands.
EOF
}

function _cmd_info() {
  local bare_dir

  if [[ "${1:-}" == "--help" ]]; then
    _usage_info --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_info --example
    return 0
  fi

  if [[ $# -ne 0 ]]; then
    _usage_info --full-usage
    return 1
  fi

  bare_dir="$(gitlib_require_bare_dir)" || return 1
  _print_repo_inventory "${bare_dir}"
}
