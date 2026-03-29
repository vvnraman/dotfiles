#!/usr/bin/env bats

. "${BATS_TEST_DIRNAME}/git-shell-common.bash"

@test "git-init creates project.git/bare and default-branch worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg init scratch"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/scratch.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/scratch.git/main/.git" ]
}

@test "git-clone creates bare layout and remotes/origin refs" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/demo.git/main/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" branch --all
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"remotes/origin/main"* ]]
}

@test "git-clone accepts single URL argument" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone github:testorg/demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/demo.git/main/.git" ]
}

@test "git-clone preserves git user from ssh URL" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone ssh://git@github.com/testorg/demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/demo.git/main/.git" ]
}

@test "git-clone rejects --host with single URL form" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone --host github github:testorg/demo"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Cannot use --host"* ]]
  [[ "${output}" == *"<url-or-local-path>"* ]]
}

@test "git-clone supports --host and env default host" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone --host codehub testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]

  _run_shell_with_host_env "codehub" "mkdir -p '${TEST_TMPDIR}/work/env'; cd '${TEST_TMPDIR}/work/env'; mg clone testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/env/demo.git/bare" ]
}

@test "git-clone accepts absolute local path source" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git'"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/myproject.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/myproject.git/main/.git" ]
}

@test "git-clone accepts relative local path source" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone ../remotes/localdisk/myproject.git --dest alpha-3rd"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/alpha-3rd.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/alpha-3rd.git/main/.git" ]
}

@test "git-clone supports --dest with local path source" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/alpha-copy'"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/alpha-copy.git/bare" ]
  [ -e "${TEST_TMPDIR}/work/alpha-copy.git/main/.git" ]
}

@test "git-clone --dest ending with .git keeps suffix" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/beta-copy.git'"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/beta-copy.git/bare" ]
  [ ! -d "${TEST_TMPDIR}/work/beta-copy.git.git" ]
}

@test "git-clone emits xtrace when MG_GIT_VERBOSE=1" {
  _run_shell_with_verbose_env "cd '${TEST_TMPDIR}/work'; mg clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/verbose-copy'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"git clone --bare"* ]]
}

@test "git-new-branch creates sibling feature worktree and cds" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg new-branch feature-new; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-new"* ]]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-new/.git" ]
}

@test "git-new-branch defaults base branch to current branch" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg switch feature-existing; mg new-branch feature-from-current"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-from-current/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" merge-base --is-ancestor refs/heads/feature-existing refs/heads/feature-from-current
  [ "${status}" -eq 0 ]
}

@test "git-new-branch --from overrides current branch base" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg switch feature-existing; mg new-branch --from main feature-from-main"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-from-main/.git" ]
  [ ! -f "${TEST_TMPDIR}/work/demo.git/feature-from-main/feature.txt" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" merge-base --is-ancestor refs/heads/main refs/heads/feature-from-main
  [ "${status}" -eq 0 ]
}

@test "git-self-branch uses existing remote and creates matching branch" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; git -C ../bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; mg self-branch upstream feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-existing/.git" ]
}

@test "git-self-branch requires existing remote" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg self-branch collab feature-existing"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Remote 'collab' is not configured."* ]]
}

@test "git-self-branch fails for absolute path remote argument" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg self-branch '${TEST_TMPDIR}/remotes/localdisk/myproject.git' feature-existing"
  [ "${status}" -ne 0 ]
}

@test "git-self-branch keeps existing remote URL unchanged" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/alpha-copy'"
  [ "${status}" -eq 0 ]

  run git -C "${TEST_TMPDIR}/work/alpha-copy.git/bare" remote get-url origin
  [ "${status}" -eq 0 ]
  local before_origin_url="${output}"

  _run_shell "cd '${TEST_TMPDIR}/work/alpha-copy.git/main'; mg self-branch origin feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/alpha-copy.git/feature-existing/.git" ]

  run git -C "${TEST_TMPDIR}/work/alpha-copy.git/bare" remote get-url origin
  [ "${status}" -eq 0 ]
  local after_origin_url="${output}"

  [ "${before_origin_url}" = "${after_origin_url}" ]
}

@test "git-alien-branch works with existing absolute-path remote URL" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone '${TEST_TMPDIR}/remotes/localdisk/myproject.git' --dest '${TEST_TMPDIR}/work/alpha-copy'"
  [ "${status}" -eq 0 ]

  _run_shell "cd '${TEST_TMPDIR}/work/alpha-copy.git/main'; mg alien-branch origin feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/alpha-copy.git/origin_feature-existing/.git" ]
}

@test "git-self-branch does not mutate existing remote URL on failure" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo"
  [ "${status}" -eq 0 ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" remote get-url origin
  [ "${status}" -eq 0 ]
  local before_origin_url="${output}"

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg self-branch origin does-not-exist"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Remote branch not found"* ]]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" remote get-url origin
  [ "${status}" -eq 0 ]
  local after_origin_url="${output}"

  [ "${before_origin_url}" = "${after_origin_url}" ]
}

@test "mg self-branch and alien-branch cd into worktree in bash" {
  if [[ "${SHELL_UNDER_TEST}" != "bash" ]]; then
    skip "cd behavior is implemented in bash wrapper context"
  fi

  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg self-branch origin feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-existing" ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git -C ../bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; mg alien-branch upstream feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/upstream_feature-existing" ]]
}

@test "git-alien-branch creates prefixed branch worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; cd demo.git/main; mg alien-branch upstream feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/upstream_feature-existing/.git" ]
}

@test "git-alien-branch rejects absolute path remote argument" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg alien-branch '${TEST_TMPDIR}/remotes/localdisk/myproject.git' feature-existing"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"must be a remote name"* ]]
}

@test "git-show-untracked and git-show-ignored report expected files" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; printf 'ignored.log\n' > .gitignore; git add .gitignore; git commit --message 'add ignore'; touch ignored.log; touch note.txt; mg show-untracked"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"note.txt"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg show-ignored"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"ignored.log"* ]]
}

@test "git-switch changes to branch worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg switch feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/feature-existing'; git branch --show-current"
  [ "${status}" -eq 0 ]
  [ "${output}" = "feature-existing" ]
}

@test "git-switch suggests new-branch when branch is missing everywhere" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg switch does-not-exist"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Branch not found locally or in origin/upstream"* ]]
  [[ "${output}" == *"mg new-branch does-not-exist"* ]]
}

@test "git-update-commit-date amends most recent commit" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; git rev-parse HEAD"
  [ "${status}" -eq 0 ]
  local before_sha="${output}"

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg update-commit-date; git rev-parse HEAD"
  [ "${status}" -eq 0 ]
  local after_sha="${output}"

  [ "${before_sha}" != "${after_sha}" ]
}

@test "git-init is blocked inside managed parent directory" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git; mg init nested"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"managed parent directory"* ]]
}

@test "git-clone is blocked inside managed worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg clone testorg demo"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"managed parent directory"* ]]
}

@test "git-init rejects existing non-layout target path" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mkdir scratch.git; touch scratch.git/README; mg init scratch"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"target path exists"* ]]
  [[ "${output}" == *"scratch.git"* ]]
}

@test "git-clone rejects existing non-layout target path" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mkdir demo.git; touch demo.git/README; mg clone testorg demo"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"target path exists"* ]]
  [[ "${output}" == *"demo.git"* ]]
}

@test "git-new-branch and git-switch reject invalid branch names" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg new-branch 'bad branch'"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Invalid branch name"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg switch 'bad branch'"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Invalid branch name"* ]]
}

@test "git-self-branch and git-alien-branch reject invalid branch names" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg self-branch origin 'bad branch'"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Invalid branch name"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg alien-branch upstream 'bad branch'"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Invalid branch name"* ]]
}

@test "git-switch rejects path collisions that are not worktrees" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; mkdir demo.git/collision; cd demo.git/main; mg switch collision"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Worktree path exists"* ]]
}

@test "git-alien-branch reports missing remote with guidance" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg alien-branch stranger feature-existing"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"not configured"* ]]
  [[ "${output}" == *"remote add stranger"* ]]
}

@test "git-alien-branch reports missing remote branch" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; cd demo.git/main; mg alien-branch upstream does-not-exist"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Remote branch not found"* ]]
  [[ "${output}" == *"upstream/does-not-exist"* ]]
}

@test "git-info shows repository inventory" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git -C '${TEST_TMPDIR}/remotes/upstream/demo' update-ref refs/heads/upstream-only refs/heads/main; mg clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; git -C demo.git/bare fetch upstream --prune; cd demo.git/main; mg self-branch origin feature-existing; mg info"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Parent:"* ]]
  [[ "${output}" == *"Bare:"* ]]
  [[ "${output}" == *"Layout:"* ]]
  [[ "${output}" == *"Default worktree:"* ]]
  [[ "${output}" == *"New sample worktree:"* ]]
  [[ "${output}" == *"Remotes:"* ]]
  [[ "${output}" == *"Remote branches for origin or upstream:"* ]]
  [[ "${output}" == *"origin/feature-existing -> feature-existing"* ]]
  [[ "${output}" == *"origin/main -> main"* ]]
  [[ "${output}" == *"upstream/upstream-only -> (none)"* ]]
  local tracked_before_untracked="${output%%upstream/upstream-only -> (none)*}"
  [[ "${tracked_before_untracked}" == *"origin/feature-existing -> feature-existing"* ]]
  [[ "${output}" == *"Worktrees:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg info"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Parent:"* ]]
  [[ "${output}" == *"Layout:"* ]]
  [[ "${output}" == *"Remote branches for origin or upstream:"* ]]
  [[ "${output}" == *"Worktrees:"* ]]
}

@test "git-path prints managed worktree path" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg path feature-existing"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-existing" ]]
}

@test "git-remove-worktree removes worktree and keeps branch" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg new-branch feature-scratch; cd ../main; mg remove-worktree feature-scratch"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Deleted worktree for branch \`feature-scratch\` at \`${TEST_TMPDIR}/work/demo.git/feature-scratch\`."* ]]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-scratch/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/heads/feature-scratch
  [ "${status}" -eq 0 ]
}

@test "git-remove-worktree alias rw dispatches command" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg new-branch feature-rw; cd ../main; mg rw feature-rw"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Deleted worktree for branch \`feature-rw\` at \`${TEST_TMPDIR}/work/demo.git/feature-rw\`."* ]]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-rw/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/heads/feature-rw
  [ "${status}" -eq 0 ]
}

@test "git-remove-branch removes merged branch and worktree" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg new-branch feature-clean; cd ../feature-clean; printf 'clean\n' > clean.txt; git add clean.txt; git commit --message 'clean feature'; git -C ../main merge --no-ff feature-clean --message 'merge feature-clean'; cd ../main; mg remove-branch feature-clean"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-clean/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/heads/feature-clean
  [ "${status}" -ne 0 ]
}

@test "git-remove-branch blocks unmerged branches" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg new-branch feature-stuck; cd ../feature-stuck; printf 'stuck\n' > stuck.txt; git add stuck.txt; git commit --message 'stuck feature'; cd ../main; mg remove-branch feature-stuck"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"not fully merged"* ]]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-stuck/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/heads/feature-stuck
  [ "${status}" -eq 0 ]
}

@test "git-remove-branch --force removes unmerged branches" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg new-branch feature-force; cd ../feature-force; printf 'force\n' > force.txt; git add force.txt; git commit --message 'force feature'; cd ../main; mg remove-branch --force feature-force"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-force/.git" ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/heads/feature-force
  [ "${status}" -ne 0 ]
}

@test "git-prune removes stale remote-tracking refs" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; git -C '${TEST_TMPDIR}/remotes/testorg/demo' update-ref -d refs/heads/feature-existing; cd demo.git/main; mg prune"
  [ "${status}" -eq 0 ]

  run git -C "${TEST_TMPDIR}/work/demo.git/bare" show-ref --verify --quiet refs/remotes/origin/feature-existing
  [ "${status}" -ne 0 ]
}

@test "example output is available across command groups" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; mg update-commit-date --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg switch --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg info --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg remove-branch --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]
}

@test "bash completion suggests branch names for switch new-branch remove commands" {
  if [[ "${SHELL_UNDER_TEST}" != "bash" ]]; then
    skip "bash-only completion behavior"
  fi

  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; COMP_WORDS=(mg switch f); COMP_CWORD=2; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
  if printf '%s\n' "${output}" | grep --quiet --line-regexp origin; then
    false
  fi

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg s f); COMP_CWORD=2; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg new-branch f); COMP_CWORD=2; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
  if printf '%s\n' "${output}" | grep --quiet --line-regexp origin; then
    false
  fi

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg new-branch --from f); COMP_CWORD=3; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg remove-branch f); COMP_CWORD=2; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg remove-branch --force f); COMP_CWORD=3; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg remove-worktree f); COMP_CWORD=2; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg rb --force f); COMP_CWORD=3; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
}

@test "bash completion keeps remote and remote-branch arguments separate" {
  if [[ "${SHELL_UNDER_TEST}" != "bash" ]]; then
    skip "bash-only completion behavior"
  fi

  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; git -C demo.git/bare fetch upstream --prune; cd demo.git/main; COMP_WORDS=(mg b o); COMP_CWORD=2; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"origin"* ]]
  if printf '%s\n' "${output}" | grep --quiet --line-regexp feature-existing; then
    false
  fi

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg b origin f); COMP_CWORD=3; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
  if printf '%s\n' "${output}" | grep --quiet --line-regexp origin; then
    false
  fi

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg alien-branch u); COMP_CWORD=2; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"upstream"* ]]
  if printf '%s\n' "${output}" | grep --quiet --line-regexp feature-existing; then
    false
  fi

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; COMP_WORDS=(mg alien-branch upstream f); COMP_CWORD=3; _mg_complete; printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
  if printf '%s\n' "${output}" | grep --quiet --line-regexp upstream; then
    false
  fi
}

@test "fish completion suggests branch names for switch new-branch remove commands" {
  if [[ "${SHELL_UNDER_TEST}" != "fish" ]]; then
    skip "fish-only completion behavior"
  fi

  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; cd demo.git/main; complete -C 'mg switch f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
  [[ "${output}" != *$'origin\tBranch name'* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg s f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg new-branch f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
  [[ "${output}" != *$'origin\tBranch name'* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg new-branch --from f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg remove-branch f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg remove-branch --force f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg remove-worktree f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *$'feature-existing\tBranch name'* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg rb --force f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *$'feature-existing\tBranch name'* ]]
}

@test "fish completion keeps remote and remote-branch arguments separate" {
  if [[ "${SHELL_UNDER_TEST}" != "fish" ]]; then
    skip "fish-only completion behavior"
  fi

  _run_shell "cd '${TEST_TMPDIR}/work'; mg clone testorg demo; git -C demo.git/bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; git -C demo.git/bare fetch upstream --prune; cd demo.git/main; complete -C 'mg b o'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *$'origin\tRemote name'* ]]
  [[ "${output}" != *$'feature-existing\tBranch name'* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg b origin f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
  [[ "${output}" != *$'origin\tBranch name'* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg alien-branch u'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *$'upstream\tRemote name'* ]]
  [[ "${output}" != *$'feature-existing\tBranch name'* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; complete -C 'mg alien-branch upstream f'"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"feature-existing"* ]]
  [[ "${output}" != *$'upstream\tBranch name'* ]]
}

@test "short aliases dispatch like full subcommands" {
  _run_shell "cd '${TEST_TMPDIR}/work'; mg c testorg demo"
  [ "${status}" -eq 0 ]
  [ -d "${TEST_TMPDIR}/work/demo.git/bare" ]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg i"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Parent:"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg s feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-existing"* ]]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg n feature-short; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/demo.git/feature-short"* ]]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-short/.git" ]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; git -C ../bare remote add upstream 'file://${TEST_TMPDIR}/remotes/upstream/demo'; git -C ../bare fetch upstream --prune; mg b upstream feature-existing"
  [ "${status}" -eq 0 ]
  [ -e "${TEST_TMPDIR}/work/demo.git/feature-existing/.git" ]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg rb --force feature-short"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-short/.git" ]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg n feature-short-rb; cd ../main; mg rb --force feature-short-rb"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-short-rb/.git" ]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg n feature-short-rw; cd ../main; mg rw feature-short-rw"
  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_TMPDIR}/work/demo.git/feature-short-rw/.git" ]

  _run_shell "cd '${TEST_TMPDIR}/work/demo.git/main'; mg u --example"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Examples:"* ]]
}
