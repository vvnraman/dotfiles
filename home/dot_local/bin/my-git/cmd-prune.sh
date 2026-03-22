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

function _usage_prune() {
  case "${1:-}" in
  --example)
    cat <<'EOF'
Examples:
  mg prune
      Prune remote-tracking refs and stale worktree metadata.

  mg prune && mg info
      Clean stale state, then inspect current repository inventory.

  mg prune && git -C ../bare branch -r
      Refresh and then inspect remaining remote-tracking branches.
EOF
    return
    ;;
  --full-usage)
    ;;
  *)
    cat <<'EOF'
  prune
      Prune remotes and stale worktree metadata. Supports: --help, --example.

EOF
    return
    ;;
  esac

  cat <<'EOF'
Usage: prune

Description:
  For each configured remote, fetch with --prune, then prune stale
  worktree administrative metadata.

Options:
  --help        Show this usage text.
  --example     Show example commands.
EOF
}

function _cmd_prune() {
  local bare_dir
  local -a remotes=()
  local remote

  if [[ "${1:-}" == "--help" ]]; then
    _usage_prune --full-usage
    return 0
  fi

  if [[ "${1:-}" == "--example" ]]; then
    _usage_prune --example
    return 0
  fi

  if [[ $# -ne 0 ]]; then
    _usage_prune --full-usage
    return 1
  fi

  bare_dir="$(gitlib_require_bare_dir)" || return 1

  mapfile -t remotes < <(git -C "${bare_dir}" remote)
  for remote in "${remotes[@]}"; do
    git -C "${bare_dir}" fetch "${remote}" --prune || return 1
  done

  git -C "${bare_dir}" worktree prune
}
