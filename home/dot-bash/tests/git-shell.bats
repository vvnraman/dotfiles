#!/usr/bin/env bats

setup_file() {
  export SHELL_UNDER_TEST="${SHELL_UNDER_TEST:-bash}"
  if [[ "${SHELL_UNDER_TEST}" != "bash" && "${SHELL_UNDER_TEST}" != "fish" ]]; then
    echo "SHELL_UNDER_TEST must be one of: bash, fish"
    return 1
  fi

  local repo_root
  repo_root="${BATS_TEST_DIRNAME}/../../.."
  export BATS_TEST_MG_SCRIPT_PATH="${repo_root}/home/dot_local/bin/executable_mg"

  if [[ "${SHELL_UNDER_TEST}" == "bash" ]]; then
    export BASH_CONFIG_PATH="${repo_root}/home/dot-bash/bashrc.d/bashrc-git.sh"
  else
    export FISH_CONFIG_PATH="${repo_root}/home/dot_config/fish/conf.d/git-config.fish"
    export FISH_MG_PATH="${repo_root}/home/dot_config/fish/functions/mg.fish"
  fi
}

setup() {
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"

  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
  unset VVN_DOTFILES_GITHUB_HOST

  git config --global user.name "Bats User"
  git config --global user.email "bats@example.com"
  git config --global init.defaultBranch main

  mkdir -p "${TEST_TMPDIR}/work"
  mkdir -p "${TEST_TMPDIR}/remotes"

  _seed_remote "testorg" "demo"
  _seed_remote "upstream" "demo"
  _seed_remote "collab" "demo"
  _seed_remote "localdisk" "myproject.git"

  git config --global url."file://${TEST_TMPDIR}/remotes/testorg/".insteadOf "github:testorg/"
  git config --global url."file://${TEST_TMPDIR}/remotes/upstream/".insteadOf "github:upstream/"
  git config --global url."file://${TEST_TMPDIR}/remotes/collab/".insteadOf "github:collab/"
  git config --global --add url."file://${TEST_TMPDIR}/remotes/testorg/".insteadOf "git@github.com:testorg/"
  git config --global --add url."file://${TEST_TMPDIR}/remotes/upstream/".insteadOf "git@github.com:upstream/"
  git config --global --add url."file://${TEST_TMPDIR}/remotes/collab/".insteadOf "git@github.com:collab/"
  git config --global --add url."file://${TEST_TMPDIR}/remotes/testorg/".insteadOf "codehub:testorg/"
  git config --global --add url."file://${TEST_TMPDIR}/remotes/upstream/".insteadOf "codehub:upstream/"
  git config --global --add url."file://${TEST_TMPDIR}/remotes/collab/".insteadOf "codehub:collab/"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

_seed_remote() {
  local org="${1}"
  local repo="${2}"
  local remote_root="${TEST_TMPDIR}/remotes/${org}"
  local remote_repo="${remote_root}/${repo}"
  local seed_dir="${TEST_TMPDIR}/seed-${org}-${repo}"

  mkdir -p "${remote_root}"
  git init --bare "${remote_repo}"
  git clone "${remote_repo}" "${seed_dir}"

  printf 'seed\n' >"${seed_dir}/README.md"
  git -C "${seed_dir}" add README.md
  git -C "${seed_dir}" commit --message "seed main"
  git -C "${seed_dir}" push origin main

  git -C "${seed_dir}" checkout -b feature-existing
  printf 'feature\n' >"${seed_dir}/feature.txt"
  git -C "${seed_dir}" add feature.txt
  git -C "${seed_dir}" commit --message "seed feature"
  git -C "${seed_dir}" push origin feature-existing

  git -C "${seed_dir}" checkout main
  rm -rf "${seed_dir}"
}

_run_shell() {
  local command_str="${1}"

  if [[ "${SHELL_UNDER_TEST}" == "bash" ]]; then
    run bash --noprofile --norc -c "source '${BASH_CONFIG_PATH}'; ${command_str}"
    return
  fi

  run fish --no-config --command "source '${FISH_CONFIG_PATH}'; source '${FISH_MG_PATH}'; ${command_str}"
}

_run_shell_with_host_env() {
  local host="${1}"
  local command_str="${2}"

  if [[ "${SHELL_UNDER_TEST}" == "bash" ]]; then
    run bash --noprofile --norc -c "source '${BASH_CONFIG_PATH}'; export VVN_DOTFILES_GITHUB_HOST='${host}'; ${command_str}"
    return
  fi

  run fish --no-config --command "source '${FISH_CONFIG_PATH}'; source '${FISH_MG_PATH}'; set --global --export VVN_DOTFILES_GITHUB_HOST '${host}'; ${command_str}"
}

_run_shell_with_verbose_env() {
  local command_str="${1}"

  if [[ "${SHELL_UNDER_TEST}" == "bash" ]]; then
    run bash --noprofile --norc -c "source '${BASH_CONFIG_PATH}'; export MG_GIT_VERBOSE='1'; ${command_str}"
    return
  fi

  run fish --no-config --command "source '${FISH_CONFIG_PATH}'; source '${FISH_MG_PATH}'; set --global --export MG_GIT_VERBOSE '1'; ${command_str}"
}

@test "git-init creates project.git/bare and default-branch worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-init scratch"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/scratch.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/scratch.git/main/.git" ]
}

@test "git-clone creates bare layout and remotes/origin refs" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/demo.git/main/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" branch --all
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"remotes/origin/main"* ]]
}

@test "git-clone accepts single URL argument" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone github:testorg/demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/demo.git/main/.git" ]
}

@test "git-clone preserves git user from ssh URL" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone ssh://git@github.com/testorg/demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/demo.git/main/.git" ]
}

@test "git-clone rejects --host with single URL form" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone --host github github:testorg/demo"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Cannot use --host"* ]]
  [[ "${output}" == *"<url-or-local-path>"* ]]
}

@test "git-clone supports --host and env default host" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone --host codehub testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]

  _run_shell_with_host_env "codehub" "mkdir -p '${TEST_TMPDIR}/work/env'; cd '${TEST_TMPDIR}/work/env'; git-clone testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/env/demo.git/bare" ]
}

@test "git-clone accepts absolute local path source" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git'"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/myproject.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/myproject.git/main/.git" ]
}

@test "git-clone accepts relative local path source" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone ../remotes/localdisk/myproject.git --dest alpha-3rd"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/alpha-3rd.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/alpha-3rd.git/main/.git" ]
}

@test "git-clone supports --dest with local path source" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/alpha-copy'"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/alpha-copy.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/alpha-copy.git/main/.git" ]
}

@test "git-clone --dest ending with .git keeps suffix" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/beta-copy.git'"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/beta-copy.git/bare" ]
  [ ! -d "${TEST_TMPDIR}/work/beta-copy.git.git" ]
}

@test "git-clone emits xtrace when MG_GIT_VERBOSE=1" {
  _run_shell_with_verbose_env "cd '${TEST_TMPDIR}/work'; git-clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/verbose-copy'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"git clone --bare"* ]]
}

@test "git-new-branch creates sibling feature worktree and cds" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-new-branch feature-new; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-new"* ]]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-new/.git" ]
}

@test "git-self-branch uses existing remote and creates matching branch" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git -C ../bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; git-self-branch upstream feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-existing/.git" ]
}

@test "git-self-branch requires existing remote" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-self-branch collab feature-existing"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Remote 'collab' is not configured."* ]]
}

@test "git-self-branch fails for absolute path remote argument" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-self-branch '${TEST_TMPDIR}/remotes/localdisk/myproject.git' feature-existing"
  [ "${status}" -ne 0 ]
}

@test "git-self-branch keeps existing remote URL unchanged" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/alpha-copy'"
  [ "${status}" -eq 0 ]

  run git -C "${TEST_TMPDIR}/work/alpha-copy.git/bare" remote get-url origin
  [ "${status}" -eq 0 ]
  local before_origin_url="${output}"

  _run_shell "cd '${TEST_TMPDIR}/work/alpha-copy.git/main'; git-self-branch origin feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/alpha-copy.git/feature-existing/.git" ]

  run git -C "${TEST_TMPDIR}/work/alpha-copy.git/bare" remote get-url origin
  [ "${status}" -eq 0 ]
  local after_origin_url="${output}"

  [ "${before_origin_url}" = "${after_origin_url}" ]
}

@test "git-alien-branch works with existing absolute-path remote URL" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/alpha-copy'"
  [ "${status}" -eq 0 ]

  _run_shell "cd '${TEST_TMPDIR}/work/alpha-copy.git/main'; git-alien-branch origin feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/alpha-copy.git/origin_feature-existing/.git" ]
}

@test "git-self-branch does not mutate existing remote URL on failure" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo"
  [ "${status}" -eq 0 ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" remote get-url origin
  [ "${status}" -eq 0 ]
  local before_origin_url="${output}"

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-self-branch origin does-not-exist"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Remote branch not found"* ]]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" remote get-url origin
  [ "${status}" -eq 0 ]
  local after_origin_url="${output}"

  [ "${before_origin_url}" = "${after_origin_url}" ]
}

@test "git-self-branch and git-alien-branch cd into worktree in bash" {
  if [[ "${SHELL_UNDER_TEST}" != "bash" ]]; then
    skip "cd behavior is implemented in bash wrapper context"
  fi

  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-self-branch origin feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-existing" ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git -C ../bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; git-alien-branch upstream feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/upstream_feature-existing" ]]
}

@test "git-alien-branch creates prefixed branch worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; cd demo.git/main; git-alien-branch upstream feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/upstream_feature-existing/.git" ]
}

@test "git-alien-branch rejects absolute path remote argument" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-alien-branch '${TEST_TMPDIR}/remotes/localdisk/myproject.git' feature-existing"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"must be a remote name"* ]]
}

@test "git-show-untracked and git-show-ignored report expected files" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; printf 'ignored.log\n' > .gitignore; git add .gitignore; git commit --message 'add ignore'; touch ignored.log; touch note.txt; git-show-untracked"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"note.txt"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-show-ignored"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"ignored.log"* ]]
}

@test "git-switch changes to branch worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-switch feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/feature-existing'; git branch --show-current"
  [ "${status}" -eq 0 ]
  [ "${output}" = "feature-existing" ]
}

@test "git-switch suggests new-branch when branch is missing everywhere" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-switch does-not-exist"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Branch not found locally or in origin/upstream"* ]]
  [[ "${output}" == *"mg new-branch does-not-exist"* ]]
}

@test "git-update-commit-date amends most recent commit" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git rev-parse HEAD"
  [ "${status}" -eq 0 ]
  local before_sha="${output}"

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-update-commit-date; git rev-parse HEAD"
  [ "${status}" -eq 0 ]
  local after_sha="${output}"

  [ "${before_sha}" != "${after_sha}" ]
}

@test "git-init is blocked inside managed parent directory" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git; git-init nested"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"managed parent directory"* ]]
}

@test "git-clone is blocked inside managed worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-clone testorg demo"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"managed parent directory"* ]]
}

@test "git-init rejects existing non-layout target path" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mkdir scratch.git; touch scratch.git/README; git-init scratch"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"target path exists"* ]]
  [[ "${output}" == *"scratch.git"* ]]
}

@test "git-clone rejects existing non-layout target path" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mkdir demo.git; touch demo.git/README; git-clone testorg demo"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"target path exists"* ]]
  [[ "${output}" == *"demo.git"* ]]
}

@test "git-new-branch and git-switch reject invalid branch names" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-new-branch 'bad branch'"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Invalid branch name"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-switch 'bad branch'"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Invalid branch name"* ]]
}

@test "git-self-branch and git-alien-branch reject invalid branch names" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-self-branch origin 'bad branch'"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Invalid branch name"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-alien-branch upstream 'bad branch'"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Invalid branch name"* ]]
}

@test "git-switch rejects path collisions that are not worktrees" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; mkdir demo.git/collision; cd demo.git/main; git-switch collision"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Worktree path exists"* ]]
}

@test "git-alien-branch reports missing remote with guidance" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-alien-branch stranger feature-existing"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"not configured"* ]]
  [[ "${output}" == *"remote add stranger"* ]]
}

@test "git-alien-branch reports missing remote branch" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; cd demo.git/main; git-alien-branch upstream does-not-exist"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Remote branch not found"* ]]
  [[ "${output}" == *"upstream/does-not-exist"* ]]
}

@test "git-info shows repository inventory" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git -C '${TEST_TMPDIR}/remotes/upstream/demo' update-ref refs/heads/upstream-only refs/heads/main; git-clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; git -C demo.git/bare fetch upstream --prune; cd demo.git/main; git-self-branch origin feature-existing; git-info"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Parent:"* ]]
  [[ "${output}" == *"Bare:"* ]]
  [[ "${output}" == *"Remotes:"* ]]
  [[ "${output}" == *"Remote branches for origin or upstream:"* ]]
  [[ "${output}" == *"origin/feature-existing -> feature-existing"* ]]
  [[ "${output}" == *"origin/main -> main"* ]]
  [[ "${output}" == *"upstream/upstream-only -> (none)"* ]]
  local tracked_before_untracked="${output%%upstream/upstream-only -> (none)*}"
  [[ "${tracked_before_untracked}" == *"origin/feature-existing -> feature-existing"* ]]
  [[ "${output}" == *"Worktrees:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-info"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Parent:"* ]]
  [[ "${output}" == *"Remote branches for origin or upstream:"* ]]
  [[ "${output}" == *"Worktrees:"* ]]
}

@test "git-path prints managed worktree path" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-path feature-existing"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-existing" ]]
}

@test "git-remove-branch removes merged branch and worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-new-branch feature-clean; cd ../feature-clean; printf 'clean\n' > clean.txt; git add clean.txt; git commit --message 'clean feature'; git -C ../main merge --no-ff feature-clean --message 'merge feature-clean'; cd ../main; git-remove-branch feature-clean"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-clean/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/heads/feature-clean
  [ "${status}" -ne 0 ]
}

@test "git-remove-branch blocks unmerged branches" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-new-branch feature-stuck; cd ../feature-stuck; printf 'stuck\n' > stuck.txt; git add stuck.txt; git commit --message 'stuck feature'; cd ../main; git-remove-branch feature-stuck"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"not fully merged"* ]]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-stuck/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/heads/feature-stuck
  [ "${status}" -eq 0 ]
}

@test "git-remove-branch --force removes unmerged branches" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-new-branch feature-force; cd ../feature-force; printf 'force\n' > force.txt; git add force.txt; git commit --message 'force feature'; cd ../main; git-remove-branch --force feature-force"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-force/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/heads/feature-force
  [ "${status}" -ne 0 ]
}

@test "git-prune removes stale remote-tracking refs" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; git -C '${TEST_TMPDIR}/remotes/testorg/demo' update-ref -d refs/heads/feature-existing; cd demo.git/main; git-prune"
  [ "${status}" -eq 0 ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/remotes/origin/feature-existing
  [ "${status}" -ne 0 ]
}

@test "example output is available across command groups" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-update-commit-date --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-switch --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-info --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git-remove-branch --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]
}
