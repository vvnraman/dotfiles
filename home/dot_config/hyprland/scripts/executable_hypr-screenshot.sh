#!/usr/bin/env bash
# vim: set ft=bash

set -o nounset
set -o pipefail

# shellcheck disable=SC2034,SC2155
{
  SCRIPT_DIR=$(dirname "$(readlink --canonicalize-existing "${0}" 2>/dev/null)")
  readonly SCRIPT="${0##*/}"
  readonly SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT}"
  readonly YEAR_MONTH="$(date +'%Y-%m')"
  readonly SCREENSHOT_DIR="${XDG_PICTURES_DIR:-${HOME}/Pictures}/screenshots/${YEAR_MONTH}"
  readonly MODES=("window" "monitor" "workspace" "region")                                         # default first
  readonly WINDOW_FORMATS=("ts_initial_title" "ts_only" "ts_title" "ts_initial_and_current_title") # default first
  readonly CLIPBOARD_OPTS=("yes" "no" "only" "only_no_annotation")                                 # default first
}

declare -A SCRIPT_ARGS
declare -A EXT_USAGE
SCRIPT_ARGS["h"]="help; Print this help and exit"
EXT_USAGE["h"]="
${SCRIPT} -h
  Print usage and exit

${SCRIPT} --help
  Print usage and exit
"
SCRIPT_ARGS["n"]="dry-run; Dry run only"
SCRIPT_ARGS["v"]="Produce verbose output"
SCRIPT_ARGS["m:"]="mode; [=${MODES[0]}]; Screenshot mode, defaults to the currently focused window"
EXT_USAGE["m:"]="
${SCRIPT} --mode=monitor
  Take a screenshot of the currently focused monitor screen

${SCRIPT} --mode=window
  Take a screenshot of the currently focused window (default)

${SCRIPT} --mode=region
  Let the user select a region on a monitor to take a screenshot of

Valid modes are ${MODES[*]}
"
SCRIPT_ARGS["f:"]="format; [=${WINDOW_FORMATS[0]}]; Format for the output file, timestmap and initial title by default"
EXT_USAGE["f:"]="
--format - Allowed formats are ${WINDOW_FORMATS[*]}
"
SCRIPT_ARGS["s:"]="format-string; [=string]; Format string for more control over the file name. Not all format strings will be available in each mode."
# Add unique negative numbers for arguments which don't use a short flag
SCRIPT_ARGS["c:"]="clipboard; [=${CLIPBOARD_OPTS[0]}]; Clipboard options"
EXT_USAGE["c:"]="
${SCRIPT} --cliboard=no
  Don't copy the screenshot to clipboard

${SCRIPT} --cliboard=only
  Only keep the screenshot to clipboard, don't save to file.
"
readonly SCRIPT_ARGS
readonly EXT_USAGE

#################
# LIBRARY BEGIN #
#################

# shellcheck disable=SC2034
{
  readonly A="══"
  readonly B="──"
  readonly C="┄┄"
  readonly S=" "
  readonly E=" "
  readonly NL="
"

  declare -A OPTIONS
  OPTIONS["dry_run"]=0
  OPTIONS["verbose"]=0
}

# STRINGS

function strip_trailing_colon() {
  printf '%s' "${1%%:}"
}

function strip_trailing_double_colon() {
  printf '%s' "${1%%::}"
}

function trim_leading_ws() {
  printf '%s' "${1#"${1%%[![:space:]]*}"}"
}

function trim_leading_trailing_ws() {
  : "${1#"${1%%[![:space:]]*}"}"
  : "${_%"${_##*[![:space:]]}"}"
  printf '%s' "$_"
}

function sanitize_string() {
  local str="${1}"
  str="$(trim_leading_trailing_ws "${str}")" # trim whitespace
  str="${str//[[:space:]]/_}"                # replace space with underscore
  str="${str//[^[:alnum:]._-]/}"             # only dots, letters, numbers, underscore, hyphen
  printf '%s' "${str}"
}

# UTILITY

function expand_tilde() {
  if [[ ! "${HOME-}" ]]; then
    # We want to abort here actually
    true
  fi
  printf '%s' "${1/#~/${HOME}}"
}

function check_cmd() {
  local -r tool="${1}"
  if ! command -v "${tool}" >/dev/null 2>&1; then
    log_e "'${tool}' is missing from the system"
    return 1
  else
    log_c "'${tool}' is available"
    return 0
  fi
}

function element_in_array() {
  local needle="$1"
  shift
  local haystack=("$@")

  for item in "${haystack[@]}"; do
    [[ "${needle}" == "${item}" ]] && return 0
  done
  return 1
}

function log() {
  if ! ((OPTIONS["verbose"])); then
    return 0
  fi
  echo "${@}" >&1
}

function log_a() {
  echo "${A}" "${@}" >&1
}

function log_b() {
  log "${B}" "${@}"
}

function log_c() {
  log "${C}" "${@}"
}

function log_s() {
  echo "${S}" "${@}" >&1
}

function log_e() {
  echo "${E}" "${@}" >&2
}

###############
# LIBRARY END #
###############

declare HELP_EXPANDED_STR=""
declare EXT_USAGE_STR=""
declare QUICK_HELP_ARGS_STR=""
declare SHORT_FLAGS=""
declare LONG_FLAGS=""
function construct_help_str_and_flags() {
  local long_sep=","
  local long_count=0
  for key in "${!SCRIPT_ARGS[@]}"; do

    long_sep=","
    if [[ ${long_count} -eq 0 ]]; then
      long_sep=""
    fi

    local value="${SCRIPT_ARGS[${key}]}"
    declare -a values
    # size 1, 2 or 3
    IFS=';' read -r -a values <<<"${value}"

    local long_flag_suffix=""
    local short_flag_str=""
    local short_quick_help
    local help_args_str

    if [[ $key == -* ]]; then
      # leading '-' indicates no short flag

      short_flag_str="  "
      short_quick_help=""
      help_args_str="   "

    else

      # append to '--options' flag for 'getopt'
      SHORT_FLAGS+="${key}"

      if [[ $key == *:: ]]; then
        short_flag_str="-$(strip_trailing_double_colon "${key}")"
        long_flag_suffix="::"
      elif [[ $key == *: ]]; then
        short_flag_str="-$(strip_trailing_colon "${key}")"
        long_flag_suffix=":"
      else
        short_flag_str="-${key}"
      fi
      short_quick_help="${short_flag_str}/"
      help_args_str="${short_flag_str},"

    fi

    local long_flag_str=""
    local opt_arg=""
    local help_text=""

    if [[ ${#values[@]} -eq 1 ]]; then
      # Size 1 means we have no long flag

      help_text="$(trim_leading_ws "${values[*]}")"

      if [[ "${short_flag_str}" == "" ]]; then
        log_e "No short and long flag for ${help_text}"
        exit 1
      fi

      QUICK_HELP_ARGS_STR+="${short_quick_help} "

    elif [[ ${#values[@]} -eq 2 ]]; then
      # Size 2 means we have a long flag, but no argument

      # append optional ',' and the short flag to show in help args
      long_flag_str="--${values[0]}"
      help_text="$(trim_leading_ws "${values[*]:1}")"
      QUICK_HELP_ARGS_STR+="${short_quick_help}${long_flag_str} "
      LONG_FLAGS+="${long_sep}${values[0]}${long_flag_suffix}"
      help_args_str+=" ${long_flag_str}"
      long_count=$((long_count + 1))

    else
      # size 3 (or more) means we have a along flag and an (optional) argument

      opt_arg="$(trim_leading_ws "${values[1]}")"
      long_flag_str="--${values[0]}${opt_arg}"
      help_text="$(trim_leading_ws "${values[*]:2}")"
      QUICK_HELP_ARGS_STR+="${short_quick_help}${long_flag_str} "
      LONG_FLAGS+="${long_sep}${values[0]}${long_flag_suffix}"
      help_args_str+=" ${long_flag_str}"
      long_count=$((long_count + 1))

    fi

    HELP_EXPANDED_STR+="  ${help_args_str}${NL}        ${help_text}${NL}"
  done

  for ex in "${!EXT_USAGE[@]}"; do
    EXT_USAGE_STR+="${EXT_USAGE[${ex}]}"
  done
}
construct_help_str_and_flags
readonly HELP_EXPANDED_STR
readonly EXT_USAGE_STR

function usage() {

  cat <<USAGE_EOF
Usage:
    ${SCRIPT} ${QUICK_HELP_ARGS_STR}

Description:
    A script to take screenshots in hyprland setups.

Options:
${HELP_EXPANDED_STR}
Extended Usage:
${EXT_USAGE_STR}
USAGE_EOF
}

function main() {
  local -r args=("${@}")

  local opts
  opts=$(getopt \
    --options "${SHORT_FLAGS}" \
    --longoptions "${LONG_FLAGS}" \
    -- "${args[@]}")

  if [[ $? -ne 0 ]]; then
    log_e "failed to parse some arguments, run with '--help' to see usage." >&2
    exit 1
  fi

  eval set -- "${opts}"

  local mode="${MODES[0]}"
  local format="${WINDOW_FORMATS[0]}"
  local clipboard="${CLIPBOARD_OPTS[0]}"
  while true; do
    case "${1}" in
    -m | --mode)
      mode="${2}"
      shift 2
      ;;
    -c | --clipboard)
      clipboard="${2}"
      shift 2
      ;;
    -f | --format)
      format="${2}"
      shift 2
      ;;
    -v)
      OPTIONS["verbose"]=1
      shift
      ;;
    -n | --dry-run)
      OPTIONS["dry_run"]=1
      shift
      ;;
    -h | --help)
      local -r help_arg=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
    esac
  done

  if ((OPTIONS["dry_run"])); then
    log_b "Dry run output wanted"
  fi

  if ((OPTIONS["verbose"])); then
    log_b "Verbose output wanted"
  fi

  log_b "Remaining args = ${*}"

  if [[ ${help_arg-} ]]; then
    usage
    exit
  fi

  do_checks "${mode}" "${format}" "${clipboard}"
  do_screenshot "${mode}" "${format}" "${clipboard}"
}

##################
# IMPLEMENTATION #
##################

function freeze_screen() {
  hyprpicker --no-zoom --render-inactive &
  sleep 0.2
}

function thaw_screen() {
  pidof -q hyprpicker && pkill hyprpicker
}

function cleanup() {
  trap - EXIT
  thaw_screen
}

function read_json_field_sanitized() {
  local input="${1}"
  local field="${2}"
  local value
  read -r value < <(jq --raw-output ".${field}" <<<"${input}")
  printf "%s" "$(sanitize_string "${value}")"
}

function check_prerequisites() {
  local tools
  declare -a tools=("hyprctl" "jq" "hyprpicker" "grim" "satty" "slurp" "wl-copy")
  local num_tools=${#tools[@]}
  local fail=0
  for tool in "${tools[@]}"; do
    if ! check_cmd "${tool}"; then
      fail=$((fail + 1))
    fi
  done
  if [[ ${fail} -gt 0 ]]; then
    log_e "${fail}/${num_tools} necessary tools missing for taking a screehshot."
    return 1
  fi
  log "${C} All ${num_tools} necessary tools are available"
  return 0
}

function do_checks() {
  local mode="${1}"
  local format="${2}"
  local clipboard="${3}"

  local -i failed_checks=0

  check_prerequisites || ((failed_checks++))

  if ! element_in_array "${mode}" "${MODES[@]}"; then
    ((failed_checks++))
    log_e "'${mode}' is not valid value for '--mode', provide 1 of ${MODES[*]}"
  fi

  if ! element_in_array "${format}" "${WINDOW_FORMATS[@]}"; then
    ((failed_checks++))
    log_e "'${format}' is not valid value for '--format', provide 1 of ${WINDOW_FORMATS[*]}"
  fi

  if ! element_in_array "${clipboard}" "${CLIPBOARD_OPTS[@]}"; then
    ((failed_checks++))
    log_e "'${clipboard}' is not valid value for '--clipboard', provide 1 of ${CLIPBOARD_OPTS[*]}"
  fi

  if [[ $failed_checks -ne 0 ]]; then
    log_e "Failed ${failed_checks} necessary check to continue"
    exit 1
  fi
}

function timestamp() {
  local -r time_stamp="$(date +'%Y%m%d_%H%M%S')"
  printf "%s" "${time_stamp}"
}

function window_file_name() {
  local format="${1}"
  local hypr_active_window_json="${2}"

  local filename="$(timestamp)"
  local field_values=""
  case "${format}" in
  ts_initial_title)
    field_values+="_$(read_json_field_sanitized "${hypr_active_window_json}" "initialTitle")"
    ;;
  ts_title)
    field_values+="_$(read_json_field_sanitized "${hypr_active_window_json}" "title")"
    ;;
  ts_initial_and_current_title)
    field_values+="_$(read_json_field_sanitized "${hypr_active_window_json}" "initialTitle")"
    field_values+="_$(read_json_field_sanitized "${hypr_active_window_json}" "title")"
    ;;
  esac
  filename+="${field_values}"
  printf "%s" "${filename}"
}

function do_screenshot() {
  local mode="${1}"
  local format="${2}"
  local clipboard="${3}"

  log_b "Taking screenshot using mode='${mode}'"

  case "${mode}" in
  window)
    do_window "${format}" "${clipboard}"
    ;;
  workspace)
    do_workspace "${format}" "${clipboard}"
    ;;
  monitor)
    do_monitor "${format}" "${clipboard}"
    ;;
  region)
    do_region "${format}" "${clipboard}"
    ;;
  *)
    log_c "Invalid mode '${mode}'"
    exit 1
    ;;
  esac
}

function take_screenshot_from_geometry() {
  local clipboard="${1}"
  local filename="${2}"
  local geometry="${3}"
  local file_path="${SCREENSHOT_DIR}/screenshot_${filename}.png"
  log_c "filepath = '${file_path}'"
  if ! ((OPTIONS["dry_run"])); then
    case "${clipboard}" in
    yes)
      mkdir -p "${SCREENSHOT_DIR}"
      grim -g "${geometry}" -t ppm - | satty --filename - \
        --output-filename "${file_path}" \
        --early-exit \
        --actions-on-enter save-to-clipboard \
        --save-after-copy
      ;;
    no)
      mkdir -p "${SCREENSHOT_DIR}"
      grim -g "${geometry}" -t ppm - | satty --filename - \
        --output-filename "${file_path}" \
        --early-exit
      ;;
    only)
      grim -g "${geometry}" -t ppm - | satty --filename - \
        --actions-on-enter save-to-clipboard \
        --early-exit
      ;;
    only_no_annotation)
      grim -g "${geometry}" - | wl-copy
      ;;
    *)
      log_e "Invalid clipboard options '${clipboard}'"
      exit 1
      ;;
    esac
  fi
}

function do_window() {
  local format="${1}"
  local clipboard="${2}"

  local -r hypr_active_window_json="$(hyprctl activewindow -j)"

  local x y width height
  read -r x y width height < <(
    jq --raw-output '
    "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"
    ' <<<"${hypr_active_window_json}"
  )
  readonly x y width height

  local -r geometry="${x},${y} ${width}x${height}"
  log_c "Active window geometry= '${geometry}'"

  local filename
  filename="$(window_file_name "${format}" "${hypr_active_window_json}")"

  take_screenshot_from_geometry "${clipboard}" "${filename}" "${geometry}"
}

function do_workspace() {
  local format="${1}"
  local clipboard="${2}"

  local -r active_ws="$(hyprctl activeworkspace -j | jq --raw-output '.id')"
  local x y width height
  read -r x y width height < <(
    hyprctl monitors -j |
      jq --raw-output --arg ws "$active_ws" '
    .[]
    | select(.activeWorkspace.id == ($ws | tonumber))
    | " \(.x) \(.y) \((.width / .scale) | floor) \((.height / .scale) | floor)"'
  )
  readonly x y width height

  local -r geometry="${x},${y} ${width}x${height}"
  log "${C} Active workpsace geometry = '${geometry}'"

  local filename
  filename="$(timestamp)_workspace_${active_ws}_${width}x${height}"

  take_screenshot_from_geometry "${clipboard}" "${filename}" "${geometry}"
}

function do_monitor() {
  local format="${1}"
  local clipboard="${2}"

  local -r active_monitor_json="$(hyprctl monitors -j | jq --raw-output '.[] | select(.focused == true)')"
  local x y width height
  read -r x y width height < <(
    jq --raw-output '
    "\(.x) \(.y) \((.width / .scale) | floor) \((.height / .scale) | floor)"
    ' <<<"${active_monitor_json}"
  )
  readonly x y width height

  local -r geometry="${x},${y} ${width}x${height}"
  log "${C} Active monitor geometry = '${geometry}'"

  local name
  name="$(read_json_field_sanitized "${active_monitor_json}" "name")"

  local filename
  filename="$(timestamp)_monitor_${name}_${width}x${height}"

  take_screenshot_from_geometry "${clipboard}" "${filename}" "${geometry}"
}

function do_region() {
  local format="${1}"
  local clipboard="${2}"

  local x y width height
  freeze_screen
  read -r x y width height < <(slurp -f "%x %y %w %h" 2>/dev/null)
  readonly x y width height
  thaw_screen

  local -r geometry="${x},${y} ${width}x${height}"
  log "${C} Selected region geometry = '${geometry}'"

  local filename
  filename="$(timestamp)_region_${x}_${y}_${width}x${height}"

  take_screenshot_from_geometry "${clipboard}" "${filename}" "${geometry}"
}

trap cleanup EXIT
main "${@}"
# created by copying /home/vvnraman/.local/bin/bash-template on 20260103_175231
