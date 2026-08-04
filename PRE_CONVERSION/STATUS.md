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
  `desktop_dashboard v18 (chat apps and browsers are not repo hints, 2026-07-27) loaded`
  → ⌘⌃⌥S labels every Desktop.

  Partly verified live via `hs.ipc` on 2026-07-27: v18 is loaded, iMac Desktop 1 reads
  `Claude Chat/Cowork`, and Built-in Display Desktop 10 auto-detects `Desktop_Dashboard`
  (confirming the v16 fix). Not verified: that the panel renders correctly on screen and
  that click-to-switch still works — those need eyes on the display.

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

## Correction to v17, and what was really wrong (v18)

v17 was built on an assumption that live inspection disproved. Enabling `hs.ipc` in
`~/.hammerspoon/init.lua` made it possible to query the running instance, and iMac
Desktop 1 (space 441) actually holds:

| app | window title |
|---|---|
| TeXShop | `desktop_dashboard_17.lua` |
| TeXShop | `desktop_dashboard_18.lua` |
| Claude | `Claude` |
| TextEdit | `init.lua` |
| Finder | `Applications` |
| Stickies | `After many many years of service, URI is…` |

The Claude app titles its window plainly **`Claude`** — it never contributed a repo hint,
so v17 suppressed something that wasn't happening. The real source is the two TeXShop
titles: `desktop_dashboard_17.lua` normalizes to `desktop dashboard 17 lua`, which
contains `desktop dashboard`. **Both files are in `~/.Trash`.** Rule 2 matches a repo
name anywhere in a title and cannot distinguish a file belonging to the repo from a
deleted file merely named like it; TeXShop is not in `docApps`, so no real path was
available to check.

That case is left unfixed on purpose — tightening it needs a path (rule 1), not more
aggressive title matching.

The v18 changes are still correct and were requested: browsers and chat apps genuinely
do title themselves by topic, and a browser on `pcornillon/Desktop_Dashboard · GitHub`
would have caused exactly this bug for real.

### Why Desktop 1 needed a manual name

Even with every hint suppressed, that Desktop resolves to `Utility`: rule 4 sees four
distinct subjects (TeXShop, Claude, TextEdit, Stickies) and returns `M.utilityLabel`
long before `M.appLabels` is consulted — `appLabels` only applies when a **single** app
owns the Desktop. No detection rule could return `Claude Chat/Cowork` for a Desktop
holding five apps.

So it was set as a manual override (`manual: true`, keyed to iMac + position 1 in the
state file), which is what ⌘⌃⌥N exists for. Verified live: Desktop 1 reads
`Claude Chat/Cowork`. **To undo:** focus that Desktop, press ⌘⌃⌥N, submit an empty name.
Note that while the override stands, that Desktop will keep the name even if it is
repurposed.

## Follow-on fix (v17, superseded above)

With v16 detecting the repo, a second, opposite problem showed: the Desktop holding the
**Claude desktop app** was labeled `Desktop_Dashboard`, because the app's window title
is a conversation name that mentioned the repo.

Rule 2 treats any repo name in any title as a hint, but a title can name either a
*location* or a *subject*, and only the first is evidence about the Desktop. A Terminal
running `claude` in a repo names its working directory; the Claude app names what you're
talking about. `M.noRepoHintApps` withholds an app's titles from the hint text while the
app still counts toward the subject, and `M.appLabels` renames the single-app result so
the Desktop reads `Claude App` rather than the bare process name `Claude`.

## Not done (deliberately)

The optional items at the end of `MOVING.md` — per-machine config split, current-Desktop
marker, window counts per Desktop, watching window moves between Spaces, README
screenshot. All require asking first.

## Backups

The two original `~/.hammerspoon` files (pre-change `desktop_dashboard.lua` and
`init.lua`) were copied to the session scratchpad before being modified. That directory
is temporary — if the reload verifies clean, nothing needs to be recovered from it.
