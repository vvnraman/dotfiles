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

  git config --global url."file://${TEST_TMPDIR}/remotes/testorg/".insteadOf "github:testorg/"
  git config --global url."file://${TEST_TMPDIR}/remotes/upstream/".insteadOf "github:upstream/"
  git config --global url."file://${TEST_TMPDIR}/remotes/collab/".insteadOf "github:collab/"
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

@test "git-clone supports --host and env default host" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone --host codehub testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]

  _run_shell_with_host_env "codehub" "mkdir -p '${TEST_TMPDIR}/work/env'; cd '${TEST_TMPDIR}/work/env'; git-clone testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/env/demo.git/bare" ]
}

@test "git-new-branch creates sibling feature worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-new-branch feature-new"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-new/.git" ]
}

@test "git-branch-new-remote derives remote url and prefixes branch" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-branch-new-remote --host codehub upstream feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/upstream_feature-existing/.git" ]
}

@test "git-branch-new-remote accepts --url" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-branch-new-remote --url 'file://${TEST_TMPDIR}/remotes/collab/demo' collab feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/collab_feature-existing/.git" ]
}

@test "git-branch-existing-remote creates prefixed worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; cd demo.git/main; git-branch-existing-remote upstream feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/upstream_feature-existing/.git" ]
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
  _run_shell "cd '${TEST_TMPDIR}/work'; git-clone testorg demo; cd demo.git/main; git-switch switch-check; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/switch-check"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/switch-check'; git branch --show-current"
  [ "${status}" -eq 0 ]
  [ "${output}" = "switch-check" ]
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
