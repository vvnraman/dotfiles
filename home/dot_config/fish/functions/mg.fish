function mg --description "Run shared git workflows"
  set --local script_path

  if set --query BATS_TEST_MG_SCRIPT_PATH; and test -n "$BATS_TEST_MG_SCRIPT_PATH"
    set script_path "$BATS_TEST_MG_SCRIPT_PATH"
  else if test -f "$HOME/.local/bin/mg"
    set script_path "$HOME/.local/bin/mg"
  else if command --search --quiet mg
    set script_path (command --search mg)
  else
    echo "mg not found in PATH or $HOME/.local/bin"
    return 1
  end

  set --local should_cd 0
  set --local branch

  if test (count $argv) -eq 2
    switch "$argv[1]"
    case switch new-branch
      if test "$argv[2]" != --example; and test "$argv[2]" != --help
        set should_cd 1
        set branch "$argv[2]"
      end
    end
  end

  bash "$script_path" $argv
  set --local command_status $status
  if test $command_status -ne 0
    return $command_status
  end

  if test $should_cd -eq 1
    set --local worktree_dir (bash "$script_path" path "$branch")
    set --local path_status $status
    if test $path_status -ne 0
      return $path_status
    end

    if test -z "$worktree_dir"
      echo "Unable to resolve worktree path for: $branch"
      return 1
    end

    cd "$worktree_dir"; or return 1
  end
end
