# Hyprland Screenshot Helper

This note documents the repo-local behavior of `scripts/hypr-screenshot.sh`.
It focuses on the screenshot workflow itself and intentionally skips the generic
library helpers bundled near the top of the script.

## What this script is for

`scripts/hypr-screenshot.sh` is the main screenshot helper for this Hyprland
config.

The current binds live in `land/keybinds.conf`:

```hyprlang
bindd =            , PRINT,      Screenshot Monitor, exec, ~/.config/hyprland/scripts/hypr-screenshot.sh --mode=monitor
bindd = CTRL       , PRINT,      Screenshot Window,  exec, ~/.config/hyprland/scripts/hypr-screenshot.sh --mode=window
bindd = $mainMod   , PRINT,      Screenshot Region,  exec, ~/.config/hyprland/scripts/hypr-screenshot.sh --mode=region
```

The script also supports `workspace` mode, but this repo does not currently bind
it to a key.

## High-level flow

At a high level, the script does four things:

1. Parse options.
2. Validate dependencies and option values.
3. Turn the chosen mode into a capture geometry.
4. Pipe the capture into either `satty` or `wl-copy`.

```text
mode
  |
  v
geometry lookup
  |
  +--> filename
  |
  v
grim -g "x,y wxh"
  |
  +----------------------+-------------------+
  |                                          |
  v                                          v
satty                                   wl-copy
(annotate/save/copy)                    (raw clipboard only)
```

## Required tools

Before doing anything useful, the script checks for these commands:

- `hyprctl`
- `jq`
- `hyprpicker`
- `grim`
- `satty`
- `slurp`
- `wl-copy`

If any are missing, it aborts before capture starts.

## CLI surface

The script exposes these practical options:

- `--mode=window|monitor|workspace|region`
- `--format=ts_initial_title|ts_only|ts_title|ts_initial_and_current_title`
- `--clipboard=yes|no|only|only_no_annotation`
- `--dry-run`
- `-v`
- `--help`

Defaults:

- mode: `window`
- format: `ts_initial_title`
- clipboard: `yes`

Two important details:

- `--format` only changes window-mode filenames; monitor, workspace, and region
  use fixed filename patterns.
- `--format-string` is advertised in the script metadata, but `main()` does not
  currently parse or use it.

## How each mode gets geometry

Each mode reduces to a single geometry string in the form `x,y widthxheight`.

### Window mode

`window` reads `hyprctl activewindow -j` and uses the window's `.at` and `.size`
fields directly.

```text
hyprctl activewindow -j
        |
        +--> .at   -> x y
        |
        +--> .size -> w h
        |
        v
geometry = "x,y wxh"
```

This is the default mode, so `Ctrl+Print` is really selecting the currently
focused window and capturing its exact rectangle.

### Monitor mode

`monitor` reads the focused monitor from `hyprctl monitors -j` and uses the
monitor origin plus its scaled width and height.

```text
hyprctl monitors -j
        |
        v
select focused monitor
        |
        +--> x y
        |
        +--> width / scale
        |
        +--> height / scale
        |
        v
geometry = "x,y wxh"
```

That makes the saved image match the logical monitor size Hyprland is using,
not the raw pre-scale pixel dimensions reported in JSON.

### Workspace mode

`workspace` first asks Hyprland for the active workspace id, then finds the
monitor whose `activeWorkspace.id` matches that id.

```text
hyprctl activeworkspace -j
        |
        v
active workspace id
        |
        v
hyprctl monitors -j
        |
        v
monitor whose activeWorkspace.id matches
        |
        v
geometry = monitor rectangle
```

In practice, this means workspace mode captures the visible monitor area that is
currently showing the active workspace. It is not a stitched "all windows in the
workspace no matter where they are" capture.

### Region mode

`region` temporarily freezes the screen feel with `hyprpicker`, asks `slurp` for
a rectangle, then tears the freeze down.

```text
start hyprpicker
      |
      v
slurp selects x y w h
      |
      v
stop hyprpicker
      |
      v
geometry = "x,y wxh"
```

The freeze/thaw logic is also protected by `trap cleanup EXIT`, so a normal exit
still tries to close the temporary `hyprpicker` process.

## Save location and filename rules

Saved screenshots go under:

```text
${XDG_PICTURES_DIR:-$HOME/Pictures}/screenshots/YYYY-MM/
```

Every saved file is named like this:

```text
screenshot_<derived-name>.png
```

### Window filenames

Window mode starts with a timestamp:

```text
YYYYMMDD_HHMMSS
```

It then appends title fields depending on `--format`:

- `ts_initial_title` -> timestamp + initial title
- `ts_only` -> timestamp only
- `ts_title` -> timestamp + current title
- `ts_initial_and_current_title` -> timestamp + initial title + current title

Window titles are sanitized before they become part of the filename:

- leading and trailing whitespace is trimmed
- spaces become `_`
- characters outside letters, numbers, `.`, `_`, and `-` are removed

### Monitor filenames

Monitor mode uses:

```text
<timestamp>_monitor_<monitor-name>_<width>x<height>
```

### Workspace filenames

Workspace mode uses:

```text
<timestamp>_workspace_<workspace-id>_<width>x<height>
```

### Region filenames

Region mode uses:

```text
<timestamp>_region_<x>_<y>_<width>x<height>
```

## Clipboard behavior

The `--clipboard` option controls whether the result is saved, copied, both, or
sent straight to the clipboard without annotation.

```text
clipboard=yes
grim -> satty -> save file + copy clipboard

clipboard=no
grim -> satty -> save file only

clipboard=only
grim -> satty -> copy clipboard only

clipboard=only_no_annotation
grim -> wl-copy -> clipboard only, no satty UI
```

This split is the most important practical behavior difference in the script:

- `yes`, `no`, and `only` all open `satty`
- `only_no_annotation` bypasses `satty` completely

So if you want a fast raw clipboard capture, `only_no_annotation` is the direct
path.

## What `satty` is doing here

For the annotated flows, `grim` writes image data to stdout and `satty` reads it
from stdin.

The script uses `satty --early-exit` in every annotated path, and adds:

- `--output-filename <path>` when a file should be written
- `--actions-on-enter save-to-clipboard` when the clipboard should receive the result
- `--save-after-copy` in the `clipboard=yes` path so the same annotated result is
  both copied and saved

That makes `satty` the place where annotation and final save/copy behavior come
together.

## Dry-run and verbose modes

`--dry-run` still parses options, validates dependencies, resolves geometry, and
builds the target path, but it does not run the final screenshot pipeline.

`-v` enables the script's logging helpers so you can see things like:

- which mode was chosen
- the computed geometry
- the derived output path

That is useful when checking whether Hyprland JSON and filename generation are
doing what you expect.

## Current repo-specific takeaways

- `scripts/hypr-screenshot.sh` is a geometry-first wrapper around `hyprctl`,
  `grim`, `satty`, `slurp`, and `wl-copy`.
- The keybind layer in `land/keybinds.conf` currently exposes monitor, window,
  and region capture.
- Workspace capture exists as a CLI feature even though it is not bound yet.
- The script's file naming is most configurable for window capture.
- The special fast path is `--clipboard=only_no_annotation`, which skips the
  annotation UI entirely.
