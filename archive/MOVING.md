# MOVING.md — getting started (hand this to Claude Code)

You're picking up a small, **already‑working** Hammerspoon tool and turning it into a
proper git repo the user can share across machines and with colleagues. Nothing here needs
a rewrite — the goal is packaging, verifying it still loads, and committing. Read
`CLAUDE.md` for the design and the reasons behind it before changing any code.

This file is a one‑time migration guide; once the repo exists and works, it's done.
Day‑to‑day install (on this or any other machine) lives in `INSTALL.md`.

## Context

- **What it is:** `desktop_dashboard.lua` — a single‑file Hammerspoon tool that overlays a
  panel listing every macOS Space ("Desktop") with a label (the repo it's focused on, or
  its app/subject) and lets you click to switch Desktops. See `README.md` (overview),
  `INSTALL.md` (install), and `CLAUDE.md` (design decisions).
- **Status:** working and in daily use. Current version is stamped in `M.version` at the
  top of the file and printed to the Hammerspoon Console on load.
- **Where it lives:** `~/Git_Repos/Desktop_Dashboard/` (this repo).
- **The one structural wrinkle:** Hammerspoon only loads Lua from `~/.hammerspoon/`. This
  repo lives elsewhere, so `~/.hammerspoon/init.lua` must point `require` at the repo
  (covered in `INSTALL.md`). Don't "fix" this by copying the `.lua` into `~/.hammerspoon`.

## What's in the repo

```
desktop_dashboard.lua   the tool (single file; CONFIG block at top; returns M)
README.md               overview, controls, config, limitations
INSTALL.md              how to install on a machine (Hammerspoon, wiring, verify)
CLAUDE.md               design + decisions (read before editing)
MOVING.md               this file (one-time repo setup)
init.lua.example        the snippet to add to ~/.hammerspoon/init.lua
.gitignore
```

## Setup steps

1. **Initialize the repo** (from `~/Git_Repos/Desktop_Dashboard`):

   ```sh
   cd ~/Git_Repos/Desktop_Dashboard
   git init
   git add .
   git commit -m "Import Desktop Dashboard (working v15)"
   ```

   Then create the remote and push. **Ask the user** which host and visibility they want;
   don't assume public.

2. **Single source of truth.** If the user previously had a copy at
   `~/.hammerspoon/desktop_dashboard.lua` (or numbered copies like
   `desktop_dashboard_11.lua`), remove them — otherwise `require` would load the stale
   `~/.hammerspoon` copy instead of the repo.

3. **Install and verify.** Follow `INSTALL.md` to wire it into Hammerspoon, then confirm
   the Console prints `desktop_dashboard vNN … loaded` matching the repo's `M.version`, the
   panel appears, and ⌘⌃⌥S labels every Desktop. This is a live‑GUI tool — you can't fully
   verify it headless, so hand the reload/Accessibility bits back to the user and have them
   confirm.

## Constraints (don't relearn these the hard way)

- **Keep reads to one `hs.window.allWindows()` snapshot.** Never call `hs.window.get(id)`
  per window id — it rebuilds the whole window list each call (~40 ms) and multiplies into
  multi‑minute freezes. This was the central performance bug; `CLAUDE.md` has the detail.
- **Don't add slow apps to `M.docApps`.** Reading `AXDocument` from Electron/Office/Java
  apps (Slack, OneNote, Teams, MATLAB) can stall for minutes. `docApps` is an allowlist of
  real editors on purpose.
- **Don't commit or sync `desktop_dashboard_state.json`.** It's machine‑specific and lives
  in `~/.hammerspoon`, outside the repo (already excluded).
- **Bump `M.version` on every change** and keep the load‑time print — it's how the user
  confirms the right file is live.
- The config block (`M.repoRoots`, `M.categories`, `M.docApps`, app names like
  `"MacDown 3000"`) is user/machine‑specific — what a colleague on another setup would edit.

## Reasonable next steps (optional, ask the user first)

- A `LICENSE` (MIT is a fine default for sharing) and a short repo description.
- Per‑machine config split (a small local override file so the shared `desktop_dashboard.lua`
  stays identical across machines while `repoRoots`/apps differ).
- Optional features discussed but not built: a marker on the Desktop you're currently in,
  window counts per Desktop, watching window *moves* between Spaces (noisier events).
- A short GIF/screenshot in the README.

Ask before doing any of these — the immediate ask is just: make it a clean, shareable repo
that still loads and works.
