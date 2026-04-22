# Hyprland Layouts and `layoutmsg`

This note is for Hyprland `0.54.x` and is focused on two ideas:

- what a layout controls
- how `layoutmsg` talks to the active layout

## What a layout is

In Hyprland, a layout controls how tiled windows are arranged on a workspace.

- Tiled windows are managed by the current layout.
- Floating windows sit outside the layout.
- Fullscreen windows also bypass normal tiled layout behavior.

That means layout decisions and floating decisions are separate. For example, a
window can be made floating by rules or tags and then stop participating in the
workspace layout entirely.

In this config, the default layout is `dwindle` in `land/looknfeel.conf`:

```hyprlang
general {
    layout = dwindle
}
```

There are also layout-specific config blocks in `land/looknfeel.conf` for
`dwindle` and `master`.

## What `layoutmsg` is

`layoutmsg` is a dispatcher that forwards a message string to the active layout
on the focused workspace.

It is best to think about it like this:

- `layoutmsg` is the transport
- the message is the layout-specific command
- the active layout is what interprets that command

So this is valid in `dwindle`:

```text
layoutmsg + togglesplit + dwindle
```

But the same message is not meaningful in every other layout.

`layoutmsg` is workspace-local. It affects the layout that is active on the
currently focused workspace, not every workspace at once.

## How to call it

From a keybind:

```hyprlang
bind = $mainMod SHIFT, J, layoutmsg, togglesplit
```

From the CLI:

```bash
hyprctl dispatch layoutmsg "togglesplit"
hyprctl dispatch layoutmsg "mfact exact 0.60"
```

If the message contains spaces, quote it in the shell.

## Current use in this config

This config already uses `layoutmsg` here:

```hyprlang
bindd = $mainMod SHIFT, J, Toggle Window Split, layoutmsg, togglesplit
```

That bind lives in `land/keybinds.conf` and is specifically a `dwindle` action.
It only makes sense when the current workspace is using `dwindle`.

## Common `layoutmsg` messages by layout

The same dispatcher is reused across layouts, but the messages differ.

### Dwindle

`dwindle` is the BSP-style split tree layout.

Useful messages:

```bash
hyprctl dispatch layoutmsg "togglesplit"
hyprctl dispatch layoutmsg "swapsplit"
hyprctl dispatch layoutmsg "preselect r"
hyprctl dispatch layoutmsg "splitratio -0.10"
```

- `togglesplit` flips the split direction for the focused node.
- `swapsplit` swaps the current split orientation.
- `preselect r` preselects the next split direction.
- `splitratio -0.10` adjusts the split ratio.

### Master

`master` organizes windows as a master area plus a stack.

Useful messages:

```bash
hyprctl dispatch layoutmsg "swapwithmaster"
hyprctl dispatch layoutmsg "focusmaster"
hyprctl dispatch layoutmsg "mfact exact 0.60"
hyprctl dispatch layoutmsg "orientationnext"
```

- `swapwithmaster` moves the focused window into the master slot.
- `focusmaster` focuses the master window.
- `mfact exact 0.60` sets the master area size factor.
- `orientationnext` rotates the master layout orientation.

### Scrolling

`scrolling` uses a tape or column-oriented model.

Useful messages:

```bash
hyprctl dispatch layoutmsg "move +col"
hyprctl dispatch layoutmsg "colresize +conf"
hyprctl dispatch layoutmsg "fit visible"
hyprctl dispatch layoutmsg "focus l"
hyprctl dispatch layoutmsg "swapcol r"
```

- `move +col` moves a window into the next column.
- `colresize +conf` resizes the current column.
- `fit visible` fits the layout to the visible area.
- `focus l` moves focus left.
- `swapcol r` swaps with the column on the right.

### Monocle

`monocle` shows one tiled window at a time.

Useful messages:

```bash
hyprctl dispatch layoutmsg "cyclenext"
hyprctl dispatch layoutmsg "cycleprev"
```

These cycle through the monocle stack.

## What `layoutmsg` is good for

Use `layoutmsg` when the action only makes sense inside a specific layout.

Good examples:

- toggling a `dwindle` split
- changing the master ratio in `master`
- moving between columns in `scrolling`
- cycling the visible tiled window in `monocle`

By contrast, use normal dispatchers for layout-independent behavior such as:

- `togglefloating`
- `fullscreen`
- `movefocus`
- `movewindow`

## Common gotchas

- `layoutmsg` acts on the focused workspace, not globally.
- A message can be valid in one layout and meaningless in another.
- Many messages assume there is a focused tiled window.
- Floating windows usually do not participate in layout operations.
- The same word can mean different things in different layouts.
- The main dispatchers page does not fully document layout messages; the layout
  pages are the source of truth.
- `hyprctl` is synchronous, so avoid spamming `layoutmsg` calls in tight loops.

## Practical workflow

When learning a new layout message:

1. Focus a tiled window on the workspace you want to test.
2. Run the message manually with `hyprctl dispatch layoutmsg "..."`.
3. Confirm the behavior matches the current layout.
4. Turn it into a bind only after the manual command feels right.

Example progression:

```bash
hyprctl dispatch layoutmsg "togglesplit"
```

Then:

```hyprlang
bind = $mainMod SHIFT, J, layoutmsg, togglesplit
```

## Mental model to keep

Ask this question before using `layoutmsg`:

> What layout is active on this workspace right now?

If the answer changes, the meaning of the same `layoutmsg` bind can change too.
