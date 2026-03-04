#!/usr/bin/env bash

pidof hyprlock || hyprlock &

# TODO: Lock 1Password if running
# Needs 1Password CLI
# if pgrep -x "1password" >/dev/null; then
#   1password --lock &
# fi
