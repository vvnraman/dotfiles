function __mg_script_path
  if set --query BATS_TEST_MG_SCRIPT_PATH; and test -n "$BATS_TEST_MG_SCRIPT_PATH"
    echo "$BATS_TEST_MG_SCRIPT_PATH"
    return
  end

  if test -f "$HOME/.local/bin/mg"
    echo "$HOME/.local/bin/mg"
    return
  end

  if command --search --quiet mg
    command --search mg
    return
  end

  return 1
end

function __mg_metadata_lines
  set --local script_path (__mg_script_path)
  test -n "$script_path"; or return
  command bash "$script_path" __complete-metadata
end

function __mg_load_metadata
  if set --query __mg_meta_loaded
    return
  end

  set --global __mg_meta_loaded 1
  set --global __mg_meta_commands
  set --global __mg_meta_alias_map
  set --global __mg_meta_opts_map
  set --global __mg_meta_branch_arg_map
  set --global __mg_meta_branch_scope_map
  set --global __mg_meta_value_opt_map

  for line in (__mg_metadata_lines)
    set --local fields (string split '|' -- $line)
    set --local record_type $fields[1]

    switch "$record_type"
    case cmd
      set --local command_name $fields[2]
      set --local alias_name $fields[3]
      if test -n "$command_name"
        set --append __mg_meta_commands $command_name
      end
      if test -n "$alias_name"
        set --append __mg_meta_alias_map "$command_name=$alias_name"
      end
    case opts
      set --append __mg_meta_opts_map "$fields[2]=$fields[3]"
    case branch
      set --append __mg_meta_branch_arg_map "$fields[2]=$fields[3]"
      set --append __mg_meta_branch_scope_map "$fields[2]=$fields[4]"
    case value-opt
      set --append __mg_meta_value_opt_map "$fields[2]=$fields[3]"
    end
  end
end

function __mg_map_get --argument-names key map_items
  for item in $map_items
    if string match --quiet "$key=*" -- $item
      string replace -- "$key=" '' $item
      return
    end
  end
end

function __mg_alias_for_command --argument-names command_name
  __mg_load_metadata
  __mg_map_get "$command_name" $__mg_meta_alias_map
end

function __mg_options_for_command --argument-names command_name
  __mg_load_metadata
  set --local csv_values (__mg_map_get "$command_name" $__mg_meta_opts_map)
  if test -z "$csv_values"
    return
  end

  for option_name in (string split ',' -- $csv_values)
    echo $option_name
  end
end

function __mg_has_value_option --argument-names command_name option_name
  __mg_load_metadata
  for item in $__mg_meta_value_opt_map
    if test "$item" = "$command_name=$option_name"
      return 0
    end
  end
  return 1
end

function __mg_git_remotes
  command git rev-parse --git-dir 1>/dev/null 2>/dev/null; or return
  command git remote 2>/dev/null
end

function __mg_git_branches
  command git rev-parse --git-dir 1>/dev/null 2>/dev/null; or return

  set --local seen

  set --local local_refs (command git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
  for ref in $local_refs
    if not contains -- $ref $seen
      set --append seen $ref
      echo $ref
    end
  end

  set --local refs (command git for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null)
  for ref in $refs
    if string match --quiet --regex '.*/HEAD$' -- $ref
      continue
    end

    if not string match --quiet '*/*' -- $ref
      continue
    end

    if not contains -- $ref $seen
      set --append seen $ref
      echo $ref
    end

    if string match --quiet '*/*' -- $ref
      set --local short_ref (string replace --regex '^[^/]+/' '' $ref)
      if test -n "$short_ref"; and not contains -- $short_ref $seen
        set --append seen $short_ref
        echo $short_ref
      end
    end
  end
end

function __mg_remote_branches
  set --local remote_name $argv[1]

  if test -z "$remote_name"
    set --local tokens (commandline --tokenize --current-process)
    if test (count $tokens) -lt 3
      return
    end
    set remote_name $tokens[3]
  end

  test -n "$remote_name"; or return

  command git rev-parse --git-dir 1>/dev/null 2>/dev/null; or return

  set --local seen
  set --local refs (command git for-each-ref --format='%(refname:short)' "refs/remotes/$remote_name" 2>/dev/null)
  for ref in $refs
    if string match --quiet --regex '.*/HEAD$' -- $ref
      continue
    end

    if not string match --quiet "$remote_name/*" -- $ref
      continue
    end

    set --local short_ref (string replace -- "$remote_name/" '' $ref)
    if test -z "$short_ref"
      continue
    end

    if not contains -- $short_ref $seen
      set --append seen $short_ref
      echo $short_ref
    end
  end
end

function __mg_positional_arg_index
  set --local line (commandline)
  set --local tokens (commandline --tokenize --current-process)
  set --local index (math (count $tokens) - 2)

  if string match --quiet --regex '\\s$' -- "$line"
    set index (math "$index + 1")
  end

  if test $index -lt 0
    set index 0
  end

  echo $index
end

function __mg_complete_branch_arg1
  if test (__mg_positional_arg_index) -ne 1
    return
  end

  if string match --quiet --regex '^-' -- (commandline --current-token)
    return
  end

  __mg_git_branches
end

function __mg_complete_remove_branch_target
  set --local tokens (commandline --tokenize --current-process)
  set --local index (__mg_positional_arg_index)

  if string match --quiet --regex '^-' -- (commandline --current-token)
    return
  end

  if test $index -eq 1
    __mg_git_branches
    return
  end

  if test $index -eq 2; and test (count $tokens) -ge 3; and test "$tokens[3]" = "--force"
    __mg_git_branches
  end
end

function __mg_complete_remote_arg1
  if test (__mg_positional_arg_index) -ne 1
    return
  end

  if string match --quiet --regex '^-' -- (commandline --current-token)
    return
  end

  __mg_git_remotes
end

function __mg_complete_remote_branch_arg2
  if test (__mg_positional_arg_index) -ne 2
    return
  end

  if string match --quiet --regex '^-' -- (commandline --current-token)
    return
  end

  __mg_remote_branches
end

complete --command mg --erase

__mg_load_metadata

complete --command mg --no-files --condition '__fish_use_subcommand' --arguments --help
complete --command mg --no-files --condition '__fish_use_subcommand' --arguments -h
complete --command mg --no-files --condition '__fish_use_subcommand' --arguments --short-help

for command_name in $__mg_meta_commands
  set --local alias_name (__mg_alias_for_command "$command_name")

  complete --command mg --no-files --condition '__fish_use_subcommand' --arguments "$command_name"
  if test -n "$alias_name"
    complete --command mg --no-files --condition '__fish_use_subcommand' --arguments "$alias_name"
  end

  set --local options (__mg_options_for_command "$command_name")
  for option_name in $options
    set --local option_word (string replace -- '--' '' "$option_name")

    set --local condition_args "$command_name"
    if test -n "$alias_name"
      set condition_args "$condition_args $alias_name"
    end

    if __mg_has_value_option "$command_name" "$option_name"
      complete --command mg --condition "__fish_seen_subcommand_from $condition_args" --long-option "$option_word" --require-parameter
    else
      complete --command mg --condition "__fish_seen_subcommand_from $condition_args" --long-option "$option_word"
    end
  end
end

complete --command mg --no-files --condition '__fish_seen_subcommand_from self-branch b' --arguments '(__mg_complete_remote_arg1)' --description 'Remote name'
complete --command mg --no-files --condition '__fish_seen_subcommand_from self-branch b' --arguments '(__mg_complete_remote_branch_arg2)' --description 'Branch name'

complete --command mg --no-files --condition '__fish_seen_subcommand_from alien-branch' --arguments '(__mg_complete_remote_arg1)' --description 'Remote name'
complete --command mg --no-files --condition '__fish_seen_subcommand_from alien-branch' --arguments '(__mg_complete_remote_branch_arg2)' --description 'Branch name'

complete --command mg --no-files --condition '__fish_seen_subcommand_from switch s' --arguments '(__mg_complete_branch_arg1)' --description 'Branch name'
complete --command mg --no-files --condition '__fish_seen_subcommand_from new-branch n' --arguments '(__mg_complete_branch_arg1)' --description 'Branch name'
complete --command mg --no-files --condition '__fish_seen_subcommand_from path' --arguments '(__mg_complete_branch_arg1)' --description 'Branch name'
complete --command mg --no-files --condition '__fish_seen_subcommand_from remove-branch r' --arguments '(__mg_complete_remove_branch_target)' --description 'Branch name'
