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
  set --local resolved_subcommand

  switch "$argv[1]"
  case u
    set resolved_subcommand update-commit-date
  case c
    set resolved_subcommand clone
  case s
    set resolved_subcommand switch
  case n
    set resolved_subcommand new-branch
  case b
    set resolved_subcommand self-branch
  case i
    set resolved_subcommand info
  case rb
    set resolved_subcommand remove-branch
  case rw
    set resolved_subcommand remove-worktree
  case '*'
    set resolved_subcommand "$argv[1]"
  end

  if test "$resolved_subcommand" = switch
    if test (count $argv) -eq 2
      if test "$argv[2]" != --example; and test "$argv[2]" != --help
        set should_cd 1
        set branch "$argv[2]"
      end
    end
  else if test "$resolved_subcommand" = new-branch
    set --local positional_branch
    set --local token_index 2

    while test $token_index -le (count $argv)
      set --local token "$argv[$token_index]"

      switch "$token"
      case --help --example
        set positional_branch
        break
      case --from
        set token_index (math "$token_index + 2")
        continue
      case '--*'
        set positional_branch
        break
      case '*'
        if test -n "$positional_branch"
          set positional_branch
          break
        end
        set positional_branch "$token"
      end

      set token_index (math "$token_index + 1")
    end

    if test -n "$positional_branch"
      set should_cd 1
      set branch "$positional_branch"
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
