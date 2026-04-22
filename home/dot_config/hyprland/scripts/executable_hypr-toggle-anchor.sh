#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Toggle anchoring the active window (float + pin + tag).
#
# Usage:
#   hypr-toggle-anchor.sh [--debug]
#
# Behavior:
#   - If unpinned, floats the active window, resizes it to 50%x75% of the
#     current monitor, centers it, pins it, raises it, and tags it.
#   - If the active window is grouped, saves its workspace/group context,
#     removes it from the group, then pins it as a normal floating window.
#   - If already pinned, clears pin/float/tag state and restores any saved
#     workspace/group context before rejoining the tiled layout.
#   - With --debug, prints parsed state and the hyprctl commands without
#     changing Hyprland state or deleting saved pin metadata.

readonly PIN_WIDTH_PERCENT=50
readonly PIN_HEIGHT_PERCENT=75
readonly PIN_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/vvn/hyprland-pins"
readonly PIN_RUNTIME_PREFIX="hypr-toggle-anchor-"
readonly PIN_RUNTIME_PREFIX_LEGACY="hypr-toggle-pinned-"
readonly PIN_RUNTIME_EXT=".txt"

DEBUG=0

# Run hyprctl commands directly or print them in debug mode.
# This keeps all dispatcher execution behind one non-destructive switch.
run() {
  local -a cmd
  cmd=("$@")

  if [[ ${DEBUG} -eq 1 ]]; then
    local pretty
    printf -v pretty '%q ' "${cmd[@]}"
    printf 'DRYRUN: hyprctl %s\n' "${pretty% }"
    return 0
  fi

  hyprctl "${cmd[@]}"
}

# Build the runtime state file path for a pinned window address.
# The file stores workspace and grouping context across pin/unpin cycles.
pin_state_file_for() {
  local addr=$1
  local prefix=${2:-${PIN_RUNTIME_PREFIX}}

  printf '%s\n' "${PIN_RUNTIME_DIR}/${prefix}${addr}${PIN_RUNTIME_EXT}"
}

# Resolve the current runtime state path for a pinned window address.
# Legacy filenames are still accepted so existing anchored windows can unpin cleanly.
resolve_pin_state_file() {
  local addr=$1
  local state_file
  state_file=$(pin_state_file_for "${addr}")

  if [[ -f "${state_file}" ]]; then
    printf '%s\n' "${state_file}"
    return 0
  fi

  local legacy_state_file
  legacy_state_file=$(pin_state_file_for "${addr}" "${PIN_RUNTIME_PREFIX_LEGACY}")

  if [[ -f "${legacy_state_file}" ]]; then
    printf '%s\n' "${legacy_state_file}"
    return 0
  fi

  printf '%s\n' "${state_file}"
}

# Read the saved workspace and grouped payload for a pinned window.
# Returns two lines on stdout so callers can restore the prior context.
load_pin_state() {
  local addr=$1
  local state_file
  state_file=$(resolve_pin_state_file "${addr}")

  if [[ ! -f "${state_file}" ]]; then
    return 1
  fi

  local workspace=""
  local grouped=""

  while IFS='=' read -r key value; do
    case "${key}" in
    workspace)
      workspace=${value}
      ;;
    grouped)
      grouped=${value}
      ;;
    esac
  done <"${state_file}"

  if [[ -z "${workspace}" || -z "${grouped}" ]]; then
    return 1
  fi

  printf '%s\n%s\n' "${workspace}" "${grouped}"
}

# Check whether the currently focused window is the requested address and still
# reports grouped peers. This is used to verify regroup attempts.
is_window_grouped() {
  local addr=$1
  local current_addr
  local grouped_count

  read -r current_addr grouped_count < <(
    hyprctl activewindow -j | jq -r '[.address // empty, ((.grouped // []) | length)] | @tsv'
  )

  [[ "${current_addr}" == "${addr}" && ${grouped_count} -gt 0 ]]
}

# Remove saved runtime state after a real run, or retain it in debug mode.
# Keeping the file during dry runs makes grouped restore testing repeatable.
cleanup_pin_state_file() {
  local pin_state_file=$1

  if ((DEBUG == 0)); then
    rm -f "${pin_state_file}"
  else
    printf 'DRYRUN: keep pin state file %s\n' "${pin_state_file}"
  fi
}

# Clear the pinned window back to a normal tiled window state.
# This drops the pin flag, floating state, and pinned-float tag together.
clear_pinned_window_state() {
  local addr=$1

  run -q --batch \
    "dispatch pin address:${addr};" \
    "dispatch togglefloating address:${addr};" \
    "dispatch tagwindow -pinned-float address:${addr};"
}

# Move a window back to its saved workspace and restore focus to it.
# Unpin flows call this first so later regroup operations start from the right place.
restore_window_to_workspace() {
  local addr=$1
  local workspace=$2

  run dispatch movetoworkspace "${workspace},address:${addr}"
  run dispatch focuswindow "address:${addr}"
}

# Finish a normal unpin after workspace restoration is already done.
# This centralizes state clearing and runtime file cleanup for fallback paths.
finish_regular_unpin() {
  local addr=$1
  local pin_state_file=$2

  clear_pinned_window_state "${addr}"
  cleanup_pin_state_file "${pin_state_file}"
}

# Recreate a one-window group when the saved grouped context shrinks away.
# The window must be focused so togglegroup applies to the restored window.
finish_single_window_group() {
  local addr=$1
  local pin_state_file=$2

  clear_pinned_window_state "${addr}"
  run dispatch focuswindow "address:${addr}"
  run dispatch togglegroup
  cleanup_pin_state_file "${pin_state_file}"
}

# Restore a pinned window that no longer needs grouped reconstruction.
# This is the standard unpin path when no saved grouped peers remain.
unpin_regular_window() {
  local addr=$1
  local workspace=$2
  local pin_state_file=$3

  restore_window_to_workspace "${addr}" "${workspace}"
  finish_regular_unpin "${addr}" "${pin_state_file}"
}

# Try to reattach the restored window to a saved neighbor window.
# The caller computes a live direction so moveintogroup targets the intended group.
attempt_group_restore() {
  local addr=$1
  local group_target=$2
  local move_direction=$3

  run dispatch focuswindow "address:${group_target}"
  run dispatch focuswindow "address:${addr}"
  run dispatch moveintogroup "${move_direction}"
}

# Derive regroup directions from the live tiled positions of the restored window
# and its saved target. Returns directions plus both window centers for debug output.
compute_group_restore_directions() {
  local addr=$1
  local group_target=$2
  local move_direction=$3
  local fallback_move_direction=$4

  local addr_center_x
  local addr_center_y
  local target_center_x
  local target_center_y
  # 1. Read the full client list once from Hyprland.
  # 2. Keep only the restored window and its saved target window.
  # 3. Compute center coordinates for both windows and return them as TSV.
  # jq details:
  # - `map(select(...))` filters the client array down to the restored window
  #   and its saved target, then rebuilds each entry with computed center points.
  # - `(.at[0] + (.size[0] / 2)) | floor` means left x + half width = center x,
  #   rounded down to an integer. After the remap, the shape is roughly:
  #   {"addr":{"address":"0xA","cx":100,"cy":200},"target":{"address":"0xB","cx":500,"cy":220}}
  # - The final `[ ... ]` creates exactly four output fields. `// {}` and
  #   `// ""` provide empty fallbacks so shell `read` still gets a stable TSV
  #   line even when one of the windows cannot be resolved.
  read -r addr_center_x addr_center_y target_center_x target_center_y < <(
    hyprctl clients -j | jq -r --arg addr "${addr}" --arg target "${group_target}" '
    map(
      select(.address == $addr or .address == $target)
      | {
          address,
          cx: ((.at[0] + (.size[0] / 2)) | floor),
          cy: ((.at[1] + (.size[1] / 2)) | floor)
        }
    )
    | {
        addr: (map(select(.address == $addr)) | first // {}),
        target: (map(select(.address == $target)) | first // {})
      }
    | [(.addr.cx // ""), (.addr.cy // ""), (.target.cx // ""), (.target.cy // "")] | @tsv
    '
  )

  if [[ -n "${addr_center_x}" && -n "${addr_center_y}" && -n "${target_center_x}" && -n "${target_center_y}" ]]; then
    local delta_x=$((target_center_x - addr_center_x))
    local delta_y=$((target_center_y - addr_center_y))
    local abs_delta_x=${delta_x#-}
    local abs_delta_y=${delta_y#-}

    if ((abs_delta_x >= abs_delta_y)); then
      if ((delta_x >= 0)); then
        move_direction="r"
        fallback_move_direction="l"
      else
        move_direction="l"
        fallback_move_direction="r"
      fi
    else
      if ((delta_y >= 0)); then
        move_direction="d"
        fallback_move_direction="u"
      else
        move_direction="u"
        fallback_move_direction="d"
      fi
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${move_direction}" \
    "${fallback_move_direction}" \
    "${addr_center_x:-}" \
    "${addr_center_y:-}" \
    "${target_center_x:-}" \
    "${target_center_y:-}"
}

# Restore a previously grouped pinned window back into the tiled layout.
# This uses saved group order to pick a target group member, then uses live
# window geometry after retiling to choose the regroup direction.
unpin_grouped_window() {
  local addr=$1
  local workspace=$2
  local pin_state_file=$3
  local grouped_members_name=$4
  local -n grouped_members_ref=${grouped_members_name}

  restore_window_to_workspace "${addr}" "${workspace}"

  local grouped_count=${#grouped_members_ref[@]}

  # A single saved grouped member means we only need to restore the unpinned
  # window as a one-window group again, without any neighbor-based regrouping.
  if ((grouped_count == 1)); then
    finish_single_window_group "${addr}" "${pin_state_file}"
    return 0
  fi

  # Find the pinned window's original position inside the saved grouped member
  # list. The stored order is later used to pick a neighbor window as the
  # anchor for regrouping.
  local group_index=-1
  local i
  for i in "${!grouped_members_ref[@]}"; do
    if [[ ${grouped_members_ref[i]} == "${addr}" ]]; then
      group_index=${i}
      break
    fi
  done

  # If the saved address is no longer present, the prior group topology has
  # drifted too far to reconstruct confidently. Fall back to a normal unpin.
  if ((group_index < 0)); then
    finish_regular_unpin "${addr}" "${pin_state_file}"
    return 0
  fi

  # Use the saved index to choose the nearest surviving neighbor as the anchor
  # window. The saved order only selects the target window; the live regroup
  # direction is computed later from the tiled positions on the workspace.
  local anchor_index=-1
  local move_direction="l"
  local fallback_move_direction="r"

  if ((group_index > 0)); then
    anchor_index=$((group_index - 1))
    move_direction="r"
    fallback_move_direction="l"
  else
    anchor_index=$((group_index + 1))
  fi

  # Resolve the saved neighbor window we will regroup against. If there is no
  # usable target, we can still safely restore the window as a normal unpinned
  # tiled window.
  local group_target="${grouped_members_ref[anchor_index]}"

  if [[ -z "${group_target}" ]]; then
    finish_regular_unpin "${addr}" "${pin_state_file}"
    return 0
  fi

  # First clear the pinned/floating state so the window can participate in the
  # tiled tree again. Once Hyprland gives it a real tiled position, derive the
  # moveintogroup direction from the live geometry instead of saved tab order.
  clear_pinned_window_state "${addr}"

  local addr_center_x
  local addr_center_y
  local target_center_x
  local target_center_y
  read -r move_direction fallback_move_direction addr_center_x addr_center_y target_center_x target_center_y < <(
    compute_group_restore_directions "${addr}" "${group_target}" "${move_direction}" "${fallback_move_direction}"
  )

  if [[ ${DEBUG} -eq 1 ]]; then
    printf 'restore group: size=%d index=%d target=%s movein=%s fallback_movein=%s addr_center=%s,%s target_center=%s,%s\n' \
      "${grouped_count}" \
      "${group_index}" \
      "${group_target}" \
      "${move_direction}" \
      "${fallback_move_direction}" \
      "${addr_center_x:-?}" \
      "${addr_center_y:-?}" \
      "${target_center_x:-?}" \
      "${target_center_y:-?}"
  fi

  attempt_group_restore "${addr}" "${group_target}" "${move_direction}"

  if ! is_window_grouped "${addr}"; then
    attempt_group_restore "${addr}" "${group_target}" "${fallback_move_direction}"
  fi

  cleanup_pin_state_file "${pin_state_file}"
}

# Print the parsed activewindow fields used by main.
# Debug mode calls this before any pin or unpin logic runs.
print_debug_fields() {
  printf 'activewindow: pinned=%s\n' "${pinned}"
  printf 'activewindow: addr=%s\n' "${addr}"
  printf 'activewindow: monitor=%s\n' "${monitor_id}"
  printf 'activewindow: workspace=%s\n' "${workspace}"
  printf 'activewindow: grouped=%s\n' "${grouped}"
  printf 'activewindow: is_grouped=%s\n' "${is_grouped}"
}

# Persist the current workspace and grouped payload before pinning.
# Debug mode reports the file path but intentionally skips writing it.
write_pin_state() {
  local addr=$1
  local workspace=$2
  local grouped=$3

  local pin_state_file
  pin_state_file=$(pin_state_file_for "${addr}")

  if ((DEBUG == 1)); then
    printf 'DRYRUN: would write %s\n' "${pin_state_file}"
    return 0
  fi

  mkdir -p "${PIN_RUNTIME_DIR}"
  printf 'workspace=%s\ngrouped=%s\n' "${workspace}" "${grouped}" >"${pin_state_file}"
}

# Orchestrate unpin behavior from either plain pinned state or saved context.
# If grouped metadata exists, dispatch to the grouped restore path; otherwise use regular unpin.
unpin_window() {
  local addr=$1

  local pin_state_file
  pin_state_file=$(resolve_pin_state_file "${addr}")

  if [[ ! -f "${pin_state_file}" ]]; then
    clear_pinned_window_state "${addr}"
    return 0
  fi

  local pin_workspace
  local pin_grouped
  if ! {
    read -r pin_workspace
    read -r pin_grouped
  } < <(load_pin_state "${addr}"); then
    cleanup_pin_state_file "${pin_state_file}"
    clear_pinned_window_state "${addr}"
    return 0
  fi

  local -a grouped_members=()
  mapfile -t grouped_members < <(jq -r '.[]' <<<"${pin_grouped}" 2>/dev/null || true)

  if ((${#grouped_members[@]} == 0)); then
    unpin_regular_window "${addr}" "${pin_workspace}" "${pin_state_file}"
    return 0
  fi

  unpin_grouped_window "${addr}" "${pin_workspace}" "${pin_state_file}" grouped_members
}

# Orchestrate pin behavior by saving state and calculating monitor-relative size.
# Grouped windows are detached first, while regular windows go straight to pinning.
pin_window() {
  local addr=$1
  local workspace=$2
  local grouped=$3
  local monitor_id=$4
  local is_grouped=$5

  write_pin_state "${addr}" "${workspace}" "${grouped}"

  local monitor
  monitor=$(hyprctl monitors -j | jq ".[] | select(.id == ${monitor_id})")

  local mon_w mon_h
  read -r mon_w mon_h < <(
    jq --raw-output '
    "\((.width / .scale) | floor) \((.height / .scale) | floor)"
    ' <<<"${monitor}"
  )

  local width=$((mon_w * PIN_WIDTH_PERCENT / 100))
  local height=$((mon_h * PIN_HEIGHT_PERCENT / 100))

  if [[ "${is_grouped}" == "0" ]]; then
    pin_regular_window "${workspace}" "${addr}" "${width}" "${height}"
  else
    pin_grouped_window "${workspace}" "${addr}" "${width}" "${height}"
  fi
}

# Apply the normal floating pin workflow to a single window.
# This toggles floating, sizes and centers the window, then pins and tags it.
pin_regular_window() {
  local workspace=$1
  local addr=$2
  local width=$3
  local height=$4

  run dispatch togglefloating "address:${addr}"
  run dispatch resizeactive exact "${width}" "${height}"
  run dispatch centerwindow

  run -q --batch \
    "dispatch pin address:${addr};" \
    "dispatch tagwindow +pinned-float address:${addr};" \
    "dispatch alterzorder top address:${addr};"
}

# Detach a grouped window before applying the regular pin workflow.
# Once it leaves the group, the window is treated like any other pinned float.
pin_grouped_window() {
  local workspace=$1
  local addr=$2
  local width=$3
  local height=$4

  run dispatch moveoutofgroup "address:${addr}"
  run dispatch focuswindow "address:${addr}"

  pin_regular_window "${workspace}" "${addr}" "${width}" "${height}"
}

# Parse the active window state once, print debug fields when requested, and
# dispatch to either pin or unpin based on the current pinned flag.
main() {
  if [[ ${1:-} == "--debug" ]]; then
    DEBUG=1
    shift
  fi

  local active_json
  active_json=$(hyprctl activewindow -j)

  local pinned addr monitor_id workspace grouped is_grouped
  # Parse activewindow JSON once into 6 tab-separated tokens:
  # 1) pinned flag
  # 2) window address
  # 3) monitor id
  # 4) workspace id
  # 5) grouped list as one compact JSON-like token
  # 6) grouped flag as 0/1 (1 when grouped)
  # Using a safe array fallback and an explicit boolean avoids
  # brittle string checks like 'grouped == []'.
  read -r pinned addr monitor_id workspace grouped is_grouped < <(
    jq -r '
    (.grouped // []) as $g
    | [
        .pinned,
        .address,
        .monitor,
        .workspace.id,
        "[" + ($g | map("\"" + . + "\"") | join(",")) + "]",
        (if ($g | length) > 0 then "1" else "0" end)
      ]
    | @tsv
    ' <<<"${active_json}"
  )

  if [[ ${DEBUG} -eq 1 ]]; then
    print_debug_fields
  fi

  if [[ ${pinned} == "true" ]]; then
    unpin_window "${addr}"
  elif [[ -n "${addr}" ]]; then
    pin_window "${addr}" "${workspace}" "${grouped}" "${monitor_id}" "${is_grouped}"
  fi
}

main "$@"
