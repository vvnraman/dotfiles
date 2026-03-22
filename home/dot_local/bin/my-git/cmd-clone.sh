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

function _parse_clone_options() {
  local -n out_host="${1}"
  local -n out_host_was_set="${2}"
  local -n out_dest_path="${3}"
  local -n out_positional_args="${4}"

  shift 4

  local parsed_host
  local parsed_host_was_set=0
  local parsed_dest_path=""
  local -a parsed_positional_args=()

  parsed_host="$(gitlib_default_git_host)"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
    --host)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Missing value for --host."
        return 1
      fi
      parsed_host="${1}"
      parsed_host_was_set=1
      shift
      ;;
    --dest)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Missing value for --dest."
        return 1
      fi
      parsed_dest_path="${1}"
      shift
      ;;
    --)
      shift
      parsed_positional_args+=("$@")
      break
      ;;
    -* )
      echo "Unknown option: ${1}"
      return 1
      ;;
    *)
      parsed_positional_args+=("${1}")
      shift
      ;;
    esac
  done

  out_host="${parsed_host}"
  out_host_was_set="${parsed_host_was_set}"
  out_dest_path="${parsed_dest_path}"
  out_positional_args=("${parsed_positional_args[@]}")
}

function _parse_clone_repo_url_components() {
  local raw_url="${1}"
  local host
  local path
  local org
  local repo

  raw_url="$(lib_strip_suffix "${raw_url}" "/")"
  raw_url="$(lib_strip_suffix "${raw_url}" ".git")"

  if lib_has_substring "${raw_url}" "://"; then
    local no_scheme
    no_scheme="$(lib_after_first "${raw_url}" "://")"
    host="$(lib_before_first "${no_scheme}" "/")"
    path="$(lib_after_first "${no_scheme}" "/")"
  elif lib_has_substring "${raw_url}" ":"; then
    host="$(lib_before_first "${raw_url}" ":")"
    path="$(lib_after_first "${raw_url}" ":")"
  else
    return 1
  fi

  path="$(lib_strip_prefix "${path}" "/")"
  if ! lib_has_path_separator "${path}"; then
    return 1
  fi

  org="$(lib_before_first "${path}" "/")"
  repo="$(lib_after_last "${path}" "/")"

  if lib_is_blank "${host}" || lib_is_blank "${org}" || lib_is_blank "${repo}"; then
    return 1
  fi

  printf '%s|%s|%s\n' "${host}" "${org}" "${repo}"
}

function _clone_project_dir_from_dest() {
  local dest_path="${1}"

  dest_path="$(lib_strip_suffix "${dest_path}" "/")"
  if lib_is_blank "${dest_path}"; then
    return 1
  fi

  if lib_has_suffix "${dest_path}" ".git"; then
    printf '%s\n' "${dest_path}"
    return
  fi

  printf '%s.git\n' "${dest_path}"
}

function _normalize_bare_origin_fetch() {
  local bare_dir="${1}"

  git -C "${bare_dir}" config --unset-all remote.origin.fetch
  git -C "${bare_dir}" config --add remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git -C "${bare_dir}" fetch origin --prune
}

function _usage_clone() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg clone vvnraman myproject
      Clone using org/repo form and create myproject.git layout.

  mg clone git@github.com:vvnraman/myproject
      Clone using a single SSH URL argument.

  mg clone /tmp/test-dir/alpha-remote.git --dest /tmp/test-dir/alpha-copy
      Clone from local bare path into /tmp/test-dir/alpha-copy.git layout.

  mg clone --dest alpha-copy alpha-remote.git
      Clone from a relative local bare path into alpha-copy.git layout.

  mg clone --host github vvnraman myproject
      Clone with an explicit host override.

  VVN_DOTFILES_GITHUB_HOST=github mg clone vvnraman myproject
      Clone using host from environment default.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  clone [--host <host-alias>] [--dest <project-dir>] <org> <repo>
  clone [--dest <project-dir>] <url-or-local-path>
      Clone into <repo>.git/bare, normalize origin fetch, and create default branch worktree. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: clone [--host <host-alias>] [--dest <project-dir>] <org> <repo>
   or: clone [--dest <project-dir>] <url-or-local-path>

Description:
  Clone into <repo>.git/bare, normalize origin fetch refs, and create a
  default-branch worktree.

Arguments:
  <org> <repo>  Organization and repository name.
  <url-or-local-path>  Repository URL in ssh/https/scp-style format, or local path.

Options:
  --host <host-alias> Override host alias when using <org> <repo> form.
                     Not supported with single-argument <url-or-local-path> form.
  --dest <project-dir> Override destination project path.
                     Appends .git unless <project-dir> already ends with .git.
  --help        Show this usage text.
  --example     Show example commands.

Defaults:
  Host defaults to VVN_DOTFILES_GITHUB_HOST; fallback is github.
EOF
}

function _cmd_clone() {
  local host
  local org
  local repo
  local source_arg
  local clone_source
  local dest_path
  local project_dir
  local bare_dir
  local default_branch
  local parsed_clone
  local parsed_host
  local host_was_set
  local -a positional_args=()

  if [[ "${1:-}" == "--help" ]]; then
    _usage_clone --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_clone --example
    return 0
  fi

  gitlib_require_outside_parent_layout "clone" || return 1

  _parse_clone_options host host_was_set dest_path positional_args "$@" || {
    _usage_clone --full-usage
    return 1
  }

  set -- "${positional_args[@]}"

  if [[ $# -eq 1 ]]; then
    source_arg="$(lib_strip_suffix "${1}" "/")"

    if [[ -e "${source_arg}" ]]; then
      clone_source="${source_arg}"
      repo="$(basename "${source_arg}")"
      repo="$(lib_strip_suffix "${repo}" ".git")"
    else
      if [[ "${host_was_set}" -eq 1 ]]; then
        echo "Cannot use --host with <url-or-local-path> clone form."
        _usage_clone --full-usage
        return 1
      fi

      parsed_clone="$(_parse_clone_repo_url_components "${source_arg}")" || {
        _usage_clone --full-usage
        return 1
      }
      IFS='|' read -r parsed_host org repo <<<"${parsed_clone}"
      if ! lib_is_blank "${parsed_host}"; then
        host="${parsed_host}"
      fi
      clone_source="${host}:${org}/${repo}"
    fi
  elif [[ $# -eq 2 ]]; then
    org="${1}"
    repo="${2}"
    clone_source="${host}:${org}/${repo}"
  else
    _usage_clone --full-usage
    return 1
  fi

  if lib_is_blank "${repo}" || lib_is_blank "${clone_source}"; then
    echo "Repository source is not valid."
    return 1
  fi

  if lib_is_blank "${dest_path}"; then
    project_dir="${repo}.git"
  else
    project_dir="$(_clone_project_dir_from_dest "${dest_path}")" || {
      echo "<project-dir> value for --dest is not valid."
      return 1
    }
  fi
  bare_dir="${project_dir}/bare"

  gitlib_require_project_dir_available "clone" "${project_dir}" || return 1

  mkdir "${project_dir}" &&
    git clone --bare "${clone_source}" "${bare_dir}" &&
    _normalize_bare_origin_fetch "${bare_dir}" &&
    default_branch="$(gitlib_default_branch_from_bare "${bare_dir}")" &&
    if lib_is_blank "${default_branch}"; then
      echo "Unable to determine default branch."
      return 1
    fi &&
    git -C "${bare_dir}" worktree add "../${default_branch}" "${default_branch}"
}
