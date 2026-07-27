# Desktop Dashboard

A small always‑on panel for macOS, powered by [Hammerspoon](https://www.hammerspoon.org),
that labels each of your Spaces ("Desktops") with the **project** or **subject** of
its windows and floats the list on every Desktop. Click a line to jump to that Desktop.

```
Built-in Retina Display:
    Desktop 1 → Utility
  ▸ Desktop 2 → Mail
    Desktop 3 → three-way_SST_error_analysis_manuscript
    Desktop 4 → opendap-registry
iMac:
    Desktop 1 → Browser
─────────────────────────────
⌘⌃⌥  S scan · D hide · N name · R restore
click a line to switch Desktops
```

macOS has no supported way to rename a Space's Mission Control label without either
disabling System Integrity Protection or a paid helper app, so this takes the opposite
approach: it draws its own overlay showing the same information. Free, no SIP.

## What it does

- **Labels each Desktop** by what's on it:
  - the **repo** it's focused on, if a window's open file lives under one of your repo
    roots (e.g. `~/Git_Repos/opendap-registry`), or if a repo name appears in a
    terminal/Finder title on that Desktop;
  - otherwise the **app** (a single app → its name, e.g. `Mail`), the **subject**
    (two or more apps that share one, e.g. `Communication`), or `Utility` (a mix of
    several subjects).
- **Ignores Finder and Terminal** when deciding the subject (their titles are still
  used as repo hints).
- **Click a line** to switch to that Desktop.
- **Auto‑refreshes** when windows open or close, when you switch Desktops, and on a
  periodic backstop — so opening `CLAUDE.md` on a Desktop relabels it within ~1s.
- **Custom names** you set are remembered and take priority over auto‑detection.
- **Saves** names and window layout, and can restore the layout after a reboot.

## Install

Requires [Hammerspoon](https://www.hammerspoon.org) (free, notarized, **no SIP changes**).
Full steps are in **[INSTALL.md](INSTALL.md)**: install Hammerspoon, grant Accessibility,
add the loader line to `~/.hammerspoon/init.lua`, Reload Config, then press ⌘⌃⌥S once to
label every Desktop.

## Controls

| Shortcut | Action |
|----------|--------|
| Click a line | Switch to that Desktop |
| ⌘⌃⌥ D | Show / hide the dashboard |
| ⌘⌃⌥ N | Name the current Desktop (blank input clears it, back to auto) |
| ⌘⌃⌥ R | Restore the saved window layout (move/open windows to match) |
| ⌘⌃⌥ S | Walk every Desktop once and label them all |

## Configuration

Everything is in the `CONFIG` block at the top of `desktop_dashboard.lua`. The ones you'll
likely change:

- `M.repoRoots` — folders whose subdirectories are your repos (default `~/Git_Repos`).
- `M.categories` / `M.categoryPatterns` — app → subject mappings (Mail → Communication, …).
- `M.docApps` — apps whose open file is read for repo detection. **Keep slow apps
  (Electron/Office/Java) out of this list** — asking them for a file path can stall.
- `M.ignoreApps` — apps excluded from the subject decision (Finder, Terminal, …).
- `M.corner`, `M.fontSize`, `M.minWidth`/`M.maxWidth` — appearance.
- `M.showLegend`, `M.legendLines` — the command legend at the bottom.

## Sharing across machines / with colleagues

- The code is portable; the **config is per‑machine** — set `M.repoRoots` and adjust
  `M.categories`/`M.docApps` to the apps you actually use.
- **Do not sync** `~/.hammerspoon/desktop_dashboard_state.json`. It holds this machine's
  Desktop names and window layout keyed to that machine's Spaces; it is regenerated
  locally and is intentionally outside the repo.
- Accessibility permission is granted per machine.

## Limitations

- macOS only lets an app read a window's details while its Desktop is active, so a
  Desktop is labeled when you visit it (or via ⌘⌃⌥S), not before. There is no
  SIP‑free way around this.
- The label shows in this overlay, **not** in the Mission Control thumbnail (that would
  require SIP‑off Dock injection or a paid app).
- Dragging a window between Desktops isn't an open/close event, so that case waits for
  the next Desktop switch or the periodic backstop.
- Custom names are keyed to a Space's internal ID in‑session and to its position on disk;
  a full reboot can reset an in‑session custom name until the next save catches up.

See `CLAUDE.md` for the design decisions and why they were made.
