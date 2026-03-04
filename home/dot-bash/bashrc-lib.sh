function source_script() {
  local _script_path="${1}"
  # shellcheck disable=SC1090
  [[ -f "${_script_path}" ]] && source "${_script_path}"
}

function prepend_to_path() {
  local dir="${1}"
  if [[ ":${PATH}:" != *":${dir}:"* ]] && [[ -d "${dir}" ]]; then
    PATH="${dir}:${PATH}"
  fi
}

function append_to_path() {
  local dir="${1}"
  if [[ ":${PATH}:" != *":${dir}:"* ]] && [[ -d "${dir}" ]]; then
    PATH="${PATH}:${dir}"
  fi
}

function is_wsl2() {
  local kernel
  kernel="$(uname -r)"
  readonly kernel

  if [[ "${kernel}" == *microsoft-standard-WSL2* ]]; then
    return 0
  fi
  return 1
}
