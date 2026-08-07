# Desktop Dashboard

**A macOS status panel for running several Claude Code sessions at once.**

It answers one question at a glance: **what is every `claude` session on this machine doing
right now** — including the ones on Desktops you can't see. With four or five sessions
running, you otherwise have to visit each in turn to find the one that stopped to ask you
something.

It works whichever way you organise things. **⌘⌃⌥m** switches between two views, or shows
both at once.

![The Desktop Dashboard panel floating over a macOS desktop: twelve Desktops on an external display and one on a laptop display, each labelled with app icons or a project name and some carrying colored status dots, then a section listing three running Claude Code sessions, then a legend of keyboard shortcuts.](DOCS/panel.png)

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
| `Desktop 4 → 3-way analysis` + 5 icons | the same thing, but with the *project* renamed by hand (⌘⌃⌥n). Renaming replaces **only** the name — the icons still report what's actually there |
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

**A blue word in the legend is a button.** `scan`, `name`, `mode` and `GitHub` each do
exactly what their hotkey does. This exists for remote sessions — over VNC or Screen
Sharing the panel is perfectly readable but ⌘⌃⌥ never reaches the far machine, so the
hotkeys are exactly what you can't use.

Two words are deliberately *not* clickable. `hide` would be a one-way door: unhiding is the
same hotkey, so on a machine that can't press it you'd have no way back. And `restore`
moves and opens windows across every Desktop with no inverse — far too much to sit one
stray click away from the words beside it. Both stay hotkey-only. Edit `M.legendClicks` if
you disagree.

**The legend** at the bottom lists the hotkeys, and the **grip in the bottom-right corner**
resizes the whole panel — drag it out or in, everything scales together. Drag the panel
itself anywhere; each display remembers where you put it.

## Why an overlay

macOS still gives apps no API for renaming a Space's Mission Control label, so this draws
its own always-on panel instead, visible from every Desktop.

If renaming is all you're after, that's a solved problem elsewhere and you should use those
instead: [SpaceJump](https://www.getspacejump.com/) puts custom names inside Mission Control
itself (paid, one-time), and the older `spaces-renamer` did the same by injecting into the
Dock, though it needs SIP disabled and is reported broken on Apple Silicon.

This panel is doing a different job. Renaming tells you what you decided to call a Desktop;
this tells you what's *on* one and what it's *doing* right now — which repo, which apps,
whether a `claude` session there is working or waiting for you, whether the repo has
anything GitHub doesn't. That's live state, and it's scriptable, free and needs no SIP
changes.

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
- **Custom names** (⌘⌃⌥n) rename a *project*, wherever it appears, and are remembered.
- **Remembers** your view, panel position, size, Desktop names **and app icons** across
  reloads and reboots, and says how many Desktops it hasn't read first-hand yet.

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
| ⌘⌃⌥ d | Show / hide the panel **on the display your mouse is on** |
| ⌘⌃⌥ n | Rename the project this Desktop is showing |
| ⌘⌃⌥ r | Restore the saved window layout (move/open windows to match) |
| ⌘⌃⌥ s | Visit every Desktop once and label them all |
| ⌘⌃⌥ m | Cycle what the panel lists: Desktops / claude sessions / both |
| ⌘⌃⌥ g | Pop up each shown repo's GitHub status (on demand; only this hits the network) |
| Drag the panel | Move it anywhere; the position is remembered per display |

**A name you type yourself belongs to the project, not to the Desktop.** ⌘⌃⌥n renames
whatever project the line is showing — the claude session running there, or the project
whose documents are open there — and that name then reads the same *wherever* the project
appears. It travels when you move the work to another Desktop, and it goes away on its own
when the project has nothing on that Desktop any more. Press ⌘⌃⌥n on it again and submit
an **empty** name to get the repo's real name back.

On a Desktop with no session and no open document there is nothing to rename, and ⌘⌃⌥n
says so rather than naming the Desktop itself. Naming Desktops was how it worked until
`v53`, and the name outlived what it described: a Desktop kept reading `3-way analysis`
after everything on it was closed, and hid the real label from every later scan.

The session dot is unaffected by a rename — it follows the detected repo, not the name you
typed.

**Hiding is per display.** With two screens the panel is drawn on each, so ⌘⌃⌥D hides
only the one your mouse is on — press again there to bring it back, or call
`dd.showAll()`. The hidden display's Desktops are still *listed* in the panel that
remains, so you lose the panel, not the information. Which display you keep doesn't much
matter, since you can drag the survivor wherever you want it.

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

## When the session is on another Mac

The red dot solves "which Desktop wants me" for the machine you're sitting at. It can't
solve "a session on my office Mac has been blocked on a permission prompt since 9am" —
and that's the one that actually costs a morning.

The hook already fires at exactly that instant, so it can optionally also raise an alert
that **leaves the machine**. Create `~/.claude/dashboard-notify.conf` on the machine you
leave running:

```
NOTIFY_DROPBOX=1
NOTIFY_NTFY_URL="https://ntfy.sh/<a-long-random-string>"
NOTIFY_DETAIL=0
```

- **`NOTIFY_DROPBOX=1`** drops a marker into `~/Dropbox/claude/dashboard_alerts` the
  moment a session blocks, and removes it the moment you answer. Any other Mac running
  the dashboard shows a red line above the legend — `satdat1 · Desktop_Dashboard is
  waiting on you` — and posts a notification the first time it sees it. Markers from your
  *own* machine are ignored, since the dot is already saying it.
- **`NOTIFY_NTFY_URL`** pushes to your phone. `NOTIFY_PUSHOVER_TOKEN` +
  `NOTIFY_PUSHOVER_USER` do the same via Pushover.

**No config file means none of this happens** — no marker, no network call, no change in
behaviour. That's deliberate: this script runs on every prompt of every session.

**On ntfy topics:** a topic on the public `ntfy.sh` is readable by anyone who knows or
guesses its name. Use a long random one, self-host, or use Pushover, which is
account-based. The default push body is thin on purpose — hostname and repo name only.
`NOTIFY_DETAIL=1` adds the working directory and the prompt text, which is real content
leaving your machine.

**What this catches, and what it doesn't.** The `Notification` hook fires when Claude Code
*asks* — a question or a permission prompt. A session that stops some other way (an error
ending the turn, a crash, a killed terminal) never writes `waiting`, so you'd see green or
a marker aging out under `M.remoteAlertMaxAgeHours`, not red. This is a "stopped and
waiting on you" alarm, **not** a general "the job isn't running" alarm — that would need a
heartbeat, which is a different mechanism.

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
renaming the project can't change.

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

If more than `M.maxAppIcons` (6) apps are present, the rest are summarised as `+N`. Set
`M.showAppIcons = false` to go back to the words; `M.appIconGap` and `M.appIconBump` tune
spacing and size.

### Icons after a reload

Icons are saved with the Desktop names, so they come straight back when Hammerspoon
reloads — you don't have to scan to get your panel looking like itself again.

What they can't be is *current*. macOS only lets an app read the windows of the Desktop
you're actually looking at, so until you visit a Desktop (or press ⌘⌃⌥s) its row is last
session's picture. Usually that's right. Occasionally it isn't — a window that has since
been closed keeps its icon until that Desktop is read again.

So the panel tells you which ones are second-hand, just above the legend:

```
10 Desktops not read yet · click here or press ⌘⌃⌥s to read them
```

Click it and it reads them all, exactly as ⌘⌃⌥s does — which takes over your displays for
about 25 seconds, which is why it asks rather than doing it on its own. The count drops as
you visit Desktops normally, and the line disappears when nothing is left unread.

Two smaller consequences of a restored row: a restored icon has no window behind it, so
clicking it just switches to that Desktop rather than raising a particular window, and it
names only the app when you hover it. Both go back to full behaviour once the Desktop is
read. `M.showStaleHint = false` hides the line.

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

### Click "GitHub ahead" to pull

Rows that say **GitHub ahead** are clickable: one click pulls that repo. The result appears
at the bottom of the popup, and the panel's git dot updates. This is the only thing in the
tool that writes to one of your repositories.

It pulls with **`--ff-only`**, and that matters more than it sounds. "GitHub ahead" means
the remote has commits you don't — but it *also* covers the case where you have commits the
remote doesn't, and the two histories have diverged. A plain `git pull` answers that with a
merge commit: a change to your history from a single click, in a window with nowhere to
resolve a conflict. `--ff-only` takes the straightforward case — someone (probably you)
pushed from another machine — and refuses the rest, in git's own words:

```
fatal: Not possible to fast-forward, aborting.
```

Nothing has moved when you see that, and it's your cue to go and merge deliberately, in a
terminal, where you can see what you're doing. The same applies if a local edit is in the
way: git says so and the popup repeats it.

**Two things it checks before pulling** — both things git can't see, but the panel can:

*A claude session working in that repo.* Files changing under a session that's mid-task
won't destroy anything, but it leaves that session reasoning about files that no longer
say what it read. So a pull stops while the session dot is yellow:

```
Aborting the pull: a claude session is working in opendap-registry.
Wait for it to finish, or pull in a terminal.
```

A session that's merely *open* doesn't block — if it did, almost every repo would be
blocked almost all the time. `M.pullBlockOnClaude = "any"` makes it strict.

*A file the pull would change that you have open in an editor.* This is the one real way
this button could cost you work, and it isn't git's doing: your editor is holding the old
text, and your next save writes it back over what just arrived. So the pull looks at what
would change first, and stops if you have any of it open:

```
Aborting the pull: MODIS_L2 would change notes.md, which you have open.
Close it, or handle this in a terminal session.
```

Close the file and click again.

**Then it asks.** Once both checks pass you get a prompt naming what's about to happen,
so you're agreeing to something specific rather than to "a pull":

```
Pull MODIS_L2? 3 files will change: extra.txt, notes.md, run.lua.
If any of these are open in an editor, close them first — saving from an
old copy would undo the pull.
Pull · Cancel
```

Cancel changes nothing. `M.pullConfirm = false` skips the prompt.

### What to be careful about

The pull itself is safe — it's the only thing in this tool that writes to a repository, and
it only ever fast-forwards, so it cannot lose committed work or leave you in a half-merged
state. What deserves attention is everything *around* it:

**The open-file check can't see every editor.** It knows about the editors listed in
`M.docApps` — MacDown, VS Code, TeXShop, TextEdit, Preview, Word and the rest — and only
for Desktops the panel has actually read since Hammerspoon started. **Electron-based
editors are invisible to it**, because asking some apps for their open document is slow
enough to stall the whole panel, which is why `M.docApps` is an allowlist rather than
"everything". So treat a clean check as *nothing known to be open*, never as *nothing is
open*.

TeXShop used to be the notable gap here and no longer is: its `AXDocument` read was measured
at 0.10–0.23 ms — the same as MacDown and Preview — and it went on the list. That is the
procedure for any editor you want to add: **measure first**, then add.

**An idle claude session doesn't block the pull.** Only a session that's actively working
does (the yellow dot). A session sitting at a prompt is fine to pull under — it re-reads
files when it next runs — but if you'd rather be strict, `M.pullBlockOnClaude = "any"`.

**Don't save from a window you had open before the pull.** Your editor is holding the old
version of the file in memory; the pull replaces the file on disk. Save from that editor
afterwards and you write the old text back over what just arrived — undoing the pull. No
git command did it, so nothing warns you. If a file from that repo is open somewhere the
check couldn't see, close it before you save.

**Checking the remote updates your tracking refs.** To find out what would change, this
fetches — so `origin/main` moves even when you then cancel. That's normal and harmless, but
it's why the "nothing touched" promise belongs to the ⌘⌃⌥g *query* and not to this button.

**If a pull is interrupted** — it's killed after `M.pullTimeout` (2 minutes) — git very
occasionally leaves a `.git/index.lock` file behind, after which every git command in that
repo complains that another process is running. The fix is to delete that one file.

**When it refuses, believe it.** `fatal: Not possible to fast-forward` means your copy and
GitHub have both moved on, and reconciling them is a decision, not a button. Do that in a
terminal where you can see what you're merging.

**There's no push button, on purpose.** A fast-forward pull can't lose work; a push can.

`M.allowPullFromPopup = false` removes the link; `M.pullFFOnly = false` allows the merge;
`M.pullTimeout` bounds a slow fetch. One caveat worth knowing: a pull *does* fetch, so it
updates your `origin/…` tracking refs even when it declines to move your branch. The
"nothing touched" promise belongs to the ⌘⌃⌥g query, not to this button.

## How a Desktop gets its label

**A Desktop that has claude sessions is named after them, one line per project.**

Every session is placed by its *terminal window*, so it labels the Desktop that window is
actually on — not whichever Desktop happens to carry a matching folder name. Sessions in
the same project share one line, so a Desktop running three sessions in one repo stays one
line; a Desktop running two in `Desktop_Dashboard` and one in `claude-config` draws two,
both under the same `Desktop N`:

```
   Desktop 13  ● ● → AGU_2026_submission     🅜 🔵
               ● ● → MODIS_L2_Manuscript
```

Clicking one of those lines raises that project's terminal window. Where a project has
several sessions there, clicking again takes the next one. ⌘⌃⌥N on such a line renames the
**project**, and it then reads that way everywhere it appears — as it does on every other
kind of line too, since a name always belongs to a project rather than to a Desktop.

**A Desktop with no session is named after the projects whose documents are open on it**,
in plain white.

That means *"still set up for this — come back and restart it"*: you exited claude but left
the documents open, and tomorrow this is how you find your way back. **An open document is
the only evidence.** A Finder window parked in the repo does not count — moving Finder from
one project to another is a keystroke — and neither does a repo name appearing in some
window's title, which usually means you were *talking* about it. Windows are counted, and
the **two** projects with the most are shown, joined with ` / `. Such a line carries **no
dots at all**: there is no session on it, and a dot would say there was.

Only the apps in `M.docApps` report an open document, so that list is exactly the set that
can name a Desktop this way. **A key there is the app's name as macOS reports it, and a
wrong one fails silently** — the app is simply never asked, so it never names anything. If
an editor you use never names a Desktop, check its spelling there first: `MacDown` sat in
the list as `MacDown 3000` from the first release until `v53`.

**Failing both**, it is named after **the apps themselves** — shown as their
**icons** ([App icons](#app-icons)). The words behind that row, which is what you see with
icons turned off, are: one app → its name; several sharing a subject → that subject
(`Communication`); several subjects → `Utility`.

Two things to know before you wonder why a line is missing:

- **Desktop lines come from Terminal.app and iTerm2.** Placing a session on a Desktop needs
  its window, and those two are the terminals that will report their windows for Spaces you
  aren't looking at. A session in Ghostty, kitty or Cursor's built-in terminal still appears
  in the `T#` list — see **Sessions elsewhere** below — but with no Desktop attached.
- A **minimized** terminal window reports no Desktop, so its session gets no Desktop line.
  It still appears in the `T#` sessions view.

### Sessions elsewhere

A session in a terminal the poll can't read — VS Code, Cursor, Ghostty, kitty — is drawn from
its **hook state file** instead, which Claude Code writes from inside the session whatever it
is running in.

**If it runs inside an editor, it gets a Desktop line anyway.** The session's file says which
project it's in and which terminal it's running under; `M.termApps` maps that terminal to an
app (`vscode` → `Code`); and a window of that app whose *title* names that project is where
the session lives. So `claude` in VS Code's built-in terminal shows up as

```
   Desktop 8 ● ● → opendap-registry  · vscode
```

on the Desktop that window is on, like any other session. If two windows on different
Desktops could match, it says nothing rather than guessing, and falls back to the list below.
This is the **only** thing a window title is ever read for — identifying which window holds a
session whose directory is already known. Nothing on the panel is ever *named* from a title. You get the project,
the dot, what it's asking, and the name of the terminal it's in:

```
   T4 ● ● MODIS_L2_Manuscript  · Cursor
             May I edit orbit_rea…
```

What you don't get is a Desktop, and that's deliberate: a hook file knows the repo, not the
window, so claiming a Desktop would be a guess dressed up as a reading. These lines appear
even in Desktops mode, in their own `Sessions elsewhere:` block — a session you can't see
isn't less urgent because of which view you're in.

The state behind them is if anything *better* than a Terminal session's: the hook records
"waiting" at the moment Claude Code asks, where the Terminal path has to infer it from a
spinner glyph. **This needs the hook installed** (see below); without it there are no lines
for non-Terminal sessions at all. Turn the whole thing off with `M.showHookSessions = false`.

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
- `M.allowPullFromPopup`, `M.pullFFOnly`, `M.pullTimeout` — clicking "GitHub ahead" to pull
  that repo, whether a non-fast-forward merge is allowed, and how long a pull may take.
- `M.pullBlockOnClaude` (`"working"` / `"any"` / `false`), `M.pullBlockOnOpenFiles` — the
  two checks made before a pull: a busy claude session in that repo, and a file the pull
  would change being open in an editor.
- `M.pullConfirm` — the prompt that names what a pull will change before it does it.
- `M.claudeOnlyHintApps` / `M.claudeTitleMarker` — terminals whose titles count as a repo
  hint only while running claude. Add your terminal if it isn't listed.
- `M.docApps` — apps asked for their open file's path. **Keep slow apps
  (Electron/Office/Java) out** — asking them can stall for minutes.
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
- `M.showStaleHint` — the clickable line counting Desktops not yet read first-hand.
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

## Under the hood

`DECISIONS.md` holds all 64 design rulings and the measurements behind them — why the
dot has two colours and not three, why the pull is `--ff-only`, why an icon needs an
invisible rectangle laid over it. `CLAUDE.md` is the architecture and the layout.
