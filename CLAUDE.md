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

`funcs` excludes Finder/Terminal (they don't decide the subject); `ctx` includes ALL
titles (so Finder/Terminal still contribute repo hints).

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
