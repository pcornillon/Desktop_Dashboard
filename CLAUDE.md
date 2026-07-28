# CLAUDE.md — Desktop Dashboard

Context for AI coding sessions on this repo. Read this before changing
`desktop_dashboard.lua`. `README.md` is the user‑facing install/usage doc; this file
is the *why*.

## What this project is

A single‑file [Hammerspoon](https://www.hammerspoon.org) tool (`desktop_dashboard.lua`)
that draws an always‑on overlay listing every macOS Space ("Desktop") and a label for
each — the repo it's focused on, or the app/subject of its windows — and lets you click
a line to switch Desktops. It exists because macOS has no supported API to rename a
Space's Mission Control label; the overlay delivers the same information without touching
System Integrity Protection.

The module returns a table `M` with a `CONFIG` block at the top and `M.start()` /
`M.stop()`. `~/.hammerspoon/init.lua` loads it via `require` and calls `dd.start()`.

## Architecture (one file)

- **CONFIG** — repo roots, app→subject maps, `docApps` allowlist, appearance, hotkeys,
  legend. All user‑tunable.
- **Detection** — `snapshot()` builds the on‑screen window list ONCE and indexes it by
  window id; `readSpaceFrom(byId, sid)` picks out the windows on a Space;
  `detectLabel(funcs, ctx)` decides the label.
- **Drawing** — `draw()` renders one `hs.canvas` per screen, `canJoinAllSpaces` so it
  shows everywhere; clickable per‑Desktop lines; a status line during scans; a legend.
- **Reads** — `scanActive()` (visible Desktops), `M.scanAll()` (⌘⌃⌥S, walks all),
  event‑driven refresh via an `hs.window.filter` on create/destroy (debounced), plus a
  space watcher, screen watcher, and a periodic backstop timer.
- **Persistence** — `M.saveLayout()` writes names + window lists to
  `~/.hammerspoon/desktop_dashboard_state.json` keyed by screen + Desktop position;
  `restoreNames()` reloads names on launch; `M.restoreLayout()` (⌘⌃⌥R) moves/opens
  windows to match a saved layout (best effort).
- `M.version` is printed on load — bump it on every change so a stale file is obvious.

## Detection order (repo first, then apps)

`detectLabel(funcs, ctx)`:

1. **Repo by document path** — for editor windows (`docApps`), read the open file's path;
   if it's under a repo root, the repo folder name is the label. The path itself names
   the repo, so we do NOT open or read the file.
2. **Repo by title hint** — a repo name appearing in ANY window title on the Desktop,
   including the `claude` terminal's title or a Finder window parked in the repo.
3. **Repo by token overlap** — looser fallback.
4. **App / subject** — no repo found:
   - one app → that app's own name (`Mail`);
   - two or more apps sharing one subject → the subject (`Communication`);
   - two or more different subjects → `Utility`.

`funcs` excludes Finder/Terminal (they don't decide the subject); `ctx` includes their
titles (so Finder/Terminal still contribute repo hints), but excludes the titles of
`noRepoHintApps` (see below).

## Key decisions and why

- **Overlay, not renaming.** macOS has no API to change a Space's Mission Control label.
  The only ways are `spaces-renamer` (needs SIP disabled — a Recovery‑Mode reboot and a
  security downgrade) or SpaceJump (paid, no scripting hook). An overlay is free, SIP‑free,
  and fully scriptable. Consequence: the name shows in our panel / menu‑bar‑style overlay,
  not in the Mission Control thumbnail.
- **Hammerspoon as runtime.** Free, notarized, no SIP, and exposes `hs.spaces`,
  `hs.window`, `hs.canvas`, and space/window watchers — everything needed.
- **Read a Desktop only while it's active.** macOS Accessibility cannot read the windows
  of a Space you're not viewing. So detection reads the visible Space(s); ⌘⌃⌥S walks all
  Spaces to fill them in. Passive "read every Space without visiting" was tried and does
  not work without SIP‑off — do not reintroduce it.
- **One `allWindows()` snapshot per read; never `hs.window.get()` per id.** THE
  performance fix. `hs.window.get(id)` rebuilds the entire window list on every call
  (~40 ms each, measured), so per‑window calls multiplied into multi‑minute freezes.
  `snapshot()` calls `hs.window.allWindows()` once and indexes by id; per‑Desktop reads
  are then hash lookups. If you touch the read path, keep it to one enumeration per read.
- **Only ask `docApps` for a file path.** Reading `AXDocument` from Electron/Office/Java
  apps (Slack, OneNote, Teams, MATLAB, …) can stall for minutes. The `docApps` allowlist
  restricts that slow call to real editors (MacDown, VS Code, CLion, Preview, …).
  Everything else is labeled by name only. Do not add slow apps to `docApps`.
- **Ignore Finder/Terminal for the subject, but use their titles as repo hints.** A
  Desktop's *subject* shouldn't be "Finder", but a `claude` terminal or a Finder window
  sitting in a repo is a strong, cheap signal of *which repo* — so their titles feed the
  repo hint only.
- **A title names a location or a subject, and only the first is a repo hint.** A
  Terminal running `claude` in a repo puts the *working directory* in its title — that
  really does say which repo the Desktop is for. A browser puts a *page title* there
  (`pcornillon/Desktop_Dashboard · GitHub`), and a chat app puts a *conversation name*;
  both can contain a repo name purely as subject matter. Rule 2 cannot tell those apart
  on text alone, so `M.noRepoHintApps` draws the line by app. Members still count toward
  the subject (unlike `ignoreApps`); only their titles are withheld from `ctx`.
- **Rule 2 matches a repo name anywhere in a title, including inside a filename that is
  not in the repo.** Measured case: two windows open in TeXShop titled
  `desktop_dashboard_17.lua` / `_18.lua` — both files sitting in `~/.Trash` — kept
  relabeling their Desktop `Desktop_Dashboard`. Nothing in the title text distinguishes
  "a file belonging to this repo" from "a file whose name resembles this repo", and the
  editor was not in `docApps`, so no real path was available to check. If you tighten
  this, do it with a path (rule 1), not by pattern-matching the title harder. Until
  then, a mixed Desktop like that is what ⌘⌃⌥N manual naming is for.
- **`M.appLabels` renames the single-app case.** Rule 4 returns the bare process name
  when one app owns the Desktop, which makes `Claude` ambiguous with `claude` in a
  terminal; the override displays `Claude Chat/Cowork`. Categories can't do this — a
  category is only shown when it groups two or more apps. Note this applies *only* when
  a single app is present; a Desktop that also holds an editor and Stickies resolves to
  `Utility` by rule 4 long before `appLabels` is consulted.
- **Re-list the repo roots on a timer.** `loadRepos()` originally ran once in `start()`,
  so a repo created after Hammerspoon loaded its config was invisible to rules 2 and 3
  until the next Reload Config — the Desktop showed `—` or a bare app name however
  clearly its titles named the repo. `refreshRepos()` re-lists on an
  `M.repoRescanSeconds` TTL from `scanActive()`; ⌘⌃⌥S always reloads. A dir listing plus
  a stat per entry is negligible next to the `allWindows()` call each read already pays.
- **Compare repo paths case-insensitively.** macOS volumes are normally
  case-insensitive, so a `repoRoots` entry of `~/Git_repos` lists `~/Git_Repos` happily
  via `hs.fs.dir` but never prefix-matches the real `AXDocument` path — rule 1 fails
  silently while the repo list looks fine. Slice the repo segment off the original path
  so its true casing survives.
- **The claude dot has two colors because the signal has two states.** Claude Code puts
  an animated Braille spinner (U+2800–U+28FF) in the terminal title while computing and
  `✳` (U+2733) when not. Measured 2026-07-28 over ~750 one-second samples across three
  live sessions, including a deliberately blocked one: a session **waiting on a user
  question shows the same `✳` as a finished one**. The title encodes whether work is
  happening, never why it stopped, so "needs you" is not derivable and there is no red
  dot. Do not add one by guessing — if a marker appears in a future Claude Code release,
  verify it the same way before wiring it to `M.claudeDotColors`.
- **Read the dot's state from Terminal's AppleScript, not Accessibility.** Terminal
  reports titles for windows on ALL Spaces, so the dot stays correct for Desktops you are
  not viewing — the one place this tool escapes the "only the active Space is readable"
  constraint. Matching the title's cwd component against the Desktop's repo label avoids
  needing any window-to-Space mapping.
- **That AppleScript call must stay asynchronous.** It runs through `hs.task`. Measured:
  the same query issued synchronously blocked long enough to time out Hammerspoon's own
  IPC — precisely the class of stall that `docApps` and the single-snapshot rule exist to
  prevent. Redraw only when a dot actually changed; `draw()` rebuilds every canvas.
- **Single app → app name; shared subject → category.** A category should only appear
  when it's actually grouping more than one app. `Mail` alone is `Mail`; `Mail` + `Slack`
  is `Communication`.
- **Manual names are overrides.** ⌘⌃⌥N sets a name that wins over auto‑detection; blank
  clears it. Kept by Space ID in‑session (so reordering Desktops moves names with their
  Space) and by screen+position on disk (so they survive a reboot, since Space IDs don't).
- **Event‑driven refresh, debounced.** An `hs.window.filter` on create/destroy triggers a
  refresh ~0.8 s after changes settle. Cheap now that reads are single‑snapshot; it just
  schedules the fast read.
- **Deferred first scan on launch.** `start()` draws immediately and schedules the first
  read 1.5 s later, so a slow read can never freeze Hammerspoon during config load.
- **Version stamp.** Every build sets `M.version` and prints it on load. Added after a
  stale‑file mix‑up (a copy saved as `desktop_dashboard_11.lua` meant `require` kept
  loading old code). Bump it on every change.

## Gotchas for future work

- `~/.hammerspoon` is Hammerspoon's load path; the repo is elsewhere. `init.lua` bridges
  the two via `package.path` (see README). Don't assume the code is in `~/.hammerspoon`.
- The state JSON is machine‑specific and lives in `~/.hammerspoon`, outside the repo.
  Don't commit it; don't sync it between machines.
- `hs.window.allWindows()` returns only the *current* Spaces' windows (per display) — by
  design; that's why reads are per active Space.
- Space IDs are stable within a login session but change on reboot; anything persisted
  across reboots is keyed by screen + position instead.
- Config is user‑specific: `repoRoots`, and app names like `"MacDown 3000"`.

## Testing

There's no automated suite (it's live‑GUI behavior). To sanity‑check a change: Reload
Config, confirm the `vNN loaded` line, press ⌘⌃⌥S, then open/close a repo file and a
non‑repo app on a Desktop and confirm the label updates within ~1 s. If a Desktop stalls,
the per‑app / per‑window timing probes in the project history are the way to pinpoint the
slow call — the culprit is almost always a slow Accessibility read of one app.
