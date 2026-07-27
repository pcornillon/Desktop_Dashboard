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

### 4. Licensed and published

MIT `LICENSE` added (copyright Peter Cornillon, 2026). Pushed public to
<https://github.com/pcornillon/Desktop_Dashboard>, `main` tracking `origin/main`.

Before publishing, the committed files were scanned for credentials and for hardcoded
home paths: none. The Lua resolves paths through `os.getenv("HOME")` rather than
embedding a username. What the repo does reveal is ordinary working-setup detail — the
`CONFIG` block names the apps in use and assumes repos live under `~/Git_Repos`.

## Pending

- **Live verification (manual, MOVING.md step 3).** This is a live-GUI tool and cannot
  be verified headless, so it remains unconfirmed. Outstanding: Accessibility enabled
  for Hammerspoon → Reload Config → Console prints
  `desktop_dashboard v16 (rescan repo roots; case-insensitive repo paths, 2026-07-27) loaded`
  → ⌘⌃⌥S labels every Desktop, and this repo's own Desktop reads `Desktop_Dashboard`.

## Bug found during migration (fixed in v16)

Creating this repo surfaced a real defect: the Desktop running `claude` in
`~/Git_Repos/Desktop_Dashboard` showed `—`, and with `MOVING.md` open in MacDown it
showed the app name instead of the repo.

Two independent causes, both now fixed:

1. **`loadRepos()` ran exactly once, in `start()`.** Hammerspoon loaded its config at
   15:44; the `Desktop_Dashboard` directory was created at 17:02. The repo therefore
   never entered the `repos` list, so detection rules 2 (repo name in a window title)
   and 3 (token overlap) could not match it no matter what the titles said — the
   Terminal title was literally
   `Desktop_Dashboard — … claude — 254×64`. Any repo created after launch was invisible
   until the next Reload Config. Now `refreshRepos()` re-lists the roots on a
   `M.repoRescanSeconds` (30 s) TTL from `scanActive()`, and ⌘⌃⌥S always re-reads.
2. **`repoForPath()` compared paths case-sensitively.** This is why rule 1 (open
   document inside a repo) also missed. The stale `~/.hammerspoon` copy had
   `repoRoots = ~/Git_repos`; `hs.fs.dir` accepted it on the case-insensitive volume,
   but the `AXDocument` path `/Users/…/Git_Repos/…` never prefix-matched. The comparison
   is now case-insensitive, with the repo segment sliced off the original path so its
   true casing is preserved.

Cause 1 is the one that bit; cause 2 was latent in the repo copy (whose casing is
correct) and would have bitten on any machine whose `repoRoots` casing drifted.

## Not done (deliberately)

The optional items at the end of `MOVING.md` — per-machine config split, current-Desktop
marker, window counts per Desktop, watching window moves between Spaces, README
screenshot. All require asking first.

## Backups

The two original `~/.hammerspoon` files (pre-change `desktop_dashboard.lua` and
`init.lua`) were copied to the session scratchpad before being modified. That directory
is temporary — if the reload verifies clean, nothing needs to be recovered from it.
