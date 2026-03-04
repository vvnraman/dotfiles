if ! command -v fzf 1>/dev/null 2>&1; then
  return
fi

readonly fzf_generated_fragments_path="${HOME}/dot-bash/generated/fzf-fragments.sh"
if [[ ! -f "${fzf_generated_fragments_path}" ]]; then
  return
fi

# shellcheck source=/home/vvnraman/dot-bash/generated/fzf-fragments.sh
. "${fzf_generated_fragments_path}"

fzf_selected_preview_file="${fzf_preview_file_cat}"
fzf_default_prompt_opt=""
fzf_ctrl_t_prompt_opt=""
fzf_ctrl_t_bind_switch=""
fzf_ctrl_t_preview="${fzf_selected_preview_file}"
fzf_shell_exec_opts="--with-shell 'bash -c'"

if command -v fd 1>/dev/null 2>&1 && command -v bat 1>/dev/null 2>&1; then
  fzf_selected_preview_file="${fzf_preview_file_bat}"
  fzf_selected_files_command="fd --type file ${fzf_fd_opts}"
  fzf_selected_dirs_command="fd --type directory ${fzf_fd_opts}"

  export FZF_DEFAULT_COMMAND="${fzf_selected_files_command}"
  export FZF_CTRL_T_COMMAND="${fzf_selected_files_command}"
  export FZF_ALT_C_COMMAND="${fzf_selected_dirs_command}"

  fzf_default_prompt_opt="--prompt '${fzf_prompt_files}'"
  fzf_ctrl_t_prompt_opt="--prompt '${fzf_prompt_files}'"
  fzf_toggle_to_files="\
change-prompt(${fzf_prompt_files})\
+reload(${fzf_selected_files_command})"
  fzf_toggle_to_dirs="\
change-prompt(${fzf_prompt_dirs})\
+reload(${fzf_selected_dirs_command})"
  fzf_toggle_prompt="\
[[ ! \$FZF_PROMPT =~ Files ]] && \
echo \"${fzf_toggle_to_files}\" || \
echo \"${fzf_toggle_to_dirs}\""
  fzf_toggle_preview="\
[[ \$FZF_PROMPT =~ Files ]] && \
${fzf_selected_preview_file} || \
${fzf_preview_tree}"
  fzf_ctrl_t_bind_switch="--bind 'ctrl-t:transform:${fzf_toggle_prompt}'"
  fzf_ctrl_t_preview="${fzf_toggle_preview}"

  _fzf_compgen_path() {
    fd ${fzf_fd_opts} . "$1"
  }

  _fzf_compgen_dir() {
    ${fzf_selected_dirs_command} . "$1"
  }
fi

export FZF_CTRL_R_OPTS="\
${fzf_shell_exec_opts} \
--header '${fzf_ctrl_r_header}' \
--preview '${fzf_ctrl_r_preview}' \
--preview-window ${fzf_ctrl_r_preview_window} \
--bind 'ctrl-/:toggle-preview' \
--bind '${fzf_ctrl_r_copy_bind}' \
--color ${fzf_ctrl_r_color}"

export FZF_DEFAULT_OPTS="\
${fzf_shell_exec_opts} \
${fzf_basic_opts} \
${fzf_default_prompt_opt} \
--header '${fzf_header_default}' \
--preview-window '${fzf_preview_window}' \
--preview '${fzf_selected_preview_file}' \
--bind '${fzf_bind_change_preview}' \
--bind '${fzf_bind_open_nvim}'"

export FZF_CTRL_T_OPTS="\
${fzf_shell_exec_opts} \
${fzf_basic_opts} \
${fzf_ctrl_t_prompt_opt} \
--header '${fzf_header_ctrl_t}' \
--preview-window '${fzf_preview_window}' \
--preview '${fzf_ctrl_t_preview}' \
--bind '${fzf_bind_change_preview}' \
${fzf_ctrl_t_bind_switch}"

export FZF_ALT_C_OPTS="\
${fzf_shell_exec_opts} \
--preview '${fzf_preview_tree}'"

export FZF_RG_PREFIX="${fzf_rg_prefix}"
export FZF_RG_PROMPT_RIPGREP="${fzf_rg_prompt_ripgrep}"
export FZF_RG_PROMPT_FZF="${fzf_rg_prompt_fzf}"
export FZF_RG_HEADER_TOGGLE="${fzf_rg_header_toggle}"
export FZF_RG_COLOR="${fzf_rg_color}"
export FZF_RG_PREVIEW_WINDOW="${fzf_rg_preview_window}"
export FZF_RG_PREVIEW="${fzf_rg_preview_fallback}"
export FZF_RG_RELOAD_DEBOUNCE="${fzf_rg_reload_debounce}"

if command -v bat 1>/dev/null 2>&1; then
  export FZF_RG_PREVIEW="${fzf_rg_preview_bat}"
fi

if command -v rg 1>/dev/null 2>&1; then
  frg() {
    local rg_query_file
    local fzf_query_file
    local initial_query
    local selected_editor
    local toggle_to_fzf_mode
    local toggle_to_ripgrep_mode
    local toggle_mode

    rg_query_file="$(mktemp -t rg-fzf-r.XXXXXX)"
    fzf_query_file="$(mktemp -t rg-fzf-f.XXXXXX)"
    initial_query="$*"
    selected_editor="${EDITOR:-nvim}"

    toggle_to_fzf_mode="\
unbind(change)\
+change-prompt(${FZF_RG_PROMPT_FZF})\
+enable-search\
+transform-query:echo \\{q} > ${rg_query_file}; cat ${fzf_query_file}"

    toggle_to_ripgrep_mode="\
rebind(change)\
+change-prompt(${FZF_RG_PROMPT_RIPGREP})\
+disable-search\
+transform-query:echo \\{q} > ${fzf_query_file}; cat ${rg_query_file}"

    toggle_mode="\
[[ ! \$FZF_PROMPT =~ ripgrep ]] && \
echo \"${toggle_to_ripgrep_mode}\" || \
echo \"${toggle_to_fzf_mode}\""

    fzf --with-shell 'bash -c' --ansi --disabled --query "${initial_query}" \
      --prompt "${FZF_RG_PROMPT_RIPGREP}" \
      --delimiter : \
      --header "${FZF_RG_HEADER_TOGGLE}" \
      --color "${FZF_RG_COLOR}" \
      --bind "start:reload:${FZF_RG_PREFIX} {q} || true" \
      --bind "change:reload:${FZF_RG_RELOAD_DEBOUNCE} ${FZF_RG_PREFIX} {q} || true" \
      --bind "ctrl-f:transform:${toggle_mode}" \
      --preview "${FZF_RG_PREVIEW}" \
      --preview-window "${FZF_RG_PREVIEW_WINDOW}" \
      --bind "enter:become(${selected_editor} {1} +{2})"

    rm --force "${rg_query_file}" "${fzf_query_file}"
  }

  __fzf_run_frg_keybind() {
    frg
  }
fi

#-------------------------------------------------------------------------------
eval "$(fzf --bash)"

if command -v rg 1>/dev/null 2>&1; then
  bind -m vi-insert -x '"\C-f":"__fzf_run_frg_keybind"'
  bind -m emacs-standard -x '"\C-f":"__fzf_run_frg_keybind"'
fi
