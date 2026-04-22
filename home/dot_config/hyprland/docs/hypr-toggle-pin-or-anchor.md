# Anchor Window Toggle Design

This note explains the two related pinning helpers in this repo:

- `scripts/hypr-toggle-anchor.sh` for the full anchor workflow
- `scripts/hypr-toggle-pin.sh` for simple pin toggling on windows that are already floating

In this repo, an anchored window means a window that has been floated and pinned
together as one workflow.

## Two Workflows

The anchor workflow turns a tiled window into a floating pinned window and can
later restore it back into its original workspace context.

```text
tiled window
    |
    | toggle anchor
    v
floating + pinned window
    |
    | toggle anchor
    v
tiled window again
```

The simple pin workflow is narrower. It only works on windows that are already
floating and only toggles the pin state.

```text
floating window
    |
    | toggle pin
    v
floating + pinned window
    |
    | toggle pin
    v
floating window again
```

## `hypr-toggle-anchor.sh`

`scripts/hypr-toggle-anchor.sh` is the full float-and-pin helper.

When the active window is not pinned yet, it does this:

1. Read the current active window details and current monitor size.
2. Write a small runtime snapshot before changing the window.
3. Float the window.
4. Resize it to `50% x 75%` of the current monitor and center it.
5. Pin it so it stays visible across workspaces.
6. Raise it above the tiled stack.
7. Tag it as `pinned-float`.

That flow looks like this:

```text
workspace 2 layout

+--------+--------+
|   A    |   B    |
+--------+--------+

toggle anchor on B

state file written first
        +
B becomes floating + pinned

      +------------+
      |     B      |
      |  anchored  |
      +------------+
```

When the active window is already anchored, the script reads the saved runtime
snapshot, restores the window to its old workspace, clears pinning and floating,
removes the `pinned-float` tag, and then lets the window rejoin the tiled layout.

Grouped windows use the same broad idea but with extra restore state so the
window can rejoin the correct workspace and regroup as reliably as possible.

The runtime snapshot directory is:

```text
${XDG_RUNTIME_DIR:-/tmp}/vvn/hyprland-pins/
```

New snapshot files use:

```text
hypr-toggle-anchor-<window-address>.txt
```

The anchor script also still reads older `hypr-toggle-pinned-<window-address>.txt`
files so already-anchored windows can be restored cleanly after the rename.

## `hypr-toggle-pin.sh`

`scripts/hypr-toggle-pin.sh` is intentionally much smaller.

It only operates on windows that are already floating. It does not float,
resize, center, move, retag, or save any restore state.

Its behavior is:

1. Read the active window.
2. Ignore the window if it is not floating.
3. Ignore the window if it carries the `pinned-float` tag.
4. Toggle only the pin state.

That means this helper is for user-floated windows, not for windows managed by
the anchor workflow.

## `pinned-float` Rule

The split between the two scripts depends on the `pinned-float` tag.

`scripts/hypr-toggle-anchor.sh` adds that tag when it anchors a window and
removes it when the window is restored.

`scripts/hypr-toggle-pin.sh` treats that tag as a guard and leaves those windows
alone.

The matching size rule lives in `land/rules/floats.conf`:

```hyprlang
windowrule {
  name = wr-pip
  match:tag = pinned-float
  size = (monitor_w*0.50) (monitor_h*0.75)
}
```

That rule gives anchored windows their default anchored size, while still
letting the plain pin script stay focused on pinning only.
