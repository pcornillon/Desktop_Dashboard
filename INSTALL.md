# Installing Desktop Dashboard

How to install and run Desktop Dashboard on a machine. Do this on each Mac where you want
it (yours or a colleague's).

**Two of these steps a person has to do**, because macOS won't let software grant itself
permissions or click menu-bar items: granting Accessibility (step 2), and looking at the
screen to confirm the panel appeared (step 5). Everything else can be done for you — see
*[Let Claude Code install it](README.md#let-claude-code-install-it)*.

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

2. **Grant Accessibility permission** — 🧑 **you must do this yourself.** macOS deliberately
   prevents software from granting this on its own. System Settings → Privacy & Security →
   Accessibility → enable **Hammerspoon**. This is what lets the tool read window titles; it
   is a normal per‑app permission (the same one Rectangle, Moom, etc. use) and is *not*
   related to disabling SIP.

   The reliable test is step 5: without this permission the panel still loads and lists your
   Desktops, but every label comes out blank or `—`.

3. **Clone the repo** — put it wherever you keep your projects. From that folder:

   ```sh
   git clone https://github.com/pcornillon/Desktop_Dashboard.git
   ```

   `git clone` creates the `Desktop_Dashboard` folder itself, so there's no destination to
   name.

   Note where you put it, because two later things refer to that location:

   - the loader line in step 4 must point at it;
   - `M.repoRoots` — the setting telling the dashboard where your repos live — defaults to
     `~/Git_Repos`.

   If that happens to be where you keep repos, both work unmodified. Anywhere else is fine
   too; it's one line to change in each.

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

   > **If `~/.hammerspoon/init.lua` already exists, add to it — don't replace it.** It may
   > hold unrelated Hammerspoon config you'd lose.

   > If an older copy already sits at `~/.hammerspoon/desktop_dashboard.lua`, remove it so
   > there's a single source of truth — otherwise `require` loads that stale copy instead
   > of the repo.

5. **Reload and verify.** Click the Hammerspoon menu‑bar icon (the hammer) → **Reload
   Config**. You should see `desktop_dashboard vNN … loaded` in the Hammerspoon Console and
   the panel appear in a corner.

   No menu bar available (installing over SSH, or having Claude do it)? Restart Hammerspoon
   from a shell instead — same effect:

   ```sh
   osascript -e 'quit app "Hammerspoon"'; /bin/sleep 3; open -a Hammerspoon
   ```

   (`/bin/sleep` rather than plain `sleep` — some agent setups block the latter.)

   🧑 **Confirming the panel actually appeared is yours to do** — it's an on-screen overlay,
   and screenshots taken from a shell can't see it without Screen Recording permission.

## Optional: the red dot (Claude Code hooks)

The yellow and green dots work out of the box. **Red** — "this session is asking you
something" — needs Claude Code to tell us, because a session blocked on a question puts
exactly the same thing in its terminal title as one that has finished.

1. Put `claude-dashboard-state.sh` somewhere stable and make it executable:

   ```sh
   cp claude-dashboard-state.sh ~/.claude/claude-dashboard-state.sh
   chmod +x ~/.claude/claude-dashboard-state.sh
   ```

2. Register it on four events in `~/.claude/settings.json`. **Merge — never replace this
   file.** It holds your permissions and any hooks you already run; appending to an existing
   event's `hooks` array is the whole job. Back it up first. (`~/.claude/settings.json` is
   often a symlink to somewhere like Dropbox, in which case your edit syncs to your other
   machines — harmless here, since the script does nothing on a Mac without Hammerspoon.)

   ```json
   {
     "hooks": {
       "UserPromptSubmit": [{ "hooks": [{ "type": "command", "async": true, "timeout": 5,
         "command": "bash \"$HOME/.claude/claude-dashboard-state.sh\" working" }] }],
       "Notification":     [{ "hooks": [{ "type": "command", "async": true, "timeout": 5,
         "command": "bash \"$HOME/.claude/claude-dashboard-state.sh\" waiting" }] }],
       "Stop":             [{ "hooks": [{ "type": "command", "async": true, "timeout": 5,
         "command": "bash \"$HOME/.claude/claude-dashboard-state.sh\" done" }] }],
       "SessionEnd":       [{ "hooks": [{ "type": "command", "async": true, "timeout": 5,
         "command": "bash \"$HOME/.claude/claude-dashboard-state.sh\" gone" }] }]
     }
   }
   ```

3. Check it: `ls ~/.hammerspoon/claude_state/` should show one JSON file per live session
   shortly after you next prompt a session. If nothing appears, open `/hooks` in Claude
   Code once (that reloads the config) or restart the session.

The script writes only to `~/.hammerspoon/claude_state/`, exits 0 unconditionally, and
does nothing at all on a machine with no `~/.hammerspoon` — so it is safe to sync these
settings across machines.

## First run

Press **⌘⌃⌥S** once to walk every Desktop and label them all. After that it keeps itself
up to date on its own.

## Testing

A scripted way to watch all three dot colors happen on cue.

**Set up:** open a terminal on a Desktop of its own, `cd` into a repo under your
`M.repoRoots`, and start `claude` there. Confirm that Desktop's line shows the repo name.
Then **switch to a different Desktop** and keep the panel in view — the point is watching a
session you can't see. Paste the prompt below into that session.

````text
I am testing a status dashboard that watches Claude Code sessions. This is a scripted
rehearsal, not real work.

Follow these steps exactly, in order. Do nothing else: no file reads, no searches, no
extra commands, no summarising between steps.

STEP 1 — wait 30 seconds by running exactly this, and let it finish:
    for i in $(seq 1 30); do /bin/sleep 1; done

STEP 2 — ask me a single multiple-choice question using your question tool. The subject
does not matter; my answer does not matter. Wait for my answer.

STEP 3 — wait 30 seconds again by running exactly this:
    for i in $(seq 1 30); do /bin/sleep 1; done

STEP 4 — run exactly this command, which is meant to require my approval:
    touch /tmp/dashboard-test.txt && rm /tmp/dashboard-test.txt
If it runs without asking my permission, tell me so and stop.

STEP 5 — wait 20 seconds by running exactly this:
    for i in $(seq 1 20); do /bin/sleep 1; done

Then reply with exactly: done

The waits are the thing being measured, so do not shorten or skip them.
````

**What you should see on that Desktop's line:**

| when | dot |
|------|-----|
| Step 1, during the wait | 🟡 yellow — computing |
| Step 2, question on screen | 🔴 red — waiting on you |
| after you answer | 🟡 yellow — resumed |
| Step 4, permission prompt | 🔴 red — waiting on you |
| after you approve or deny | 🟡 yellow — resumed |
| after `done` | 🟢 green — finished, unseen |
| when you switch to that Desktop | *(no dot)* — acknowledged |

Notes:

- **Steps 2 and 4 test different things.** A question box and a permission prompt are
  separate mechanisms; both should turn the dot red.
- **Step 4 assumes `rm` needs approval on your setup.** If your `permissions` settings
  auto-allow it, substitute any command yours does ask about.
- **Red only appears if the hooks are installed** (previous section). Without them steps 2
  and 4 show green instead of red; everything else is the same.
- If the dot never appears at all, the Desktop probably isn't labeled with the repo name —
  press ⌘⌃⌥S and check the line reads the repo, not `Utility` or an app name.

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
