# Desktop Dashboard

**A macOS status panel for running several Claude Code sessions at once.**

It answers one question at a glance: **what is every `claude` session on this machine doing
right now** — including the ones on Desktops you can't see. With four or five sessions
running, you otherwise have to visit each in turn to find the one that stopped to ask you
something.

It works whichever way you organise things. **⌘⌃⌥M** switches between two views, or shows
both at once.

**Desktops** — one line per Space, labelled by the repo or app on it:

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
⌘⌃⌥  S scan · D hide · N name
     R restore · M mode
click a line to switch Desktops
```

**Sessions** — one line per running session, wherever its window happens to be. For people
who keep every session on a single Desktop, where listing Desktops says almost nothing:

```
Claude sessions:
   T1   three-way_SST_error_analysis_manuscript
            Review status and co…
   T2 ● opendap-registry
            Implement Phase 2 fi…
   T3 ● MODIS_L2_Manuscript
            Claude Code
```

The dots mean the same in both: **yellow** working, **red** waiting on you, **green**
finished and you haven't looked yet. Click a line to go there — a Desktop in one view, a
terminal window in the other. Drag the panel wherever you want it.

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
- **Two views, ⌘⌃⌥M** — list Desktops, list sessions, or both. See
  [Two views](#two-views-desktops-or-sessions). Sessions are found automatically; nothing
  to register, and they keep their numbering as others come and go.
- **Labels a Desktop with the repo you're working in**, so `claude` running in
  `~/Git_Repos/opendap-registry` makes that Desktop read `opendap-registry`.

**For everything else**

- Labels non-project Desktops by **app** (one app → `Mail`), **subject** (several apps
  sharing one → `Communication`), or `Utility` (a mix).
- **Click a line** to go there — a Desktop, or a session's terminal window.
- **Drag the panel** anywhere; each display remembers where you put it.
- **Auto-refreshes** on window open/close, Desktop switch, and a periodic backstop; the
  session dots poll faster still (~3 s).
- **Custom names** (⌘⌃⌥N) override auto-detection and are remembered.
- **Remembers** your view, panel position and Desktop names across reloads and reboots.

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
| ⌘⌃⌥ M | Cycle what the panel lists: Desktops / claude sessions / both |
| Drag the panel | Move it anywhere; the position is remembered per display |

**A name you type yourself sticks.** It beats whatever the dashboard would have worked
out, and ⌘⌃⌥S will not overwrite it — that's the point of setting one. To go back to
automatic labeling, press ⌘⌃⌥N on that Desktop again and submit an **empty** name.

Behind the scenes a scan still works out the automatic label for a Desktop you've named,
it just doesn't show it. So clearing your name reveals a current label, not a stale one —
and the session dot keeps working, because it follows the detected repo rather than the
name you typed.

**Dragging.** Press anywhere on the panel and drag it where you like. Each display
remembers its own position, and it survives a reload. A press that moves less than a few
pixels still counts as a click, so dragging doesn't interfere with clicking a line to
switch Desktops. `dd.resetPanelPosition()` in the Hammerspoon Console puts it back in the
corner; `M.draggable = false` disables dragging entirely.

## Two views: Desktops or sessions

The panel can list **Desktops** (the default), **claude sessions**, or both. **⌘⌃⌥M**
cycles; `M.mode` sets the startup value.

Sessions view exists for a different working style: if you keep every claude session on a
single Desktop, listing Desktops tells you almost nothing. This lists the sessions instead,
wherever their windows happen to be:

```
Claude sessions:
   T1   three-way_SST_error_analysis_manuscript
            Review status and co…
   T2 ● opendap-registry
            Implement Phase 2 fi…
   T3 ● MODIS_L2_Manuscript
            Claude Code
```

The dimmed second line is that session's **task summary** — Claude Code's own short
description of what it's working on, which it writes into the terminal window title. A
session that hasn't earned one yet reads `Claude Code`. It sits on its own line so the
panel's width is set by the project name rather than by the summary; `M.sessionTwoLine`,
`M.sessionSummaryChars` and `M.sessionSummaryIndent` control it, and either line can be
clicked.

Sessions are found automatically — nothing to register. They're numbered in the order
their terminal windows were created, so T1/T2/T3 stay put as sessions come and go. The
task summary after the project name is what tells apart **two sessions in the same repo**,
which the Desktop view cannot do at all. Click a line to bring that session's window
forward; macOS follows it to whatever Desktop it lives on.

A green dot here clears as soon as you **look at that session's window** — by clicking its
line, switching to the window yourself, or just typing in it. Whichever way you get there
counts as having seen it.

Same dots, with one difference worth knowing: yellow and green are **per session**, since
each is read from that window's own title. Red is **per repo** — the hooks record a
session id and a working directory, and nothing joins a hook file to a specific terminal
window, so if two sessions share a repo and one is asking you something, both show red.

Sessions view needs **Terminal.app**; other terminals aren't listed.

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
3b. **A claude session's working directory**, even if it isn't one of your repo roots — so
   `claude` started in your home directory labels that Desktop too, and gets a dot.
4. **The apps themselves** — one app → its name; several sharing a subject → that subject;
   several subjects → `Utility`.

## Configuration

Everything is in the `CONFIG` block at the top of `desktop_dashboard.lua`. Most likely to
need changing:

- `M.repoRoots` — folders whose subdirectories are your repos (default `~/Git_Repos`).
- `M.mode` — which view the panel opens in: `"desktops"`, `"terminals"` or `"both"`. ⌘⌃⌥M
  changes it at runtime and the choice is remembered, so this is only the first-run value.
- `M.sessionTwoLine`, `M.sessionSummaryChars`, `M.sessionSummaryIndent`, `M.sessionHeader`
  — the sessions view: whether the task summary gets its own indented line, how much of it
  is shown, how far it's indented, and the section heading in `"both"` mode.
- `M.draggable`, `M.dragThreshold` — panel dragging, and how far the mouse must move before
  a press counts as a drag rather than a click. `dd.resetPanelPosition()` re-corners it.
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
