#!/usr/bin/env bats

. "${BATS_TEST_DIRNAME}/git-shell-common.bash"

@test "bare-siblings.git layout reports expected layout kind" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git clone --bare 'file://${TEST_TMPDIR}/remotes/testorg/demo' demo.git; git -C demo.git worktree add ../main main; cd main; mg info"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Layout: bare-siblings.git"* ]]
}

@test "bare-siblings.git layout creates sibling branch worktrees" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git clone --bare 'file://${TEST_TMPDIR}/remotes/testorg/demo' demo.git; git -C demo.git worktree add ../main main; cd main; mg new-branch feature-git; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/work/feature-git" ]]
  [ -e "${TEST_TMPDIR}/work/feature-git/.git" ]
}

@test "bare-siblings layout reports expected layout kind" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git clone --bare 'file://${TEST_TMPDIR}/remotes/testorg/demo' bare; git -C bare worktree add main main; cd bare/main; mg info"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Layout: bare-siblings"* ]]
  [[ "${output}" == *"Parent: ${TEST_TMPDIR}/work/bare"* ]]
}

@test "bare-siblings layout creates sibling tracked branch worktrees" {
  _run_shell "cd '${TEST_TMPDIR}/work'; git clone --bare 'file://${TEST_TMPDIR}/remotes/testorg/demo' bare; git -C bare worktree add main main; cd bare/main; mg switch feature-existing; pwd"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/work/bare/feature-existing" ]]
  [ -e "${TEST_TMPDIR}/work/bare/feature-existing/.git" ]
}
