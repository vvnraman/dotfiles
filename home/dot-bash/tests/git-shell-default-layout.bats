#!/usr/bin/env bats

. "${BATS_TEST_DIRNAME}/git-shell-common.bash"

@test "default layout reports expected layout kind" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git clone 'file://${TEST_TMPDIR}/remotes/testorg/demo' default-demo; cd default-demo; mg info"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Layout: default"* ]]
}

@test "default layout keeps default branch at repository root" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git clone 'file://${TEST_TMPDIR}/remotes/testorg/demo' default-demo; cd default-demo; mg path main"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/default-demo" ]]
}

@test "default layout creates branch worktrees in <repo>-worktrees" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git clone 'file://${TEST_TMPDIR}/remotes/testorg/demo' default-demo; cd default-demo; mg new-branch feature-default; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/default-demo-worktrees/feature-default" ]]
  [ -e "${TEST_TMPDIR}/work/default-demo-worktrees/feature-default/.git" ]
}

@test "default layout switch creates tracked remote branch in <repo>-worktrees" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git clone 'file://${TEST_TMPDIR}/remotes/testorg/demo' default-demo; cd default-demo; mg switch feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/default-demo-worktrees/feature-existing" ]]
  [ -e "${TEST_TMPDIR}/work/default-demo-worktrees/feature-existing/.git" ]
}
