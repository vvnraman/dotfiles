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

function _usage_update_commit_date() {
  if [[ "${1:-}" == "--example" ]]; then
    cat <<'EOF'
Examples:
  mg update-commit-date
      Amend the most recent commit to use the current timestamp.

  cd myproject.git/feature && mg update-commit-date
      Refresh commit date from within a specific worktree branch.

  before=$(git rev-parse HEAD) && mg update-commit-date && after=$(git rev-parse HEAD)
      Compare commit ids before and after amendment.
EOF
    return
  fi

  cat <<'EOF'
  update-commit-date
      Amend current commit date to now. Supports: --example.

EOF
}

function _cmd_update_commit_date() {
  if [[ "${1:-}" == "--example" ]]; then
    _usage_update_commit_date --example
    return 0
  fi

  if [[ $# -ne 0 ]]; then
    _usage_update_commit_date
    return 1
  fi

  local date_str
  date_str="$(date)"
  GIT_COMMITTER_DATE="${date_str}" \
    git commit --amend --no-edit --date "${date_str}"
}
