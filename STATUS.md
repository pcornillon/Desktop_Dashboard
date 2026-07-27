# STATUS.md — repo migration record

One-time record of the `MOVING.md` migration: turning the working
`desktop_dashboard.lua` into a git repo. Written 2026-07-27.

Day-to-day install lives in `INSTALL.md`; design rationale in `CLAUDE.md`.

## Done

### 1. Repository initialized

```sh
git init -b main     # main, not master
git add .
git commit -m "Import Desktop Dashboard (working v15)"
```

Initial commit `8ec045a` — 7 files, 1047 lines:
`desktop_dashboard.lua`, `README.md`, `INSTALL.md`, `CLAUDE.md`, `MOVING.md`,
`init.lua.example`, `.gitignore`.

`.DS_Store` was present in the directory and was correctly excluded by `.gitignore`.
No `desktop_dashboard_state.json` / `desktop_dashboard_names.json` entered the repo —
both live in `~/.hammerspoon`, outside it, as intended.

### 2. Single source of truth established

A stale copy sat at `~/.hammerspoon/desktop_dashboard.lua` and was the file actually
being loaded. It was the same `M.version` (v15) but older by half an hour, and it
carried a bug the repo copy does not:

```lua
os.getenv("HOME") .. "/Git_repos",     -- stale copy: lowercase r
os.getenv("HOME") .. "/Git_Repos",     -- repo copy:  matches the real directory
```

macOS is normally case-insensitive so both resolved, but the repo copy is the correct
one. The stale file was removed.

### 3. Hammerspoon rewired to the repo

`~/.hammerspoon/init.lua` had no `package.path` line — it was resolving
`require("desktop_dashboard")` against `~/.hammerspoon` itself, which is why the stale
copy won. It now matches `init.lua.example`:

```lua
package.path = package.path .. ";" .. os.getenv("HOME") .. "/Git_Repos/Desktop_Dashboard/?.lua"

local dd = require("desktop_dashboard")
dd.start()
```

Removing the stale copy without this change would have broken the load, so the two
went together.

## Pending

- **Live verification (manual, MOVING.md step 3).** This is a live-GUI tool and cannot
  be verified headless. Outstanding: Accessibility enabled for Hammerspoon → Reload
  Config → Console prints
  `desktop_dashboard v15 (auto-refresh on window changes, 2026-07-27) loaded` → ⌘⌃⌥S
  labels every Desktop. If repo detection misbehaves after the reload, the
  `Git_repos` → `Git_Repos` casing change above is the first thing to check.
- **Remote.** Not yet created. Host and visibility are the user's call.
- **`LICENSE`.** Not added. MIT is `MOVING.md`'s suggested default for sharing.

## Not done (deliberately)

The optional items at the end of `MOVING.md` — per-machine config split, current-Desktop
marker, window counts per Desktop, watching window moves between Spaces, README
screenshot. All require asking first.

## Backups

The two original `~/.hammerspoon` files (pre-change `desktop_dashboard.lua` and
`init.lua`) were copied to the session scratchpad before being modified. That directory
is temporary — if the reload verifies clean, nothing needs to be recovered from it.
