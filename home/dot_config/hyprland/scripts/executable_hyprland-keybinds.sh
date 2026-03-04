#!/usr/bin/env bash

binds=$(hyprctl binds -j | jq -r '
  [ .[] | 
    ( 
      [ (if (.modmask / 64 | floor) % 2 == 1 then "SUPER" else null end),
        (if (.modmask / 8 | floor) % 2 == 1 then "ALT" else null end),
        (if (.modmask / 4 | floor) % 2 == 1 then "CTRL" else null end),
        (if (.modmask / 1 | floor) % 2 == 1 then "SHIFT" else null end)
      ] | map(select(. != null)) | if length > 0 then join(" + ") else "NONE" end
    ) as $mods
    | ($mods + (if .key != "" then " + " + .key else "" end)) as $bind
    | {bind: $bind, action: (.dispatcher + (if .arg != "" then " " + .arg else "" end))}
  ]
  | sort_by(.bind)
  | .[] 
  | .bind + " → " + .action
')

echo "$binds" | rofi -dmenu -i -p "Hyprland Keybinds" -markup-rows
