# Installing Desktop Dashboard

How to install and run Desktop Dashboard on a machine. Do this on each Mac where you want
it (yours or a colleague's). It's separate from `MOVING.md`, which is the one‑time job of
turning this into a repo.

## Requirements

- macOS (built and used on an Intel Mac; should work on Apple Silicon too).
- [Hammerspoon](https://www.hammerspoon.org) — free, open‑source, notarized.
  **No SIP changes required.**

## Steps

1. **Install Hammerspoon**

   ```sh
   brew install --cask hammerspoon
   ```

   (or download from https://www.hammerspoon.org). Launch it once.

2. **Grant Accessibility permission** when prompted — this is what lets the tool read
   window titles and files. System Settings → Privacy & Security → Accessibility → enable
   **Hammerspoon**. This is a normal per‑app permission (the same one Rectangle, Moom, etc.
   use); it is *not* related to disabling SIP.

3. **Get the repo onto this machine** wherever you keep your projects, e.g.

   ```sh
   git clone <your-remote> ~/Git_Repos/Desktop_Dashboard
   ```

4. **Point Hammerspoon at it.** Hammerspoon only loads Lua from `~/.hammerspoon/`, so add
   these lines to `~/.hammerspoon/init.lua` (create the file if it doesn't exist) to load
   the code from the repo. This is the content of `init.lua.example`:

   ```lua
   -- Load Desktop Dashboard from its repo (adjust the path if you cloned elsewhere)
   package.path = package.path .. ";" .. os.getenv("HOME") .. "/Git_Repos/Desktop_Dashboard/?.lua"
   local dd = require("desktop_dashboard")
   dd.start()
   ```

   Adjust the path if you cloned somewhere other than `~/Git_Repos`. If you'd rather not
   touch `package.path`, symlink instead:

   ```sh
   ln -s ~/Git_Repos/Desktop_Dashboard/desktop_dashboard.lua ~/.hammerspoon/desktop_dashboard.lua
   ```

   and then just `local dd = require("desktop_dashboard"); dd.start()`.

   > If an older copy already sits at `~/.hammerspoon/desktop_dashboard.lua`, remove it so
   > there's a single source of truth — otherwise `require` loads that stale copy instead
   > of the repo.

5. **Reload and verify.** Click the Hammerspoon menu‑bar icon (the hammer) → **Reload
   Config**. You should see `desktop_dashboard vNN … loaded` in the Hammerspoon Console and
   the panel appear in a corner.

## First run

Press **⌘⌃⌥S** once to walk every Desktop and label them all. After that it keeps itself
up to date on its own.

## Configuration

Everything is in the `CONFIG` block at the top of `desktop_dashboard.lua`. On a new machine
the main one to set is `M.repoRoots` (your repos folder, default `~/Git_Repos`); you may
also adjust `M.categories` / `M.docApps` to the apps you actually use. See the
Configuration section of `README.md` for the full list.

## Troubleshooting

- **No panel / everything blank:** confirm Accessibility is enabled for Hammerspoon
  (step 2), then Reload Config.
- **Wrong version in the Console (or old behavior):** an old copy is shadowing the repo —
  remove `~/.hammerspoon/desktop_dashboard.lua` (step 4 note) and reload.
- **A Desktop won't label until you visit it:** expected — macOS only lets an app read a
  Desktop's windows while it's active. Press ⌘⌃⌥S to fill them all in.
