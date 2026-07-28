# Desktop Dashboard

**A macOS status panel for running several Claude Code sessions at once.**

If you keep one Desktop (Space) per project, this tells you at a glance which project each
Desktop belongs to and — the point of the whole thing — **what every `claude` session on
your machine is doing right now**, including the ones you can't see:

```
Built-in Retina Display:
    Desktop 1   → Utility
  ▸ Desktop 2   → Communication
    Desktop 3 ● → three-way_SST_error_analysis_manuscript     ← working
    Desktop 4 ● → opendap-registry                            ← asking you something
    Desktop 6 ● → MODIS_L2                                    ← finished, you haven't looked
    Desktop 7   → SIED
iMac:
    Desktop 1   → Claude Chat/Cowork
─────────────────────────────
⌘⌃⌥  S scan · D hide · N name · R restore
click a line to switch Desktops
```

The dots are colored: **yellow** working, **red** waiting on you, **green** finished and
unseen. Click any line to jump to that Desktop.

The problem it solves: with four or five sessions running in different repos on different
Desktops, you cannot tell which one has stopped to ask you a question without visiting each
in turn. Everything else the panel does — labeling Desktops by repo, by app, by subject —
grew out of making that one thing legible.

Built on [Hammerspoon](https://www.hammerspoon.org). Free, notarized, **no SIP changes**.

## Why an overlay

macOS has no supported way to rename a Space's Mission Control label without disabling
System Integrity Protection or buying a helper app. So this draws its own always-on panel
instead, visible from every Desktop.

## What it does

**For Claude sessions**

- **A colored dot per session** — yellow while it computes, red when it's blocked asking
  you something, green when it finished while you were elsewhere. See
  [the dot](#the-claude-session-dot).
- **Works for Desktops you aren't looking at.** macOS won't let an app read the windows of
  a Space you're not viewing, but Terminal will report every window's title regardless — so
  session state stays live everywhere, which is exactly where it's useful.
- **Labels a Desktop with the repo you're working in**, so `claude` running in
  `~/Git_Repos/opendap-registry` makes that Desktop read `opendap-registry`.

**For everything else**

- Labels non-project Desktops by **app** (one app → `Mail`), **subject** (several apps
  sharing one → `Communication`), or `Utility` (a mix).
- **Click a line** to switch to that Desktop.
- **Auto-refreshes** on window open/close, Desktop switch, and a periodic backstop; the
  session dots poll faster still (~3 s).
- **Custom names** (⌘⌃⌥N) override auto-detection and are remembered.

## Install

Full steps in **[INSTALL.md](INSTALL.md)** — install Hammerspoon, grant Accessibility, add
the loader line to `~/.hammerspoon/init.lua`, Reload Config, press ⌘⌃⌥S once.

The **red** dot needs one extra, optional step: letting Claude Code tell the dashboard when
it has paused for you. Claude Code can be told to run a script automatically at set moments.
The script ships with this tool (`claude-dashboard-state.sh`) and the moments are already
chosen — when a session starts working, stops to ask you something, or finishes. Setting it
up is copying four entries into your Claude Code settings file; there is nothing to write
and nothing to decide. (Those entries are what Claude Code calls *hooks*.) Everything except
the red dot works without this.

INSTALL.md also has a **[test prompt](INSTALL.md#testing)** you can paste into a session to
watch all three colors happen on cue.

### Let Claude Code install it

Since you're presumably already running Claude Code, it can do most of this. Clone the repo
wherever you keep your projects — from that folder:

```sh
git clone https://github.com/pcornillon/Desktop_Dashboard.git
```

Then start `claude` inside the new `Desktop_Dashboard` folder and paste:

````text
Install this tool on my Mac by following INSTALL.md in this repo.

Do the steps you can do from a shell. Two steps are mine, not yours — stop and ask me
when you reach each one:
  - granting Hammerspoon Accessibility permission (macOS won't let software grant it)
  - confirming the panel actually appeared on my screen

Two files may already exist and may contain things I care about. Back both up first,
show me what you intend to change, and ADD to them — never overwrite:
  - ~/.hammerspoon/init.lua
  - ~/.claude/settings.json  (only if I say I want the red dot; merge the four entries
    into any existing "hooks" object rather than replacing it)

If `brew` asks for my password, stop and tell me rather than trying to work around it.

When you're done, tell me the version string Hammerspoon printed to its Console.
````

**What it can't do, and why:** granting Accessibility is blocked by macOS by design, and
confirming the panel appeared needs eyes on the screen — a screenshot taken from a shell
can't see the overlay without Screen Recording permission. Everything else, including
restarting Hammerspoon to load the config, works from a shell.

## Controls

| Shortcut | Action |
|----------|--------|
| Click a line | Switch to that Desktop |
| ⌘⌃⌥ D | Show / hide the dashboard |
| ⌘⌃⌥ N | Name the current Desktop yourself |
| ⌘⌃⌥ R | Restore the saved window layout (move/open windows to match) |
| ⌘⌃⌥ S | Visit every Desktop once and label the ones you haven't named |
| Drag the panel | Move it anywhere; the position is remembered per display |

**A name you type yourself sticks.** It beats whatever the dashboard would have worked
out, and ⌘⌃⌥S will not overwrite it — that's the point of setting one. To go back to
automatic labeling, press ⌘⌃⌥N on that Desktop again and submit an **empty** name.

Behind the scenes a scan still works out the automatic label for a Desktop you've named,
it just doesn't show it. So clearing your name reveals a current label, not a stale one.

**Dragging.** Press anywhere on the panel and drag it where you like. Each display
remembers its own position, and it survives a reload. A press that moves less than a few
pixels still counts as a click, so dragging doesn't interfere with clicking a line to
switch Desktops. `dd.resetPanelPosition()` in the Hammerspoon Console puts it back in the
corner; `M.draggable = false` disables dragging entirely.

## The claude session dot

A Desktop labeled with a repo that also has a `claude` session running in that repo gets a
colored dot between the Desktop number and the arrow:

| dot | meaning | needs the extra setup? |
|-----|---------|------------------------|
| 🟡 yellow | that session is working | no |
| 🔴 red | it has stopped to ask you something | **yes** |
| 🟢 green | it finished and you haven't looked yet | no |
| *(none)* | nothing to tell you | — |

Order of priority is **yellow → red → green**. Working always wins, so the instant you
answer a question the dot goes straight back to yellow.

**Green means "finished, unseen", not merely "idle".** It appears on the working →
not-working edge, so it marks a prompt that *completed while you were elsewhere*. It clears
when you visit that Desktop — clicking its line counts, since that switches you there — and
re-prompting the session clears it too. A session already sitting idle when the dashboard
starts is never flagged, so you don't get a wall of green at login.

**Red needs the extra setup in INSTALL.md.** Without it everything else still works — you
simply never see red, and a session waiting on you looks the same as one that has finished.

Why it needs help is worth knowing, because it explains what the dashboard can and can't
see. To tell whether a session is busy, it reads the session's **terminal window title**,
which Claude Code keeps updated as it goes. Asking Terminal for its window titles works for
*every* Desktop, which is why the dots stay accurate for Desktops you aren't looking at —
macOS otherwise only lets an app inspect windows on the Desktop you're currently viewing.

That title reliably distinguishes *working* from *not working*. What it cannot tell you is
**why** a session stopped: one that has finished and one sitting there waiting for you to
answer a question look exactly alike. That isn't a guess — I sampled it about 750 times to
be certain. So the only way to know the difference is for Claude Code to say so itself, and
that is all the extra setup does: it has Claude Code run a short script whenever a session
pauses for your attention, finishes, or starts working again.

You can't acknowledge a dot by pressing return in the claude window — that changes nothing
the dashboard can see. Visiting the Desktop is the acknowledgement.

The title check runs in the background, so a slow or unresponsive Terminal can never freeze
the panel. Set `M.showClaudeDot = false` to turn the dots off entirely.

## How a Desktop gets its label

In order, first match wins:

1. **An open file inside a repo** — for editors in `M.docApps`, the document's path. The
   path names the repo, so the file is never opened or read.
2. **A repo name in a window title** — but only from titles that name a *location*. A
   terminal counts **only when it's running `claude`**; a shell that happens to be `cd`'d
   somewhere does not. Finder, browsers and chat apps never count: their titles name what
   you're *browsing* or *discussing*, which is not what the Desktop is *for*.
3. **Loose token overlap** with a repo name.
4. **The apps themselves** — one app → its name; several sharing a subject → that subject;
   several subjects → `Utility`.

## Configuration

Everything is in the `CONFIG` block at the top of `desktop_dashboard.lua`. Most likely to
need changing:

- `M.repoRoots` — folders whose subdirectories are your repos (default `~/Git_Repos`).
- `M.showClaudeDot`, `M.claudeDotColors`, `M.claudeDotSeconds`, `M.claudeStateDir` — the
  session dot.
- `M.claudeOnlyHintApps` / `M.claudeTitleMarker` — terminals whose titles count as a repo
  hint only while running claude. Add your terminal if it isn't listed.
- `M.docApps` — apps asked for their open file's path. **Keep slow apps
  (Electron/Office/Java) out** — asking them can stall for minutes.
- `M.noRepoHintApps` — apps whose titles never suggest a repo: browsers, chat apps, Finder.
- `M.categories` / `M.categoryPatterns` — app → subject mappings.
- `M.appLabels` — display name for a Desktop holding a **single** app
  (`Claude` → `Claude Chat/Cowork`).
- `M.ignoreApps` — apps excluded from the subject decision.
- `M.repoRescanSeconds` — how often repo roots are re-listed, so a repo created after
  launch is found without a reload.
- `M.corner`, `M.fontSize`, `M.minWidth`/`M.maxWidth`, `M.showLegend`, `M.legendLines` —
  appearance.

## Sharing across machines / with colleagues

- The code is portable; the **config is per-machine** — set `M.repoRoots` and adjust
  `M.categories`/`M.docApps` to the apps you actually use.
- **Do not sync** `~/.hammerspoon/desktop_dashboard_state.json` or `claude_state/`. Both are
  keyed to one machine's Spaces and sessions, are regenerated locally, and live outside the
  repo on purpose.
- Accessibility permission is granted per machine.

## Limitations

- macOS only lets an app read a window's details while its Desktop is active, so a Desktop
  is labeled when you first visit it (or via ⌘⌃⌥S), not before. There's no SIP-free way
  around this. **Session dots are the exception** — they come from asking Terminal for its
  window titles, which reports every Desktop, not just the visible one.
- Session dots currently require **Terminal.app**; other terminals are labeled but get no
  dot.
- The label shows in this overlay, **not** in the Mission Control thumbnail.
- Dragging a window between Desktops isn't an open/close event, so that case waits for the
  next Desktop switch or the periodic backstop.
- ⌘⌃⌥R (restore layout) is **manual and partial**: it can only move windows that are on a
  currently-visible Desktop, and can only reopen windows that have a document path. It will
  not reassemble a scattered post-reboot layout. For apps that always belong in one place,
  macOS's own Dock → Options → **Assign To** is more reliable.

See `CLAUDE.md` for the design decisions and the measurements behind them.
