function mg --description "Run shared git workflows"
  if test (count $argv) -gt 0; and test "$argv[1]" = switch
    if test (count $argv) -ne 2
      echo "Usage: switch <branch>"
      return 1
    end

    set --local branch "$argv[2]"
    if test -z (string replace --all --regex '\\s' '' -- "$branch")
      echo "<branch> name is not valid."
      return 1
    end

    set --local bare_dir (git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    if test -z "$bare_dir"
      echo "Not inside a git repository."
      return 1
    end

    set --local project_dir (dirname "$bare_dir")
    set --local worktree_dir "$project_dir/$branch"

    if test -e "$worktree_dir/.git"
      cd "$worktree_dir"
      return
    end

    if git -C "$bare_dir" show-ref --verify --quiet "refs/heads/$branch"
      git -C "$bare_dir" worktree add "../$branch" "$branch"; or return
      cd "$worktree_dir"; or return
      return
    end

    mg new-branch "$branch"; or return
    cd "$worktree_dir"
    return
  end

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

  bash "$script_path" $argv
end
