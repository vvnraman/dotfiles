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
    export BASH_COMPLETION_PATH="${repo_root}/home/dot-bash/completions/mg.bash"
  else
    export FISH_CONFIG_PATH="${repo_root}/home/dot_config/fish/conf.d/git-config.fish"
    export FISH_MG_PATH="${repo_root}/home/dot_config/fish/functions/mg.fish"
    export FISH_MG_COMPLETION_PATH="${repo_root}/home/dot_config/fish/completions/mg.fish"
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
    run bash --noprofile --norc -c "source '${BASH_CONFIG_PATH}'; source '${BASH_COMPLETION_PATH}'; ${command_str}"
    return
  fi

  run fish --no-config --command "source '${FISH_CONFIG_PATH}'; source '${FISH_MG_PATH}'; source '${FISH_MG_COMPLETION_PATH}'; ${command_str}"
}

_run_shell_with_host_env() {
  local host="${1}"
  local command_str="${2}"

  if [[ "${SHELL_UNDER_TEST}" == "bash" ]]; then
    run bash --noprofile --norc -c "source '${BASH_CONFIG_PATH}'; source '${BASH_COMPLETION_PATH}'; export VVN_DOTFILES_GITHUB_HOST='${host}'; ${command_str}"
    return
  fi

  run fish --no-config --command "source '${FISH_CONFIG_PATH}'; source '${FISH_MG_PATH}'; source '${FISH_MG_COMPLETION_PATH}'; set --global --export VVN_DOTFILES_GITHUB_HOST '${host}'; ${command_str}"
}

_run_shell_with_verbose_env() {
  local command_str="${1}"

  if [[ "${SHELL_UNDER_TEST}" == "bash" ]]; then
    run bash --noprofile --norc -c "source '${BASH_CONFIG_PATH}'; source '${BASH_COMPLETION_PATH}'; export MG_GIT_VERBOSE='1'; ${command_str}"
    return
  fi

  run fish --no-config --command "source '${FISH_CONFIG_PATH}'; source '${FISH_MG_PATH}'; source '${FISH_MG_COMPLETION_PATH}'; set --global --export MG_GIT_VERBOSE '1'; ${command_str}"
}
