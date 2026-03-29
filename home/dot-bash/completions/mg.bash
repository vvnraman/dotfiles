# shellcheck shell=bash

declare -g _MG_COMPLETION_METADATA_LOADED=0
declare -a _MG_COMPLETION_COMMAND_WORDS=()
declare -A _MG_COMPLETION_ALIAS_TO_COMMAND=()
declare -A _MG_COMPLETION_OPTIONS=()
declare -A _MG_COMPLETION_BRANCH_ARG_POSITION=()
declare -A _MG_COMPLETION_BRANCH_SCOPE=()
declare -A _MG_COMPLETION_REMOTE_ARG_POSITION=()
declare -A _MG_COMPLETION_REMOTE_BRANCH_ARG_POSITION=()
declare -A _MG_COMPLETION_VALUE_OPTIONS=()

function _mg_completion_script_path() {
  if declare -F _mg_script_path 1>/dev/null 2>&1; then
    _mg_script_path
    return
  fi

  if [[ -n "${BATS_TEST_MG_SCRIPT_PATH:-}" ]]; then
    printf '%s\n' "${BATS_TEST_MG_SCRIPT_PATH}"
    return
  fi

  if [[ -f "${HOME}/.local/bin/mg" ]]; then
    printf '%s\n' "${HOME}/.local/bin/mg"
    return
  fi

  if type -P mg 1>/dev/null 2>&1; then
    type -P mg
    return
  fi

  return 1
}

function _mg_completion_split_csv() {
  local csv_values="${1}"

  if [[ -z "${csv_values}" ]]; then
    return
  fi

  local old_ifs="${IFS}"
  IFS=','
  # shellcheck disable=SC2206
  local values=( ${csv_values} )
  IFS="${old_ifs}"

  printf '%s\n' "${values[@]}"
}

function _mg_completion_load_metadata() {
  local script_path
  local metadata_line
  local record_type
  local command_name
  local alias_name
  local value
  local position
  local scope
  local -a fields=()

  if [[ "${_MG_COMPLETION_METADATA_LOADED}" -eq 1 ]]; then
    return 0
  fi

  script_path="$(_mg_completion_script_path)" || return 1

  while IFS= read -r metadata_line; do
    [[ -n "${metadata_line}" ]] || continue

    fields=()
    IFS='|' read -r -a fields <<<"${metadata_line}"

    record_type="${fields[0]:-}"
    case "${record_type}" in
    cmd)
      command_name="${fields[1]:-}"
      alias_name="${fields[2]:-}"

      if [[ -n "${command_name}" ]]; then
        _MG_COMPLETION_COMMAND_WORDS+=("${command_name}")
      fi

      if [[ -n "${alias_name}" ]]; then
        _MG_COMPLETION_COMMAND_WORDS+=("${alias_name}")
        _MG_COMPLETION_ALIAS_TO_COMMAND["${alias_name}"]="${command_name}"
      fi
      ;;
    opts)
      command_name="${fields[1]:-}"
      value="${fields[2]:-}"
      if [[ -n "${command_name}" ]]; then
        _MG_COMPLETION_OPTIONS["${command_name}"]="${value}"
      fi
      ;;
    branch)
      command_name="${fields[1]:-}"
      position="${fields[2]:-}"
      scope="${fields[3]:-all}"
      if [[ -n "${command_name}" && -n "${position}" ]]; then
        _MG_COMPLETION_BRANCH_ARG_POSITION["${command_name}"]="${position}"
        _MG_COMPLETION_BRANCH_SCOPE["${command_name}"]="${scope}"
      fi
      ;;
    remote)
      command_name="${fields[1]:-}"
      position="${fields[2]:-}"
      if [[ -n "${command_name}" && -n "${position}" ]]; then
        _MG_COMPLETION_REMOTE_ARG_POSITION["${command_name}"]="${position}"
      fi
      ;;
    remote-branch)
      command_name="${fields[1]:-}"
      position="${fields[2]:-}"
      if [[ -n "${command_name}" && -n "${position}" ]]; then
        _MG_COMPLETION_REMOTE_BRANCH_ARG_POSITION["${command_name}"]="${position}"
      fi
      ;;
    value-opt)
      command_name="${fields[1]:-}"
      value="${fields[2]:-}"
      if [[ -n "${command_name}" && -n "${value}" ]]; then
        if [[ -n "${_MG_COMPLETION_VALUE_OPTIONS[${command_name}]:-}" ]]; then
          _MG_COMPLETION_VALUE_OPTIONS["${command_name}"]+=" ${value}"
        else
          _MG_COMPLETION_VALUE_OPTIONS["${command_name}"]="${value}"
        fi
      fi
      ;;
    esac
  done < <(bash "${script_path}" __complete-metadata)

  _MG_COMPLETION_COMMAND_WORDS+=("--help" "-h" "--short-help")
  _MG_COMPLETION_METADATA_LOADED=1
}

function _mg_complete_branch_names() {
  local line
  local branch_name

  {
    git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null

    git for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null |
      while IFS= read -r line; do
        if [[ "${line}" == */HEAD ]]; then
          continue
        fi

        if [[ "${line}" != */* ]]; then
          continue
        fi

        printf '%s\n' "${line}"

        branch_name="${line#*/}"
        if [[ -n "${branch_name}" ]]; then
          printf '%s\n' "${branch_name}"
        fi
      done
  } | sort -u
}

function _mg_complete_remote_branch_names() {
  local remote_name="${1}"

  if [[ -z "${remote_name}" ]]; then
    return
  fi

  git for-each-ref --format='%(refname:short)' "refs/remotes/${remote_name}" 2>/dev/null |
    while IFS= read -r line; do
      if [[ "${line}" == */HEAD ]]; then
        continue
      fi

      if [[ "${line}" == "${remote_name}/"* ]]; then
        printf '%s\n' "${line#"${remote_name}"/}"
      fi
    done | sort -u
}

function _mg_completion_resolve_alias() {
  local subcommand="${1}"

  if [[ -n "${_MG_COMPLETION_ALIAS_TO_COMMAND[${subcommand}]:-}" ]]; then
    printf '%s\n' "${_MG_COMPLETION_ALIAS_TO_COMMAND[${subcommand}]}"
    return
  fi

  printf '%s\n' "${subcommand}"
}

function _mg_completion_is_value_option() {
  local command_name="${1}"
  local option_name="${2}"
  local option_words="${_MG_COMPLETION_VALUE_OPTIONS[${command_name}]:-}"
  local option

  for option in ${option_words}; do
    if [[ "${option}" == "${option_name}" ]]; then
      return 0
    fi
  done

  return 1
}

function _mg_completion_positional_arg_index() {
  local command_name="${1}"
  local index=2
  local positional_index=0
  local skip_next=0
  local token

  while [[ ${index} -lt ${COMP_CWORD} ]]; do
    token="${COMP_WORDS[${index}]}"

    if [[ ${skip_next} -eq 1 ]]; then
      skip_next=0
      index=$(( index + 1 ))
      continue
    fi

    if [[ "${token}" == --* ]]; then
      if _mg_completion_is_value_option "${command_name}" "${token}"; then
        skip_next=1
      fi
      index=$(( index + 1 ))
      continue
    fi

    positional_index=$(( positional_index + 1 ))
    index=$(( index + 1 ))
  done

  if [[ "${COMP_WORDS[COMP_CWORD]}" == --* ]]; then
    printf '%s\n' "-1"
    return
  fi

  printf '%s\n' "$(( positional_index + 1 ))"
}

function _mg_dedupe_compreply() {
  local -A seen=()
  local -a unique=()
  local candidate

  for candidate in "${COMPREPLY[@]}"; do
    if [[ -n "${seen[${candidate}]:-}" ]]; then
      continue
    fi

    seen["${candidate}"]=1
    unique+=("${candidate}")
  done

  COMPREPLY=("${unique[@]}")
}

function _mg_complete_words() {
  local word_list="${1}"
  local cur_word="${2}"

  mapfile -t COMPREPLY < <(compgen -W "${word_list}" -- "${cur_word}")
}

function _mg_complete() {
  local cur_word="${COMP_WORDS[COMP_CWORD]}"
  local prev_word=""
  local raw_subcommand=""
  local command_name=""
  local option_csv=""
  local option_words=""
  local positional_index=0
  local branch_position=0
  local remote_position=0
  local remote_branch_position=0
  local remote_name=""
  local remote_arg_word_index=0

  COMPREPLY=()
  compopt +o default +o bashdefault 2>/dev/null || true

  _mg_completion_load_metadata || return 0

  if [[ ${COMP_CWORD} -gt 0 ]]; then
    prev_word="${COMP_WORDS[COMP_CWORD - 1]}"
  fi

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    _mg_complete_words "${_MG_COMPLETION_COMMAND_WORDS[*]}" "${cur_word}"
    _mg_dedupe_compreply
    return
  fi

  raw_subcommand="${COMP_WORDS[1]:-}"
  command_name="$(_mg_completion_resolve_alias "${raw_subcommand}")"

  if [[ "${command_name}" == "help" ]]; then
    _mg_complete_words '--short --short-help -h' "${cur_word}"
    _mg_dedupe_compreply
    return
  fi

  option_csv="${_MG_COMPLETION_OPTIONS[${command_name}]:-}"
  option_words="$(_mg_completion_split_csv "${option_csv}")"

  if _mg_completion_is_value_option "${command_name}" "${prev_word}"; then
    if [[ "${command_name}" == "clone" && "${prev_word}" == "--host" ]]; then
      _mg_complete_words "$(git remote 2>/dev/null)" "${cur_word}"
    elif [[ "${command_name}" == "new-branch" && "${prev_word}" == "--from" ]]; then
      _mg_complete_words "$(_mg_complete_branch_names)" "${cur_word}"
    fi
    _mg_dedupe_compreply
    return
  fi

  if [[ "${cur_word}" == --* && -n "${option_words}" ]]; then
    _mg_complete_words "${option_words}" "${cur_word}"
    _mg_dedupe_compreply
    return
  fi

  positional_index="$(_mg_completion_positional_arg_index "${command_name}")"

  remote_position="${_MG_COMPLETION_REMOTE_ARG_POSITION[${command_name}]:-0}"
  if [[ ${remote_position} -gt 0 && ${positional_index} -eq ${remote_position} ]]; then
    _mg_complete_words "$(git remote 2>/dev/null)" "${cur_word}"
    _mg_dedupe_compreply
    return
  fi

  remote_branch_position="${_MG_COMPLETION_REMOTE_BRANCH_ARG_POSITION[${command_name}]:-0}"
  if [[ ${remote_branch_position} -gt 0 && ${positional_index} -eq ${remote_branch_position} ]]; then
    remote_arg_word_index=$(( 1 + remote_position ))
    remote_name="${COMP_WORDS[${remote_arg_word_index}]:-}"
    _mg_complete_words "$(_mg_complete_remote_branch_names "${remote_name}")" "${cur_word}"
    _mg_dedupe_compreply
    return
  fi

  branch_position="${_MG_COMPLETION_BRANCH_ARG_POSITION[${command_name}]:-0}"
  if [[ ${branch_position} -gt 0 && ${positional_index} -eq ${branch_position} ]]; then
    _mg_complete_words "$(_mg_complete_branch_names)" "${cur_word}"
    _mg_dedupe_compreply
    return
  fi

  if [[ -n "${option_words}" ]]; then
    _mg_complete_words "${option_words}" "${cur_word}"
    _mg_dedupe_compreply
  fi
}

complete -r mg 2>/dev/null || true
complete -F _mg_complete mg
