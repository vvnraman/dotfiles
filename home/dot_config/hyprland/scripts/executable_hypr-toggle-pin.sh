#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Toggle pinning for the active floating window.
#
# Windows managed by the anchor workflow carry the pinned-float tag and are
# ignored here so this script only handles plain user-floated windows.

active=$(hyprctl activewindow -j)
addr=$(jq -r '.address // empty' <<<"${active}")
pinned=$(jq -r '.pinned' <<<"${active}")
floating=$(jq -r '.floating' <<<"${active}")
is_anchor=$(jq -r '((.tags // []) | index("pinned-float")) != null' <<<"${active}")

if [[ -z "${addr}" || "${floating}" != "true" || "${is_anchor}" == "true" ]]; then
  exit 0
fi

hyprctl dispatch pin "address:${addr}"
