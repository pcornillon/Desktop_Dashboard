# CLAUDE.md — Desktop Dashboard

**What:** a Hammerspoon overlay panel reporting live macOS Desktop, Claude-session and
git state.
**Produces:** `desktop_dashboard.lua` — a single-file tool loaded from
`~/.hammerspoon/init.lua` — plus `claude-dashboard-state.sh`, its Claude Code hook.
**State:** v57, working and in daily use; see `STATUS.md`.

Context for AI coding sessions on this repo. Read this before changing
`desktop_dashboard.lua`. `README.md` is the user-facing install/usage doc; **`DECISIONS.md`
is the *why*, and it is the file to read before you change behaviour** — every measured
design ruling lives there as a numbered `D##`.

**Read in this order before starting work:**

| File | What it holds |
|------|---------------|
| `CLAUDE.md` (this file) | what the project is, the architecture, the layout |
| `STATUS.md` | where things stand right now, ending in the **active thread** |
| `LOG.md` | one line per prompt — scan this to see what has been done |
| `DECISIONS.md` | **D1–D82** — every design ruling and the measurement behind it |
| `TASKS.md` | the work list: numbered tasks with `Status:` lines |

## What this project is

A single-file [Hammerspoon](https://www.hammerspoon.org) tool (`desktop_dashboard.lua`)
that draws an always-on overlay listing every macOS Space ("Desktop") and a label for
each — the repo it is focused on, or the app/subject of its windows — and lets you click a
line to switch Desktops. It also reports, per line, whether a `claude` session there is
working / waiting / finished, and whether that repo has anything GitHub does not.

It exists because macOS has no supported API to rename a Space's Mission Control label,
and because no renamer reports live state anyway (**D1**). The overlay delivers the
information without touching System Integrity Protection.

The module returns a table `M` with a `CONFIG` block at the top and `M.start()` /
`M.stop()`. `~/.hammerspoon/init.lua` loads it via `require` and calls `dd.start()`.

## Layout

```
CLAUDE.md               this file — project context, architecture, layout
STATUS.md               where things stand + active thread
DECISIONS.md            D1–D82 — every design ruling, with its measurement
TASKS.md                numbered work list with Status: lines
LOG.md                  append-only one-line-per-prompt index
README.md               human-facing overview, controls, config, limitations
INSTALL.md              how to install on a machine, and the optional hook setup

desktop_dashboard.lua   THE TOOL — single file, CONFIG block at top, returns M
claude-dashboard-state.sh   the Claude Code hook that makes the red dot possible
init.lua.example        the loader line for ~/.hammerspoon/init.lua
LICENSE

SESSIONS/               curated session logs, one per session, P## per prompt
DOCS/                   panel.png — the screenshot README.md is built around
PRE_CONVERSION/         the one-time 2026-07-27 repo-migration record (D63)
LATEX/                  empty — no manuscript here
ISSUE_ANALYSES/         hook_without_jq/ — why a colleague's Mac showed nothing
                        Python/test_claude_dashboard_hook.py — the hook's test suite
```

**The code stays at the top level and does not move into a spine folder (D64).**
`~/.hammerspoon/init.lua` points `require` at `desktop_dashboard.lua` by path, and
`~/.claude/settings.json` names `claude-dashboard-state.sh` by path on four hook
registrations. Moving either silently breaks a live installation.

**The empty spine folders are deliberate.** A constant shape across projects costs
nothing and a varying one costs time on every switch; an empty `LATEX/` says "no
manuscript here", which is information.

## Architecture (one file)

- **CONFIG** — repo roots, app→subject maps, the `docApps` allowlist, appearance,
  hotkeys, legend. All user-tunable; documented in `README.md`.
- **Detection** — `snapshot()` builds the on-screen window list **once** and indexes it by
  window id (**D4**, the performance fix); `readSpaceFrom(byId, sid)` picks out the windows
  on a Space; `detectLabel(funcs, claudeCwd, projHits)` decides the label and returns the KIND of evidence
  behind it (**D40**).
- **Drawing** — `draw()` renders one `hs.canvas` per screen, `canJoinAllSpaces` so it shows
  everywhere; clickable per-Desktop lines; a status line during scans; a legend.
  **`draw()` deletes and rebuilds every canvas**, which is the root of several rules
  (D42, D49, D55).
- **Reads** — `scanActive()` (visible Desktops), `M.scanAll()` (⌘⌃⌥s, walks all),
  event-driven refresh via an `hs.window.filter` on create/destroy (debounced, **D60**),
  plus a space watcher, screen watcher, and a periodic backstop timer.
- **Dots** — `refreshClaudeStates()` (session dot, from Terminal titles + hook files) and
  `refreshGitStates()` (git dot, local `git` status for every repo) both run async via
  `hs.task` on their own timers (**D25**, **D27**). `M.scanGitHub()` (⌘⌃⌥g) is the
  on-demand GitHub popup — `git ls-remote` for the shown repos, rendered in an
  `hs.webview` (**D29**).
- **Persistence** — `M.saveLayout()` writes names, icon rows and window lists to
  `~/.hammerspoon/desktop_dashboard_state.json` keyed by screen + Desktop position
  (**D16**, **D44**); `restoreNames()` reloads on launch; `M.restoreLayout()` (⌘⌃⌥r)
  moves/opens windows to match a saved layout (best effort).
- `M.version` is printed on load — **bump it on every change** so a stale file is obvious
  (**D62**).

## What names a Desktop (D67)

**Sessions first, and by window — not by name.** Each claude session is tied to the Desktop
its terminal window is on, via `hs.spaces.windowSpaces` (2.9 ms for 13 windows, and it
answers for Spaces that are not active). `sessionGroupsFor(sid)` then collapses those
sessions **one group per project**, so a Desktop running three sessions in two repos draws
two lines under one `Desktop N`, and a Desktop running three in one repo draws one.

A Desktop with at least one session shows **only** those lines. Its dots are that group's:
yellow if any of its sessions is computing, red if the hooks say the repo wants you, green
if one finished unseen.

**⌘⌃⌥N renames a project, never a Desktop (D76).** On a session line it is that group's
project; on a Desktop with no session it is the top-ranked project whose documents are open
there; on a Desktop with neither it refuses and says why. The name is stored against the
project, so it reads the same wherever the project appears and leaves a Desktop as soon as
the project does. **There is no per-Desktop override any more** — `overrides`, its `manual`
flag on disk and its restore path are gone with D16, because that name outlived the windows
it described and hid every later reading from the panel.

**Otherwise `detectLabel(funcs, claudeCwd, projHits)` decides**, and the first rule is a
count rather than a match:

1. **The projects whose DOCUMENTS are open here**, ranked by how many windows each has, at
   most `M.maxProjects` (2), joined with ` / `. Attribution is per window, by
   `projectOfWindow`, and an open document under a repo root is the **only** evidence it
   accepts (**D75**) — `docApps` only (**D5**), compared case-insensitively (**D12**).
2. *(rule 1.5)* **A claude session's working directory**, for a session whose window could
   not be placed on a Desktop — a minimized terminal.
3. **App / subject** — one app → that app's own name; two or more sharing a subject → the
   subject; two or more subjects → `Utility` (**D15**). With icons on, this row is drawn as
   icons rather than words (**D40**).

**A name from a document means "still set up for this project", not "running"** — you
exited claude and left the documents open, and it is how you find your way back tomorrow.
It is drawn in plain white like everything else that is not live, and **carries no dots at
all**, since a dot there would read as a session.

**There is no rule that reads a window's title any more.** A Finder window parked in a repo,
a repo name in a mail subject or a Slack channel, and the loose token-overlap match are all
gone with `M.noRepoHintApps` and the `ctx` machinery that fed them (**D75**, superseding
**D8**/**D9** and restoring **D7** in effect). `funcs` still excludes Finder and terminals
from the subject (**D6**), and `claudeOnlyHintApps` survives for the icon row and for
recognising a session's own window.

**Two limits worth knowing before you debug a missing line.** The session poll reads
**Terminal.app and iTerm2** (D82) — both have an AppleScript dictionary that reports windows
on Spaces you are not looking at, and a window id `hs.spaces` accepts, which are the two
things a Desktop line needs. Any other terminal (Ghostty, kitty, Cursor's built-in) gets a
**`T#` line from its hook state file instead, with no Desktop** (D81); Cursor cannot do
better, being Electron with no usable dictionary. And a minimized session window reports no
Space, so it gets no Desktop line either — it is still in the `T#` list, which is keyed by
window.

## Where the design rulings live

They are **not** in this file. `DECISIONS.md` holds all 82, with the measurements intact —
the ~40 ms `hs.window.get` cost, the 750-sample dot study, the Menlo 13 glyph widths, the
observation dates. The ones most likely to be violated by accident:

| If you are touching… | Read first |
|---|---|
| the read path | **D4** (one snapshot per read), **D5** (`docApps` allowlist), **D3** (active Space only) |
| label detection | **D67** first — it rewrote what names a Desktop; then **D7**–**D9**, **D13**, four false positives from matching repo names in free text |
| naming by hand (⌘⌃⌥N) | **D76** — a name belongs to a project, never to a Desktop; it supersedes **D16** |
| the claude dot | **D67** (a session belongs to the Desktop its WINDOW is on), then **D17**–**D19** — what the terminal title can and cannot tell you |
| the session poll | **D82** (Terminal + iTerm, and the two measurements a third terminal would have to pass), **D81** (everything else, from its hook file) |
| the ⌘⌃⌥g pull | **D30**–**D36** — the only code here that writes to a repository |
| drawing / icons | **D40**–**D59**, and **D68**–**D71** for the clickable legend |

## Gotchas for future work

These are platform facts rather than choices, which is why they are here and not in
`DECISIONS.md`.

- **A guarded dependency in the hook is worse than no dependency.** `command -v jq` around
  every call meant a machine without `jq` wrote no state file and exited 0 — the red dot
  never lit and nothing anywhere said why (**D80**, now `awk` only). The same shape would
  hide any tool you reach for there: the hook must never fail loudly, so it will hide a
  missing tool for ever unless it has none.
- **The deployed hook is a DIFFERENT FILE from this repo's copy.** `~/.claude/settings.json`
  runs `~/Git_Repos/claude-config/hooks/claude-dashboard-state.sh`. Editing the copy here
  changes nothing until it is copied there and `diff`ed. This has caught two sessions now —
  it is what Task #1 was opened for.
- **A wrong key in `M.docApps` fails silently and for ever.** The key must be the app's own
  name as macOS reports it — check it against `hs.application.runningApplications()`, not
  against the menu bar or the `.app` filename, and not against `CFBundleName` either
  (Word's is `Word`, Chrome's is `Chrome`). A key that matches nothing means that app is
  never asked for its document, so it can never name a Desktop; there is no warning, and
  the Desktop just falls through to its icon row. `["MacDown 3000"]` was in the list from
  the first commit and cost nothing visible until **D75** made a document the *only*
  evidence — then MacDown, the editor Peter reads every `.md` in, stopped naming anything.
  **Symptom to recognise:** one particular editor never names a Desktop while others do.
- **Keep a live reference to any `hs.timer.doAfter` whose callback must run.** A pending
  timer with nothing referencing it can be garbage-collected before it fires — no error,
  no log, it just never happens. The ⌘⌃⌥s walk chains one `doAfter` per Desktop, and with
  no reference held it **died at a different Desktop every run (observed: #1, #5, #6,
  #9)**. It surfaced only once the claude dot began allocating on a 3 s timer, which
  raised GC pressure enough to collect the pending step mid-walk. `scanTimer` holds it now.
  **Symptom to recognise:** `M.status` frozen part-way, `scanningAll` stuck true, console
  completely clean.
- **`hs.task` deadlocks on more than ~512 bytes of output** unless you give it a streaming
  callback. Hammerspoon does not drain the child's stdout until the child exits, and a
  macOS pipe starts with a 512-byte buffer, so the child blocks for ever inside `exit()`
  and its termination callback never fires — taking the in-flight guard above it with it.
  It is worse than that: `hs.task` also **splits its output between its streaming and
  termination callbacks**, and **drops any chunk that ends inside a multi-byte character** —
  routine here, where titles carry `—`, `✳`, `⠂` and `×`. **Never call `hs.task.new`
  directly; use `runTask`**, which captures to a file and times out (**D65**, **D66**, where
  the measurements are). **Symptom to recognise:** a dot column that stops
  updating and never recovers, an `osascript` or `sh` child of Hammerspoon with an
  implausible elapsed time in `ps`, and a console that says nothing at all.
- **`hs.spaces` queries throw rather than return nil.** `windowsForSpace`,
  `spacesForScreen` and `activeSpaceOnScreen` reach through the Dock's accessibility
  element and raise when that lookup transiently fails ("Unable to fetch
  NSRunningApplication for pid: …"). **`x or {}` cannot catch it.** Use
  `safeWindowsForSpace` / `safeSpacesForScreen` / `safeActiveSpace`. A failed read returns
  nil and callers keep the previous label — blanking a Desktop to `—` because one read
  glitched is worse than a stale name.
- `~/.hammerspoon` is Hammerspoon's load path; the repo is elsewhere. `init.lua` bridges
  the two via `package.path` (see `INSTALL.md`). **Don't assume the code is in
  `~/.hammerspoon`**, and don't "fix" this by copying the `.lua` there — that is how the
  stale-copy bug of 2026-07-27 happened (`PRE_CONVERSION/STATUS.md`).
- The state JSON is machine-specific and lives in `~/.hammerspoon`, outside the repo.
  Don't commit it; don't sync it between machines.
- `hs.window.allWindows()` returns only the *current* Spaces' windows (per display) — by
  design; that is why reads are per active Space (**D3**).
- Space IDs are stable within a login session but change on reboot; anything persisted
  across reboots is keyed by screen + position instead (**D16**).
- Config is user-specific: `repoRoots`, and app names like `"MacDown 3000"`.

## Testing

**You can photograph the panel from a session**, which makes "does it draw" checkable
rather than a question for whoever is at the machine:

```lua
-- the panel is a layer-3 CoreGraphics window owned by Hammerspoon
hs.window.snapshotForID(<its kCGWindowNumber>, true):saveToFile("/tmp/panel.png")
```

Find the id in `hs.window.list(true)`, taking the largest layer-3 Hammerspoon window.
**`hs.screen:snapshot()` does NOT work** — it returns the desktop with our canvases missing,
which reads as "the panel isn't drawing" when it is. Found 2026-08-06 verifying D81.

There is no automated suite for the Lua — it is live-GUI behaviour. The **hook** does have
one: `python3 ISSUE_ANALYSES/Python/test_claude_dashboard_hook.py`, which runs it with `jq`
off the PATH (D80). To sanity-check a change: Reload
Config, confirm the `vNN loaded` line, press ⌘⌃⌥s, then open/close a repo file and a
non-repo app on a Desktop and confirm the label updates within ~1 s. If a Desktop stalls,
the per-app / per-window timing probes in the project history are the way to pinpoint the
slow call — **the culprit is almost always a slow Accessibility read of one app** (D5).

`INSTALL.md` carries a test prompt that exercises all three dot colours on cue.
