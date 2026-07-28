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
- `M.noRepoHintApps` — apps whose window titles are ignored for repo detection: browsers
  (a page title such as `pcornillon/Desktop_Dashboard · GitHub`), chat apps (Claude,
  ChatGPT), and **Finder** (its title is whatever folder you're browsing, which is not
  the same as what the Desktop is for). They still count toward the Desktop's subject —
  only their titles are withheld.
- `M.claudeOnlyHintApps` / `M.claudeTitleMarker` — terminals, whose titles count as a
  repo hint **only when running claude**. A shell sitting in a repo is weak evidence; a
  `claude` session in one is the strongest signal there is.
- `M.appLabels` — display-name overrides for a Desktop holding a **single** app
  (`Claude` → `Claude Chat/Cowork`). A Desktop with several apps is decided by subject
  before this is consulted; use ⌘⌃⌥N to name those.
- `M.repoRescanSeconds` — how often the repo roots are re-listed, so a repo created
  after Hammerspoon launched is detected without a Reload Config.
- `M.showClaudeDot`, `M.claudeDotChar`, `M.claudeDotColors`, `M.claudeDotSeconds` — the
  claude session dot (below).
- `M.corner`, `M.fontSize`, `M.minWidth`/`M.maxWidth` — appearance.
- `M.showLegend`, `M.legendLines` — the command legend at the bottom.

## The claude session dot

A Desktop labeled with a repo that also has a `claude` session running in that repo gets
a colored dot between the Desktop number and the arrow:

```
▸ Desktop 10 ● → Desktop_Dashboard      yellow — that session is working
   Desktop 4 ● → opendap-registry        red   — it is asking you something
   Desktop 6 ● → MODIS_L2                green — it finished and you haven't looked
   Desktop 7   → SIED                    no dot — nothing to tell you
```

Precedence is yellow → red → green. Computing always wins: the moment you answer a
question the session resumes and the dot goes yellow again.

**Green means "finished, unseen" — not merely "idle".** It appears on the working →
not-working edge, so it marks a prompt that *completed while you were elsewhere*. It
clears when you visit that Desktop; clicking its line in the panel counts, since that
switches you there. Re-prompting a session clears it too (it goes yellow again). A
session that was already sitting idle when the dashboard started shows nothing at all,
so you don't get a wall of green on login.

**Red requires the hooks** (see INSTALL.md). Without them everything still works, you
just never see red — a session waiting on you shows green like any other finished one.
That is not a shortcut: the terminal title is identical in both cases (measured), so
only Claude Code's own `Notification` hook can tell them apart.

There is no way to acknowledge by pressing return in the claude window: an empty return
doesn't change the terminal title, so the dashboard has no way to observe it. Visiting
the Desktop is the acknowledgement.

**There are only two colors, and that is a limit of the signal, not a shortcut.** Claude
Code stamps the terminal title with an animated Braille spinner while it computes and
with `✳` when it does not. Measured over ~750 one-second samples: a session *blocked on a
question* shows the same `✳` as one that has *finished*. The title says whether work is
happening, never why it stopped, so "waiting for you" cannot be distinguished from "done"
and there is no red dot. If that ever changes, `M.claudeDotColors` is where it goes.

Titles are read from Terminal via AppleScript rather than Accessibility, which is why the
dot stays live for Desktops you are **not** currently viewing — Accessibility can only see
the Space you are on. The read is asynchronous (`hs.task`), so a slow or wedged Terminal
cannot stall the panel.

Set `M.showClaudeDot = false` to turn the whole thing off.

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
