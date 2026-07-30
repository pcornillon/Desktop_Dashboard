# Desktop Dashboard

**A macOS status panel for running several Claude Code sessions at once.**

It answers one question at a glance: **what is every `claude` session on this machine doing
right now** — including the ones on Desktops you can't see. With four or five sessions
running, you otherwise have to visit each in turn to find the one that stopped to ask you
something.

It works whichever way you organise things. **⌘⌃⌥m** switches between two views, or shows
both at once.

![The Desktop Dashboard panel floating over a macOS desktop: twelve Desktops on an external display and one on a laptop display, each labelled with app icons or a project name and some carrying colored status dots, then a section listing three running Claude Code sessions, then a legend of keyboard shortcuts.](docs/panel.png)

Built on [Hammerspoon](https://www.hammerspoon.org). Free, notarized, **no SIP changes**.

## What you're looking at

That is the whole tool — one translucent panel, floating above everything, visible from
every Desktop. It's showing both views at once (**⌘⌃⌥m**). Working down the figure:

**One block per display.** `LG Ultra HD:` and `Built-in Retina Display:` head the Desktops
belonging to each screen, in Mission Control order. Headers only appear when you have more
than one display.

**One line per Desktop:** its number, two status dots, an arrow, and then a name, an icon
row, or both.

**`▸` and magenta mark where you are.** Two lines are marked here — `Desktop 11` on the LG
and `Desktop 1` on the laptop — because each display has its own active Desktop. The caret
and the color say the same thing twice on purpose, so the marker doesn't depend on being
able to distinguish magenta from white.

**Names name the work; icons name what's on it.** They're independent parts of the line:

| line in the figure | what it means |
|---|---|
| `Desktop 5 → opendap-registry` + 2 icons | a repo, detected from what's open on it, followed by the apps sitting there |
| `Desktop 4 → 3-way analysis` + 5 icons | the same thing, but with a name typed by hand (⌘⌃⌥n). Renaming replaces **only** the name — the icons still report what's actually there |
| `Desktop 1`, `2`, `3`, `6` … (icons only) | nothing here names *work*, so the icons are the answer. These would otherwise read `Utility`, `Communication` or a bare app name — words that told you almost nothing |
| `Desktop 12 → ` one icon | a single app owns this Desktop, so its icon says it |

**Finder and terminals come last in every row.** `Desktop 7` is a Finder window and a
terminal; `Desktop 9` is one terminal; `Desktop 8` adds them after MacDown. They never
decide what a Desktop is *about* — a Desktop is never "about Finder" — but seeing that
they're there is useful. Note `Desktop 5`: a `claude` session is running in that repo, yet
no terminal icon appears, because that terminal is *where the name came from*.

**`Desktop 6` shows ChatGPT and Claude** — two apps that expose no windows at all to
macOS's Accessibility API. That Desktop read as empty until those windows were found
through CoreGraphics instead. See [App icons](#app-icons).

**The two dots are a claude session and a git repo,** in that order:

| in the figure | reading |
|---|---|
| `Desktop 4` 🟡🔴 | a session is **working** here; the repo has uncommitted or unpushed changes |
| `Desktop 5` ⚪️🟢 | no session to report; the repo is **clean and fully pushed** |
| `Desktop 11` ⚪️🔴 | no session to report; this repo has local work GitHub doesn't have |
| most lines: no dots | not a repo, and no session — nothing to say, so nothing is drawn |

A **gray** dot is a placeholder, not a state: it holds the claude column open whenever the
git dot beside it is lit, so a lone green dot can never be mistaken for a finished session.
Full meanings in [the claude dot](#the-claude-session-dot) and
[the git dot](#the-git-status-dot).

**`Claude sessions:`** lists every running session, wherever its window is — the project
it's in, and the first words of what it's doing (`Fix vertical axis la…`). This is the
view that matters if you keep all your sessions on one Desktop, where listing Desktops
tells you nothing. Same dots, per session.

**Everything is clickable.** Click a Desktop line to switch to it; click an *icon* to
switch there **and** raise that app's window; click a session line to jump to its terminal
window. Point at an icon and it names itself and the window it would raise.

**The legend** at the bottom lists the hotkeys, and the **grip in the bottom-right corner**
resizes the whole panel — drag it out or in, everything scales together. Drag the panel
itself anywhere; each display remembers where you put it.

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
- **Two views, ⌘⌃⌥m** — list Desktops, list sessions, or both. See
  [Two views](#two-views-desktops-or-sessions). Sessions are found automatically; nothing
  to register, and they keep their numbering as others come and go.
- **Labels a Desktop with the repo you're working in**, so `claude` running in
  `~/Git_Repos/opendap-registry` makes that Desktop read `opendap-registry`.

**For git repos**

- **A git status dot per repo** — red when this machine has uncommitted or unpushed work,
  green when it's clean and in sync with GitHub. Local and offline. See
  [the git dot](#the-git-status-dot).
- **⌘⌃⌥g for GitHub state on demand** — a popup of each shown repo's local + GitHub status,
  querying the network only when you press it.

**For everything else**

- Labels non-project Desktops with **the icons of the apps on them**, rather than a word
  like `Mail`, `Communication` or `Utility`. Point at an icon to name it; click it to go
  straight to that window. See [App icons](#app-icons).
- **Marks where you are** — the active Desktop gets a caret and its number in magenta.
- **Click a line** to go there — a Desktop, or a session's terminal window.
- **Drag the panel** anywhere; each display remembers where you put it.
- **Auto-refreshes** on window open/close, Desktop switch, and a periodic backstop; the
  session dots poll faster still (~3 s).
- **Custom names** (⌘⌃⌥n) override auto-detection and are remembered.
- **Remembers** your view, panel position and Desktop names across reloads and reboots.

## Install

Full steps in **[INSTALL.md](INSTALL.md)** — install Hammerspoon, grant Accessibility, add
the loader line to `~/.hammerspoon/init.lua`, Reload Config, press ⌘⌃⌥s once.

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
| ⌘⌃⌥ d | Show / hide the dashboard |
| ⌘⌃⌥ n | Name the current Desktop yourself |
| ⌘⌃⌥ r | Restore the saved window layout (move/open windows to match) |
| ⌘⌃⌥ s | Visit every Desktop once and label the ones you haven't named |
| ⌘⌃⌥ m | Cycle what the panel lists: Desktops / claude sessions / both |
| ⌘⌃⌥ g | Pop up each shown repo's GitHub status (on demand; only this hits the network) |
| Drag the panel | Move it anywhere; the position is remembered per display |

**A name you type yourself sticks.** It beats whatever the dashboard would have worked
out, and ⌘⌃⌥s will not overwrite it — that's the point of setting one. To go back to
automatic labeling, press ⌘⌃⌥n on that Desktop again and submit an **empty** name.

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

The panel can list **Desktops** (the default), **claude sessions**, or both. **⌘⌃⌥m**
cycles; `M.mode` sets the startup value.

Sessions view exists for a different working style: if you keep every claude session on a
single Desktop, listing Desktops tells you almost nothing. This lists the sessions instead,
wherever their windows happen to be:

```
Claude sessions:
   T1 🟡🔴 three-way_SST_error_analysis_manuscript
              Fix vertical axis la…
   T2 ⚪️🔴 Desktop_Dashboard
              Improve dashboard la…
   T3 ⚪️🟢 opendap-registry
              Test timing with del…
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

## The git status dot

Every panel line whose label is one of your repos also carries a **second dot**, right
after the claude dot, telling you whether **this machine is in sync with GitHub**:

| dot | meaning |
|-----|---------|
| 🔴 red | GitHub doesn't have everything here — a dirty working tree (uncommitted or untracked changes) **or** local commits you haven't pushed |
| 🟢 green | clean working tree **and** all commits pushed |
| ⚪️ gray | nothing to report here — but the *other* dot on this line is lit, so this slot stays visible to keep the two apart |
| *(none)* | nothing to report on either dot: this line isn't a repo (an app label like `Mail`, or an icon row) and has no session |

This check is **local and offline** — `git status` plus a count of unpushed commits, run in
the background on its own timer (`M.gitDotSeconds`, default 15 s). It never touches the
network, so it can't hang and doesn't need any credentials. It deliberately does **not**
try to show GitHub's own state: that would go stale the instant anyone pushed, and a dot
shouldn't claim something it hasn't checked. Set `M.showGitDot = false` to turn it off;
`M.gitDotColors` sets the two colors.

The **gray** dot is a placeholder, not a state. The two dots are told apart only by
position — claude first, git second — and that's unreadable when one of them is blank: a
lone green dot sitting in the git column looks exactly like a claude dot saying "finished".
So an empty slot is drawn gray whenever the line's other dot is lit. Lines with nothing to
report on either dot stay blank rather than growing a pair of gray dots. Turn it off with
`M.showDotPlaceholders = false`; `M.dotPlaceholderColor` sets the shade.

## App icons

Every Desktop line is two independent parts: **a name, then an icon row.** The name says
what the Desktop is *for*; the icons say what is *on* it.

```
    Desktop 1    → ✉️💬📊🗂️                        ← no name: the icons are the answer
    Desktop 5 ●● → opendap-registry  📝🗂️         ← a repo, and what's open on it
    Desktop 9    → 🖥️                              ← just a terminal parked there
```

When a Desktop's label would only name **apps**, the icons replace it: `Utility` and
`Communication` (bins, being what's left when no repo matched and no single app owns the
Desktop) and a lone app's own name like `MacDown`. When the label names **work** — a repo,
or a claude session's directory — it keeps its text and the icons follow it.

**Apps that hide from Accessibility still get icons.** Some apps — the Claude desktop app
and ChatGPT Classic among them — expose no windows at all to the API this tool normally
reads, so a Desktop holding only those used to look empty (`—`). Those windows are now
found through CoreGraphics instead. They contribute an icon and nothing else (there's no
title or file path to read), and clicking one brings the *app* forward rather than a
specific window.

**Finder and terminals always come last** in the row. They're excluded from deciding what
a Desktop is *about* (a Desktop is never "about Finder"), but "there's a Finder and two
terminals here" is still worth seeing. One exception: a terminal's icon is dropped from a
Desktop named after a repo or a session directory, because that name came from the
terminal's own working directory — the icon would just say it twice.

**⌘⌃⌥n renames the name only.** The icons report what's actually on the Desktop, which
renaming it can't change.

A mixed Desktop needs at least **two** resolvable app icons before the row replaces the
word: one icon standing in for three apps would claim the others aren't there, and
`Utility` is at least honest about being a summary. Trailing Finder/terminal icons don't
count toward that. A single-app Desktop has no such problem, so one icon is enough.

## Resizing the panel

**Drag the grip in the bottom-right corner.** The whole panel scales, from 9 pt to 28 pt —
text, icons, dots, the legend and the width limits together, because they all derive from
one number (`M.fontSize`). Drag out along either axis to grow it, back to shrink it. The
size you pick is remembered across reloads and reboots, like the position you drag to.

The panel has no independent aspect ratio to distort: its shape follows its content, so
resizing only ever changes the scale.

`M.showResizeGrip = false` removes the grip; `M.minFontSize` and `M.maxFontSize` set the
range. `dd.setFontSize(n)` does the same thing from the console.

**Point at an icon and it names itself** — the app, plus the title of the window a click
would raise, so you can tell two windows of the same app apart before you commit:

```
    Desktop 1    → 💬✉️📨
                    ┌────────────────────────────────────────┐
                    │ Mail                                   │
                    │ All Inboxes — 3,645 messages, 1,113 un… │
                    └────────────────────────────────────────┘
```

**Clicking an icon takes you to that Desktop *and* raises that window.** Clicking anywhere
else on the line just goes to the Desktop and leaves whatever was focused there alone —
arriving somewhere shouldn't rearrange it. Dragging from an icon moves the panel as usual.

Turn the tips off with `M.showIconTips = false`, or the window-raising with
`M.iconClickFocus = false`. `M.iconTipDelay` is how long you must rest on an icon before
it names itself (0.18 s — enough that sweeping across the row doesn't flash every name).

Icons come from the live window read, so a Desktop whose name was restored from your last
session shows its old text until it's next scanned (⌘⌃⌥s, or just visit it) — the same
constraint as everything else the panel reads. If more than `M.maxAppIcons` (6) apps are
present, the rest are summarised as `+N`. Set `M.showAppIcons = false` to go back to the
words; `M.appIconGap` and `M.appIconBump` tune spacing and size.

### ⌘⌃⌥g — GitHub status, on demand

GitHub's side is a keypress away. **⌘⌃⌥g** opens a popup summarizing every repo currently
on the panel — branch, local state (how many files changed, how many commits unpushed),
GitHub state, and the last commit's date/time:

| GitHub state | meaning |
|--------------|---------|
| up to date | the remote's tip is exactly your `HEAD` |
| unpushed only | you're ahead; the remote is behind you but has nothing new |
| GitHub ahead | the remote has commits you don't have (also shown when you've diverged) |
| unreachable | no network, no `origin`, or the remote refused without credentials |

It's **on demand on purpose**: nothing hits the network until you press it, and then only
for the repos you're actually looking at. The query is a **light touch** — `git ls-remote`
reads the remote's head SHA without fetching anything or updating your local refs, so it
never changes what `git status` shows in your own terminal. It runs in the background with
a timeout (`M.githubTimeout`), so a slow remote can't wedge the panel. A "last push" time
isn't shown because git doesn't record one; the last *commit* time is what's available.

## How a Desktop gets its label

In order, first match wins:

1. **An open file inside a repo** — for editors in `M.docApps`, the document's path. The
   path names the repo, so the file is never opened or read.
2. **A claude session running on it** — its working directory, whether or not that's one
   of your repos. A session's location is a fact about the Desktop, so it beats a repo name
   that merely appears in some window's text. Only the directory counts; the session's task
   summary is deliberately ignored, since matching repo names inside prose is where every
   mislabel has come from.
3. **A repo name in a window title** — but only from titles that name a *location*. A
   terminal counts **only when it's running `claude`**; a shell that happens to be `cd`'d
   somewhere does not. Finder, browsers and chat apps never count: their titles name what
   you're *browsing* or *discussing*, which is not what the Desktop is *for*.
4. **Loose token overlap** with a repo name.
5. **The apps themselves** — shown as their **icons** ([App icons](#app-icons)). The words
   behind that row, which is what you see with icons turned off, are: one app → its name;
   several sharing a subject → that subject (`Communication`); several subjects →
   `Utility`.

## Configuration

Everything is in the `CONFIG` block at the top of `desktop_dashboard.lua`. Most likely to
need changing:

- `M.repoRoots` — folders whose subdirectories are your repos (default `~/Git_Repos`).
- `M.mode` — which view the panel opens in: `"desktops"`, `"terminals"` or `"both"`. ⌘⌃⌥m
  changes it at runtime and the choice is remembered, so this is only the first-run value.
- `M.sessionTwoLine`, `M.sessionSummaryChars`, `M.sessionSummaryIndent`, `M.sessionHeader`
  — the sessions view: whether the task summary gets its own indented line, how much of it
  is shown, how far it's indented, and the section heading in `"both"` mode.
- `M.draggable`, `M.dragThreshold` — panel dragging, and how far the mouse must move before
  a press counts as a drag rather than a click. `dd.resetPanelPosition()` re-corners it.
- `M.showClaudeDot`, `M.claudeDotColors`, `M.claudeDotSeconds`, `M.claudeStateDir` — the
  session dot.
- `M.showGitDot`, `M.gitDotColors`, `M.gitDotSeconds` — the local git status dot.
- `M.showDotPlaceholders`, `M.dotPlaceholderColor` — the gray dot that holds an empty slot
  open so the two dots stay distinguishable by position.
- `M.showAppIcons`, `M.maxAppIcons`, `M.appIconGap`, `M.appIconBump` — app icons in place
  of a `Utility`/`Communication` label.
- `M.trailingIconApps` — apps that don't decide the subject but still earn an icon at the
  end of the row (Finder; terminals come from `M.claudeOnlyHintApps`).
- `M.showIconTips`, `M.iconTipDelay`, `M.iconTipMaxChars` — the tip that names an icon
  when you point at it.
- `M.showResizeGrip`, `M.minFontSize`, `M.maxFontSize` — the corner grip that resizes the
  panel, and how far it goes.
- `M.iconClickFocus`, `M.iconFocusDelay` — whether clicking an icon raises that app's
  window as well as switching Desktops, and how long it waits for the switch to settle.
- `M.githubHotkey`, `M.githubTimeout` — the on-demand GitHub popup (⌘⌃⌥g) and how long to
  wait before killing a hung query.
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
- `M.highlightActive`, `M.activeColor`, `M.activeMarker`/`M.inactiveMarker` — how the
  Desktop you're on is marked. If you change the markers, keep them the **same rendered
  width** or that line will stop lining up with the others; `▸` happens to be exactly one
  Menlo cell, which is why the default is a caret plus two spaces against three spaces.
- `M.corner`, `M.fontSize`, `M.showLegend`, `M.legendLines` — appearance.
- `M.minWidth`/`M.maxWidth`, `M.baseFontSize` — the width bounds, in px **at
  `M.baseFontSize`**. They scale with the current size, so zooming in doesn't clip the
  right-hand end of long lines.

## Sharing across machines / with colleagues

- The code is portable; the **config is per-machine** — set `M.repoRoots` and adjust
  `M.categories`/`M.docApps` to the apps you actually use.
- **Do not sync** `~/.hammerspoon/desktop_dashboard_state.json` or `claude_state/`. Both are
  keyed to one machine's Spaces and sessions, are regenerated locally, and live outside the
  repo on purpose.
- Accessibility permission is granted per machine.

## Limitations

- macOS only lets an app read a window's details while its Desktop is active, so a Desktop
  is labeled when you first visit it (or via ⌘⌃⌥s), not before. There's no SIP-free way
  around this. **Session dots are the exception** — they come from asking Terminal for its
  window titles, which reports every Desktop, not just the visible one.
- Session dots currently require **Terminal.app**; other terminals are labeled but get no
  dot.
- The label shows in this overlay, **not** in the Mission Control thumbnail.
- Dragging a window between Desktops isn't an open/close event, so that case waits for the
  next Desktop switch or the periodic backstop.
- ⌘⌃⌥r (restore layout) is **manual and partial**: it can only move windows that are on a
  currently-visible Desktop, and can only reopen windows that have a document path. It will
  not reassemble a scattered post-reboot layout. For apps that always belong in one place,
  macOS's own Dock → Options → **Assign To** is more reliable.

See `CLAUDE.md` for the design decisions and the measurements behind them.
