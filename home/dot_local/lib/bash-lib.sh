# vim: set filetype=sh : */

if [[ -n "${MG_INCLUDE_GUARD_BASH_LIB_LOADED:-}" ]]; then
  return 0
fi

function lib_is_blank() {
  [[ -z "${1//[[:space:]]/}" ]]
}

function lib_has_substring() {
  local haystack="${1}"
  local needle="${2}"

  [[ "${haystack}" == *"${needle}"* ]]
}

function lib_has_suffix() {
  local value="${1}"
  local suffix="${2}"

  [[ "${value}" == *"${suffix}" ]]
}

function lib_has_prefix() {
  local value="${1}"
  local prefix="${2}"

  [[ "${value}" == "${prefix}"* ]]
}

function lib_strip_suffix() {
  local value="${1}"
  local suffix="${2}"

  if lib_has_suffix "${value}" "${suffix}"; then
    printf '%s\n' "${value%"${suffix}"}"
    return
  fi

  printf '%s\n' "${value}"
}

function lib_strip_prefix() {
  local value="${1}"
  local prefix="${2}"

  if lib_has_prefix "${value}" "${prefix}"; then
    printf '%s\n' "${value#"${prefix}"}"
    return
  fi

  printf '%s\n' "${value}"
}

function lib_before_first() {
  local value="${1}"
  local delimiter="${2}"

  printf '%s\n' "${value%%"${delimiter}"*}"
}

function lib_after_first() {
  local value="${1}"
  local delimiter="${2}"

  printf '%s\n' "${value#*"${delimiter}"}"
}

function lib_after_last() {
  local value="${1}"
  local delimiter="${2}"

  printf '%s\n' "${value##*"${delimiter}"}"
}

function lib_has_path_separator() {
  lib_has_substring "${1}" "/"
}

function lib_is_absolute_path() {
  [[ "${1}" == /* ]]
}

MG_INCLUDE_GUARD_BASH_LIB_LOADED=1
