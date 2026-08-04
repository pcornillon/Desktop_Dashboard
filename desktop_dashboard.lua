--[[============================================================
  desktop_dashboard.lua  —  a Hammerspoon tool for Peter

  A small always-on panel, shown on every Desktop, that labels each
  Desktop with the project (a repo under your repo roots) or subject
  (Communication / Matlab / Browser …) of its windows. Finder and
  Terminal windows are ignored. Click a line to jump to that Desktop.

  HOW DETECTION WORKS (and why it's fast now)
  -------------------------------------------
  macOS only lets an app read a window's details while that window's Desktop
  is the active one. So this reads the *currently visible* Desktops (the
  active Space on each display) — which is cheap and reliable — and caches
  each Desktop's label. That means:
    • A Desktop is labeled the moment you switch to it, and the label sticks.
    • ⌘⌃⌥s walks every Desktop, reading each as it becomes active, to fill
      them all in at once.
    • Names from your last session are restored on launch, so Desktops you
      haven't visited yet still show their previous name immediately.
  Showing/hiding and clicking never do any of this work, so they're instant.

  INSTALL
  -------
  1. brew install --cask hammerspoon   (or hammerspoon.org)
  2. Launch it; grant Accessibility (System Settings → Privacy & Security
     → Accessibility → Hammerspoon ON).
  3. Copy this file to  ~/.hammerspoon/desktop_dashboard.lua
  4. In  ~/.hammerspoon/init.lua :
        local dd = require("desktop_dashboard")
        dd.start()
  5. Hammerspoon menubar (hammer icon) → Reload Config.

  CONTROLS  (the letters are LOWERCASE — the binds are cmd+ctrl+alt+<key>,
             so adding shift, i.e. an uppercase letter, does NOT trigger them)
  --------
  • Click a line — switch to that Desktop.
  • ⌘⌃⌥ d — show / hide the dashboard.
  • ⌘⌃⌥ n — name the current Desktop (blank clears it).
  • ⌘⌃⌥ r — restore the saved window layout (move/open windows).
  • ⌘⌃⌥ s — walk every Desktop once and label them all.
  • ⌘⌃⌥ m — cycle what the panel lists: Desktops / claude sessions / both.
  • ⌘⌃⌥ g — pop up each shown repo's GitHub status (on demand; queries the
            network only when pressed). In that popup, click "GitHub ahead"
            to pull that repo — fast-forward only, so it can't lose work.
  • Drag the panel to move it; its position is remembered per display.

  Every panel line whose label is a repo also carries a git dot: RED if this
  machine has something GitHub doesn't (uncommitted changes or unpushed
  commits), GREEN if it is clean and fully pushed. That check is local/offline;
  ⌘⌃⌥ g is what reaches out to GitHub. An empty dot slot on a line whose other
  dot is lit is drawn GRAY, so claude (first) and git (second) can always be
  told apart by position.

  Each line is a NAME and an ICON ROW. The name says what the Desktop is for (a
  repo, or a name you set with ⌘⌃⌥n); the icons say what is on it, Finder and
  terminals last. A Desktop whose label would only name apps (Utility, or one
  app's own name) drops the word and shows just the icons. Point at an icon to
  see which app it is and which window you'd get; click it to go to that Desktop
  AND raise that window (clicking the line just goes to the Desktop).

  Drag the grip in the bottom-right corner to resize the whole panel.

  Names + window layout auto-save (periodically and at logout/shutdown) to
  ~/.hammerspoon/desktop_dashboard_state.json.
============================================================]]--

local M = {}
M.version = "v50 (legend buttons; alerts from another Mac; quote restore paths, 2026-08-03)"

-- ============================ CONFIG ============================

M.repoRoots = {
  os.getenv("HOME") .. "/Git_Repos",
  -- add more, e.g.  os.getenv("HOME") .. "/Dropbox/Data",
}

M.ignoreApps = {
  ["Finder"] = true, ["Terminal"] = true, ["iTerm2"] = true, ["Hammerspoon"] = true,
}

-- Apps whose window titles must NOT feed the repo hint, though the app itself
-- still counts toward the Desktop's subject.
--
-- A Terminal running `claude` in a repo puts the WORKING DIRECTORY in its title
-- — a real statement about which repo this Desktop is for. The Claude desktop
-- app puts the CONVERSATION NAME in its title, which may contain a repo name
-- merely because that's what you're discussing. Same words, different meaning:
-- the app is a workspace of its own, not a checkout of a repo. Without this,
-- a chat about Desktop Dashboard relabels the Desktop as Desktop_Dashboard.
--
-- Chat apps and browsers both title themselves by topic: a conversation name,
-- or a page title such as "pcornillon/Desktop_Dashboard · GitHub". Neither says
-- the Desktop *is* that repo's workspace.
-- Finder is here because a Finder window's title is the folder you happen to
-- be BROWSING. Parking Finder in a repo to copy one file out of it should not
-- rename the Desktop after that repo, and in practice it did.
M.noRepoHintApps = {
  ["Claude"] = true, ["ChatGPT"] = true, ["Finder"] = true,
  ["Safari"] = true, ["Google Chrome"] = true, ["Firefox"] = true,
  ["Microsoft Edge"] = true, ["Arc"] = true, ["Brave Browser"] = true,
  ["Chromium"] = true, ["Opera"] = true, ["Vivaldi"] = true,
}

-- Terminals are the in-between case. A shell sitting in a repo is weak
-- evidence — you cd through directories all day — but a terminal running
-- `claude` in a repo is the strongest signal there is, because that is a
-- session someone is actually working in. So a terminal's title counts as a
-- repo hint ONLY when it looks like a claude session.
M.claudeOnlyHintApps = {
  ["Terminal"] = true, ["iTerm2"] = true, ["Ghostty"] = true,
  ["Alacritty"] = true, ["kitty"] = true, ["WezTerm"] = true,
}
M.claudeTitleMarker = "claude"     -- lowercased substring that marks a session

-- Display-name overrides for the "one app on this Desktop" case, where the
-- label would otherwise be the bare process name.
M.appLabels = {
  ["Claude"] = "Claude Chat/Cowork",   -- distinct from `claude` in a terminal
}

-- Colored dot next to a repo Desktop that has a `claude` session running,
-- showing whether that session is computing.
--
-- Claude Code stamps the terminal title with an animated Braille spinner while
-- it is working, and with U+2733 (✳) when it is not. Measured 2026-07-28 over
-- ~750 one-second samples. There are only those two states: a session blocked
-- on a question shows the SAME ✳ as one that has finished, so "waiting for you"
-- cannot be told from "done" and there is deliberately no red. See CLAUDE.md.
--
-- Titles come from Terminal via AppleScript, not Accessibility, so this works
-- for Desktops you are not currently viewing.
-- A green dot is an UNACKNOWLEDGED completion, not merely "idle": it appears
-- when a session goes from working to not-working, and clears once you visit
-- that Desktop (clicking its line counts, since that switches you there).
-- A session that was already idle at launch shows nothing — only work that
-- finishes while the dashboard is watching is worth flagging.
-- RED comes from Claude Code hooks, not the title. The title cannot express it:
-- a session blocked on a question shows the same ✳ as one that has finished
-- (measured). The Notification hook is the only authoritative source, so
-- ~/Dropbox/claude/claude-dashboard-state.sh writes one JSON file per session
-- into claudeStateDir and this reads them. Without the hooks installed the dot
-- still works — you simply never see red.
M.showClaudeDot    = true
M.claudeDotChar    = "●"
-- An empty dot slot on a line that shows ANY live dot is drawn as a dim gray
-- dot rather than left blank. The two dots are told apart by position (claude
-- first, git second), and position only reads if both columns are visible: a
-- lone green git dot floating in slot 2 was being taken for a claude dot.
-- Lines with nothing to report stay blank — a wall of gray dots on every
-- Desktop would be worse than the ambiguity it fixes.
M.showDotPlaceholders  = true
M.dotPlaceholderColor  = { white = 0.42, alpha = 1 }
M.claudeDotSeconds = 3           -- how often titles are read (async, never blocks)
M.claudeStateDir   = os.getenv("HOME") .. "/.hammerspoon/claude_state"
M.claudeHookMaxAgeHours = 12     -- ignore state files older than this
M.claudeDotColors  = {
  working = { red = 1.00, green = 0.78, blue = 0.20, alpha = 1 },   -- yellow: computing
  waiting = { red = 1.00, green = 0.28, blue = 0.26, alpha = 1 },   -- red: wants you
  done    = { red = 0.30, green = 0.85, blue = 0.40, alpha = 1 },   -- green: finished, unseen
}

-- GIT STATUS DOT — a second dot, right after the Claude dot, on every panel line
-- whose label is one of your repos (a folder under M.repoRoots). It says whether
-- THIS machine is in sync with GitHub, and nothing more subtle:
--   RED   = GitHub does not have everything here — a dirty working tree
--           (uncommitted/untracked changes) OR local commits not yet pushed.
--   GREEN = clean working tree AND all commits pushed.
-- The check is purely LOCAL/OFFLINE (git status --porcelain + rev-list @{u}..HEAD),
-- run in one hs.task pass on its own timer, so it never blocks and never touches
-- the network. GitHub's own state is deliberately NOT folded in here: it would go
-- stale the moment someone pushed, and a dot cannot honestly show what it hasn't
-- checked. ⌘⌃⌥g queries GitHub on demand and shows it in a popup instead.
-- A folder under repoRoots that is not a git repo gets no dot. App/category
-- labels (Mail, Utility) are not repos, so they get no dot either.
M.showGitDot    = true
M.gitDotChar    = "●"
M.gitDotSeconds = 15             -- how often local git status is re-read (offline)
M.gitDotColors  = {
  changed = { red = 1.00, green = 0.28, blue = 0.26, alpha = 1 },   -- red: local ≠ GitHub
  clean   = { red = 0.30, green = 0.85, blue = 0.40, alpha = 1 },   -- green: in sync
}

-- ⌘⌃⌥g — GitHub status popup, ON DEMAND ONLY. Nothing hits the network until you
-- press it; then it queries just the repos currently on the panel. Light touch:
-- `git ls-remote` reads the remote head SHA without fetching or mutating any
-- local ref, so it never disturbs what `git status` shows in your own terminal.
M.githubHotkey  = { mods = {"cmd","ctrl","alt"}, key = "g" }
M.githubTimeout = 20             -- seconds before a slow/hung GitHub query is killed

-- Clicking "GitHub ahead" in that popup pulls the repo. This is the ONLY thing
-- in the tool that writes to one of your repositories, so it is the one place
-- that needs to be conservative rather than clever:
--   • --ff-only. "GitHub ahead" also covers a true DIVERGENCE (you committed
--     here, someone committed there), and a plain `git pull` would answer that
--     with a merge commit — a rewrite of your history from a single click, in a
--     window with nowhere to resolve a conflict. --ff-only takes the easy case
--     and refuses the rest out loud. Set false to allow the merge.
--   • Nothing else is offered. There is deliberately no push button here: a
--     pull that fast-forwards cannot lose work, and a push can.
-- Git's own refusals (dirty tree in the way, diverged history) are shown
-- verbatim in the popup rather than second-guessed.
M.allowPullFromPopup = true
M.pullFFOnly         = true
M.pullTimeout        = 120       -- a pull fetches objects; give it longer than a query

-- Two things a pull can't see, which this panel can, so it checks them first.
--
-- 1. A CLAUDE SESSION IN THAT REPO. Changing files under a session that is
--    mid-task doesn't destroy anything, but it does leave it reasoning about
--    files that no longer say what it read. "working" (the yellow dot) blocks
--    the pull; a session that is merely open does not, because on this machine
--    that would block nearly every repo nearly all the time. Set "any" to
--    refuse whenever a session is live in the repo at all, or false for never.
M.pullBlockOnClaude = "working"   -- "working" | "any" | false
--
-- 2. A FILE THE PULL WOULD CHANGE THAT YOU HAVE OPEN IN AN EDITOR. This is the
--    one real way to lose work here, and it isn't git's fault: the editor is
--    holding the old text, and your next save writes it back over what arrived.
--    Git can't know, but this panel already reads the open document of every
--    editor in M.docApps, so it can. Aborting beats warning — a warning still
--    leaves the stale buffer in front of you.
--    LIMIT, and it matters: this only sees editors in M.docApps, on Desktops
--    that have been read since launch. TeXShop, Electron editors and anything
--    unvisited are invisible to it. Treat a clean check as "nothing known to be
--    open", never as "nothing is open".
M.pullBlockOnOpenFiles = true

-- Confirm before pulling. The prompt comes AFTER the checks, so it can say what
-- is actually about to change instead of asking you to agree to an unknown —
-- "3 files will change: notes.md, run.lua, README.md" is a decision; "are you
-- sure?" is a speed bump. It appears inside the popup rather than as a system
-- dialog: the popup is already frontmost under your cursor, and an alert raised
-- by Hammerspoon while another app is active can open BEHIND that app.
M.pullConfirm = true

M.categories = {
  ["Mail"] = "Communication", ["Microsoft Outlook"] = "Communication",
  ["WhatsApp"] = "Communication", ["Messages"] = "Communication",
  ["Slack"] = "Communication", ["Microsoft Teams"] = "Communication",
  ["Microsoft Teams classic"] = "Communication", ["zoom.us"] = "Communication",
  ["Webex"] = "Communication", ["GoToMeeting"] = "Communication",
  ["Skype"] = "Communication", ["Discord"] = "Communication",
  ["Google Chrome"] = "Browser", ["Firefox"] = "Browser", ["Safari"] = "Browser",
  ["Visual Studio Code"] = "VS Code", ["Code"] = "VS Code", ["CLion"] = "CLion",
  ["Aquamacs"] = "Emacs", ["Emacs"] = "Emacs", ["MacDown 3000"] = "Markdown",
  ["Preview"] = "Reading", ["Adobe Acrobat"] = "Reading",
  ["Adobe Acrobat Reader"] = "Reading",
  ["Keynote"] = "Presentation", ["Microsoft PowerPoint"] = "Presentation",
  ["Microsoft Word"] = "Writing", ["Microsoft Excel"] = "Spreadsheet",
  ["Numbers"] = "Spreadsheet",
  ["Microsoft OneNote"] = "Notes", ["OneNote"] = "Notes", ["Notes"] = "Notes",
  ["Calendar"] = "Calendar", ["Reminders"] = "Reminders",
}

-- Only these apps get asked for their open file's path (needed for repo
-- detection). Everything else is labeled by category/name — this avoids the
-- slow accessibility queries to Electron/Office apps (Slack, OneNote, Teams…)
-- that were causing multi-minute hangs.
M.docApps = {
  ["MacDown 3000"] = true, ["Visual Studio Code"] = true, ["Code"] = true,
  ["CLion"] = true, ["PyCharm"] = true, ["Aquamacs"] = true, ["Emacs"] = true,
  ["Preview"] = true, ["Microsoft Word"] = true, ["Microsoft Excel"] = true,
  ["Pages"] = true, ["Numbers"] = true, ["Keynote"] = true,
  ["TextEdit"] = true, ["BBEdit"] = true, ["Xcode"] = true,
  ["Sublime Text"] = true, ["Nova"] = true,
}

-- A Desktop whose windows span at least this many different subjects is
-- labeled M.utilityLabel (e.g. browser + Slack + Calendar → "Utility").
-- A single subject keeps that subject's name (Calendar alone → "Calendar").
M.utilityMinSubjects = 2
M.utilityLabel       = "Utility"

-- APP ICONS. Whenever a Desktop's label names APPS rather than work, the panel
-- draws the apps instead of the word: "Utility" and "Communication" (a bucket
-- for a mix), and a lone app's own name ("MacDown"). A Desktop labeled by a
-- repo or by a claude session's directory keeps its text — that names the work,
-- which no icon can. Pointing at an icon gives the name back, which is what
-- makes dropping the word affordable.
-- Set false to go back to the words everywhere.
M.showAppIcons = true
M.maxAppIcons  = 6              -- beyond this, the rest are summarised as "+N"
M.appIconGap   = 3              -- px between icons
M.appIconBump  = 3              -- icon edge = fontSize + this

-- Hovering an icon names it. A 16 px icon is recognisable for apps you use all
-- day and a guess for the rest, which is exactly the case the icons are meant
-- to cover — so point at one and a tip says which app it is and which of its
-- windows you'd get. Naming beats enlarging: a bigger version of an icon you
-- didn't recognise is still an icon you don't recognise.
M.showIconTips    = true
M.iconTipDelay    = 0.18        -- s before the tip appears; keeps a sweep across
                                -- the row from flashing every name on the way past
M.iconTipMaxChars = 44          -- window title truncated to this

-- Clicking an ICON goes to that Desktop and raises that app's window; clicking
-- anywhere else on the line just goes to the Desktop and leaves whatever was
-- focused there alone. Both are useful: the line is "take me there", the icon is
-- "take me to this".
M.iconClickFocus = true
M.iconFocusDelay = 0.45         -- s to let the Space switch settle before raising

-- Apps that are ignored when deciding what a Desktop is ABOUT, but still worth
-- an icon: "there's a Finder and two terminals here" is useful even though the
-- Desktop is not *about* Finder. Their icons always come LAST, after the
-- subject apps, so the row keeps reading subject-first. Terminals are taken
-- from M.claudeOnlyHintApps rather than repeated here, so adding your terminal
-- there is enough. Hammerspoon is deliberately absent: it is this panel.
M.trailingIconApps = { ["Finder"] = true }

-- RESIZE. Drag the grip in the bottom-right corner. It scales M.fontSize, which
-- every other measurement derives from, so the panel keeps its proportions
-- instead of stretching — there is no free aspect ratio here, the shape comes
-- from the content. The size is saved with the layout, like the position.
-- (This replaced a pair of −/+ buttons: stepping one point per click to cross a
-- useful range was tedious, which is the whole objection to a stepper.)
M.showResizeGrip = true
M.minFontSize    = 9
M.maxFontSize    = 28

M.categoryPatterns = {
  { pat = "MATLAB", cat = "Matlab" },
  { pat = "Simply Fortran", cat = "Fortran" },
  { pat = "Eclipse", cat = "Eclipse" },
  { pat = "PyCharm", cat = "PyCharm" },
}

-- What the panel lists.
--   "desktops"  one line per Desktop (the original behaviour)
--   "terminals" one line per running claude session, wherever its window is —
--               for people who keep every session on a single Desktop, where
--               listing Desktops says almost nothing
--   "both"      Desktops, then a Claude sessions section underneath
-- ⌘⌃⌥M cycles through them.
M.mode            = "desktops"
M.sessionHeader   = "Claude sessions:"
-- The task summary is what tells two sessions in the same repo apart, so it
-- earns its place — but on one line it dictates the panel's width. Giving it
-- its own indented line means the width is set by the project name instead.
M.sessionTwoLine      = true
M.sessionSummaryChars = 20      -- characters of summary shown
M.sessionSummaryIndent = 5      -- indent past the start of the project name
M.modeHotkey      = { mods = {"cmd","ctrl","alt"}, key = "m" }

-- Drag the panel with the mouse. A position you drag to is remembered per
-- display and survives a reload; M.resetPanelPosition() puts it back in the
-- corner. Set false to pin the panel and disable all mouse-drag handling.
M.draggable       = true
M.dragThreshold   = 3           -- px of movement before a press counts as a drag
                                -- rather than a click on a Desktop line

-- THE "YOU ARE HERE" MARKER. The active Desktop is called out twice: a caret,
-- and the Desktop number in magenta. Both, because either alone is weak — the
-- caret is easy to miss in a list of a dozen lines, and color alone excludes
-- anyone who can't separate it from white (this panel already spends four
-- colors on the dots). Magenta is deliberately not one of the dot colors.
--
-- The two markers MUST render the same width or the active line loses its
-- alignment with the rest. "▸" is exactly one Menlo cell, so caret + 2 spaces
-- matches 3 spaces. If you change these, check the widths — do not assume a
-- glyph occupies one cell just because the font is monospaced.
M.highlightActive = true
M.activeMarker    = "▸  "
M.inactiveMarker  = "   "
M.activeColor     = { red = 1.00, green = 0.45, blue = 0.90, alpha = 1 }

M.corner          = "topleft"
M.margin          = 14
M.fontSize        = 13
-- The width bounds are in px, and px stop meaning anything fixed once the panel
-- can be zoomed: at 20 pt a long repo name plus its icons needs ~990 px, so a
-- flat 760 cap simply cut the icons off the right-hand end. Both bounds are
-- therefore taken as px AT M.baseFontSize and scaled with the current size.
M.minWidth        = 220
M.maxWidth        = 760
M.baseFontSize    = 13          -- the size minWidth/maxWidth were chosen for
M.sectionGap      = 10
M.refreshSeconds  = 10          -- re-read the visible Desktop(s) this often (cheap)
M.repoRescanSeconds = 30        -- re-list repoRoots this often, so repos created
                                -- after launch get detected without a reload
M.scanDwell       = 0.6         -- dwell per Desktop during ⌘⌃⌥S
M.restoreDwell    = 0.5         -- gap between per-display restores after a scan
M.autosaveMinutes = 4
M.toggleHotkey    = { mods = {"cmd","ctrl","alt"}, key = "d" }
M.nameHotkey      = { mods = {"cmd","ctrl","alt"}, key = "n" }
M.restoreHotkey   = { mods = {"cmd","ctrl","alt"}, key = "r" }
M.scanHotkey      = { mods = {"cmd","ctrl","alt"}, key = "s" }

-- A line above the legend counting the Desktops still showing restored state
-- rather than a first-hand read — macOS only lets us read the Desktop you are
-- looking at, so after a reload the rest are last session's picture until you
-- visit them or press ⌘⌃⌥S. Click the line to do that now. It counts itself
-- down as Desktops are read and disappears when none are left.
M.showStaleHint = true

-- Alerts from ANOTHER Mac — a session there is blocked on a question. Written by
-- claude-dashboard-state.sh at the instant it happens, into a synced folder.
-- Nothing here is on by default beyond reading the folder: if the folder does
-- not exist, this costs one failed directory read every remoteAlertSeconds.
M.showRemoteAlerts       = true
M.remoteAlertDir         = (os.getenv("HOME") or "") .. "/Dropbox/claude/dashboard_alerts"
M.remoteAlertSeconds     = 20     -- backstop; a path watcher catches it sooner
M.remoteAlertMaxAgeHours = 12     -- same bound as the local hook files
M.remoteAlertNotify      = true   -- post a macOS notification for a NEW marker
M.remoteAlertColor       = { red = 1, green = 0.45, blue = 0.45, alpha = 1 }

-- Command legend shown at the bottom of the panel. Set showLegend=false to
-- hide it; edit legendLines if you remap the hotkeys above.
M.showLegend  = true
-- Split across two lines on purpose: the legend is the widest thing in the
-- panel in Desktops mode, so appending to one line widens the whole panel.
M.legendLines = {
  "⌘⌃⌥  s scan · d hide · n name",
  "     r restore · m mode · g GitHub",
  "click a line, or a blue word",
}

-- Words IN the legend that are themselves click targets. The legend is the only
-- place the hotkeys are named, and over a remote session (VNC, Screen Sharing)
-- the hotkey is precisely what you cannot send — ⌘⌃⌥ is eaten by the local
-- machine, so the panel is readable but every command on it is unreachable.
-- The word is the fallback, and it costs no panel width because it is text that
-- is already there. Key is the literal substring to find in a legend line; value
-- is the element id `activateElement` routes on.
--
-- `d hide` is deliberately NOT here. Unhiding is the same hotkey, so on the one
-- machine that cannot press it a clickable "hide" is a one-way door.
--
-- `scan` routes to the id the stale-count line already uses, so both paths to
-- ⌘⌃⌥S stay one branch.
-- `r restore` is deliberately not here either, for a different reason than
-- `hide`: it MOVES AND OPENS WINDOWS across every Desktop. It is the most
-- disruptive thing the panel can do and the hardest to undo — there is no
-- inverse — so it stays behind a deliberate two-hand keypress rather than
-- sitting one stray click away from the words next to it. Asked for 2026-08-03.
M.legendClicks = {
  scan   = "rescan",
  name   = "name",
  mode   = "mode",
  GitHub = "github",
}
-- Blue, and named as blue on the third legend line. Not magenta: that already
-- means "the Desktop you are standing on" and a second meaning would dilute it.
M.legendClickColor = { red = 0.45, green = 0.75, blue = 1.00, alpha = 1 }

-- ===============================================================

local canvases   = {}          -- { { cv = canvas, uuid = screenUUID }, ... }
local panelPos   = {}          -- screen UUID -> { x =, y = } once dragged
local hiddenScreens = {}       -- screen UUID -> true when that display's panel is hidden
local drag       = nil         -- in-flight drag session, nil when idle
local dragTap, dragWatchdog
local labelCache = {}          -- spaceID -> label string
local lastGather = {}          -- spaceID -> { {app,title,doc,win,bundle}, ... }
local iconApps   = {}          -- spaceID -> ordered { {bundle,app,wid,title}, ... } to
                               -- draw as icons, set only for app-grouped Desktops
local iconImages = {}          -- bundle id -> hs.image, or false if it has none
local iconMeta   = {}          -- canvas element id -> { app, title, x, y, w, h },
                               -- rebuilt by draw(); drives the hover tip
local liveRead   = {}          -- spaceID -> true once actually read THIS session,
                               -- as opposed to restored from the state file
local hoverId, hoverUUID       -- the icon currently pointed at, and its screen
local tipCanvas, tipTimer, tipWatch, focusTimer
local overrides  = {}          -- spaceID -> manual name
local repos      = {}
local reposLoadedAt = 0        -- when loadRepos() last ran (see refreshRepos)
local claudeStates = {}        -- repo name (lowercased) -> "working" | "idle"
local claudeHooks  = {}        -- repo name -> "working" | "waiting" | "done" (from hooks)
local sessions     = {}        -- one entry per claude terminal window, ordered
local sessionPrev  = {}        -- Terminal window id -> previous state
local sessionDone  = {}        -- Terminal window id -> finished, unacknowledged
local claudePrev   = {}        -- previous sample, for spotting working -> idle
local claudeDone   = {}        -- repo name -> true: finished, not yet acknowledged
local claudeStatesAt, claudeTask, claudeTimer = 0, nil, nil
local gitStates    = {}        -- repo name (lowercased) -> "changed" | "clean"
local gitStatesAt, gitTask, gitTimer = 0, nil, nil
local ghTask, ghWatchdog, ghWebview     -- ⌘⌃⌥g: in-flight query, its kill timer, popup
local ghUserContent                     -- JS→Lua bridge for the popup, made once
local pullTask, pullWatchdog, pullRescan  -- the one operation here that writes to a repo
local pendingPull                         -- a pull waiting on its confirmation click
local refreshTimer, autosaveTimer, spaceWatcher, screenWatcher, winWatcher, debounceTimer
-- Holds the ⌘⌃⌥S walk's pending step. MUST be a live reference: an hs.timer
-- with nothing referencing it can be garbage-collected before it fires, which
-- silently ended the walk part way through — no error, just a stop.
local scanTimer
local draw                     -- forward declaration
local scanningAll = false      -- true only during a ⌘⌃⌥S walk
M.visible = true
M.status  = nil                -- progress text shown while walking Desktops

local stateFile = os.getenv("HOME") .. "/.hammerspoon/desktop_dashboard_state.json"

-- ---- helpers --------------------------------------------------------------

local function normalize(s) return (tostring(s or "")):lower():gsub("[%-%_%./]", " ") end

local function tokenSet(s)
  local set = {}
  for w in normalize(s):gmatch("[%a%d]+") do if #w >= 3 then set[w] = true end end
  return set
end

local function uwidth(s) return (utf8 and utf8.len and utf8.len(s)) or #s end
-- One monospaced character's width, the unit the panel is sized in.
local function charWidth() return (M.fontSize or 13) * 0.62 end

-- Width of a run of legend text, MEASURED rather than counted. The legend mixes
-- ⌘⌃⌥ and · with ASCII, and the rule that placed the active marker applies here
-- too: do not assume a glyph is one cell wide because the font is monospaced.
-- This positions a click target over one word of an already-drawn line, so an
-- error of a few px puts the target off the word. Falls back to a count.
local function legendFont() return { name = "Menlo", size = math.max(1, (M.fontSize or 13) - 2) } end
local function legendWidth(s)
  if s == "" then return 0 end
  local ok, sz = pcall(hs.drawing.getTextDrawingSize, hs.styledtext.new(s, { font = legendFont() }))
  if ok and type(sz) == "table" and sz.w then return sz.w end
  return uwidth(s) * ((M.fontSize or 13) - 2) * 0.62
end
-- Icon edge and the gap after it, in px.
local function iconMetrics()
  return math.max(8, (M.fontSize or 13) + (M.appIconBump or 3)), (M.appIconGap or 3)
end

-- Ignored for the subject, but still shown as an icon at the end of the row.
local function isTrailingIconApp(app)
  return (M.trailingIconApps and M.trailingIconApps[app])
      or (M.claudeOnlyHintApps and M.claudeOnlyHintApps[app]) or false
end
local function loadState() local t = hs.json.read(stateFile); return (type(t) == "table") and t or nil end
local function saveState(t) pcall(hs.json.write, t, stateFile, true, true) end

local function loadRepos()
  repos = {}
  reposLoadedAt = hs.timer.secondsSinceEpoch()
  for _, root in ipairs(M.repoRoots) do
    if hs.fs.attributes(root) then
      for name in hs.fs.dir(root) do
        if name:sub(1, 1) ~= "." then
          local p = root .. "/" .. name
          local a = hs.fs.attributes(p)
          if a and a.mode == "directory" then
            repos[#repos + 1] = { name = name, path = p, norm = normalize(name), tokens = tokenSet(name) }
          end
        end
      end
    end
  end
end

-- Re-scan the repo roots if the list has gone stale. Without this, loadRepos()
-- ran once in start() and a repo CREATED AFTER Hammerspoon loaded its config
-- stayed invisible to the title-hint and token rules until the next Reload
-- Config — the Desktop would show "—" or the bare app name instead of the repo.
-- Cheap: a dir listing plus a stat per entry, against the ~40ms
-- hs.window.allWindows() that every read already pays.
local function refreshRepos()
  if hs.timer.secondsSinceEpoch() - reposLoadedAt >= (M.repoRescanSeconds or 30) then
    loadRepos()
  end
end

-- Ask Terminal for every window's title. Terminal's own scripting dictionary
-- reports windows on ALL Spaces, which Accessibility cannot do — that is the
-- whole reason the dot can stay live for a Desktop you are not looking at.
-- Guarded by `is running` so it never launches Terminal just to ask.
local CLAUDE_TITLE_SCRIPT = [[
if application "Terminal" is running then
  tell application "Terminal"
    set out to ""
    -- Which window is frontmost, so a session you are actually looking at can
    -- be marked as seen. `front window` raises when there are none.
    try
      set out to "FRONT|" & ((id of front window) as text) & linefeed
    end try
    repeat with w in windows
      set out to out & ((id of w) as text) & "|" & (name of w) & linefeed
    end repeat
    return out
  end tell
else
  return ""
end if
]]

local function firstCodepoint(s)
  if not (utf8 and utf8.codepoint) or not s or s == "" then return nil end
  local ok, cp = pcall(utf8.codepoint, s, 1)
  return ok and cp or nil
end

-- A Terminal title looks like:
--   "<cwd basename> — <glyph> <task summary> — caffeinate ◂ claude — 254×64"
-- The trailing process component varies with whatever child is running
-- (caffeinate, security, …), so match "claude" anywhere rather than exactly.
-- Returns two views of the same read:
--   byRepo   repo name -> state, collapsed. Drives the Desktop-mode dot.
--   sessions one entry per claude window, NOT collapsed. Drives terminal mode,
--            so two sessions in the same repo stay two lines.
--
-- Terminal's own window `id` is what makes per-session identity possible: it is
-- stable for the life of the window and unique even when two windows sit in the
-- same directory, which a repo name cannot distinguish.
-- If this window title belongs to a claude session, return its working
-- directory name. Terminal builds titles as: cwd — <spinner + task> — process
-- — WxH, so a real session has all four parts and names claude as the process.
local function claudeCwdFromTitle(title)
  local comps = {}
  for part in (tostring(title or "") .. " — "):gmatch("(.-) — ") do comps[#comps + 1] = part end
  local proc = comps[#comps - 1]
  if #comps >= 4 and proc and proc:lower():find("claude", 1, true) then
    return comps[1], comps[2] or ""
  end
  return nil
end

local function parseClaudeTitles(text)
  local byRepo, sessions, frontId = {}, {}, nil
  for line in tostring(text or ""):gmatch("[^\r\n]+") do
    local fid = line:match("^FRONT|(%d+)$")
    if fid then frontId = tonumber(fid) end
    local wid, title = line:match("^(%d+)|(.*)$")
    if not title then title = line end            -- tolerate an id-less read
    local cwd, body = claudeCwdFromTitle(title)
    if cwd then
      body = body or ""
      local glyph = body:match("^(.-)%s") or ""
      local cp = firstCodepoint(glyph)
      -- Braille block: the spinner Claude Code animates while computing.
      local state = (cp and cp >= 0x2800 and cp <= 0x28FF) and "working" or "idle"
      local key = cwd:lower()
      if byRepo[key] ~= "working" then byRepo[key] = state end  -- any busy session wins
      sessions[#sessions + 1] = {
        wid = tonumber(wid), project = cwd, state = state,
        summary = body:gsub("^%S+%s*", ""),      -- task text, minus the spinner
      }
    end
  end
  -- Terminal ids ascend with creation order, so ordering is stable across polls
  -- and T1/T2/T3 keep meaning without anyone registering anything.
  table.sort(sessions, function(a, b) return (a.wid or 0) < (b.wid or 0) end)
  return byRepo, sessions, frontId
end

-- Sessions mode's equivalent of visiting a Desktop: if you are actually looking
-- at a session's window, its finished-and-unseen flag is cleared. Clicking the
-- dashboard line used to be the only way, so going to the window directly — or
-- typing into it — left the dot stuck green.
--
-- Terminal always reports a `front window` even when Terminal isn't the active
-- app, so the frontmost-application check matters: without it a session would be
-- marked seen while you were working in something else entirely.
local function acknowledgeFrontSession(frontId)
  if not (frontId and M.showClaudeDot) then return end
  local ok, app = pcall(hs.application.frontmostApplication)
  if not (ok and app) then return end
  local name = app:name()
  if not (name and (M.claudeOnlyHintApps[name] or name == "Terminal")) then return end
  sessionDone[frontId] = nil
end

-- One small JSON file per live session, written by the Claude Code hooks. Local
-- file reads on a handful of tiny files — cheap enough for the 3s cycle.
local function readHookStates()
  local out = {}
  local dir = M.claudeStateDir
  if not (dir and hs.fs.attributes(dir)) then return out end
  local maxAge = (M.claudeHookMaxAgeHours or 12) * 3600
  local now = os.time()
  pcall(function()
    for name in hs.fs.dir(dir) do
      if name:sub(-5) == ".json" then
        local t = hs.json.read(dir .. "/" .. name)
        if type(t) == "table" and t.repo and t.state then
          -- A session killed without SessionEnd leaves its file behind; age it out
          -- so a stale "waiting" cannot pin a Desktop red forever.
          if not t.at or (now - t.at) <= maxAge then
            local key = tostring(t.repo):lower()
            -- Several sessions in one repo: the one wanting you wins.
            if t.state == "waiting" or out[key] == nil then out[key] = t.state end
          end
        end
      end
    end
  end)
  return out
end

-- What the panel would show: title state, the unacknowledged flag, and the hook
-- state, since the dot depends on all three. Decides whether to repaint.
local function dotKey()
  local keys = {}
  for k, v in pairs(claudeStates) do
    keys[#keys + 1] = k .. "=" .. v .. (claudeDone[k] and "!" or "") .. "/" .. tostring(claudeHooks[k])
  end
  for _, s in ipairs(sessions) do
    keys[#keys + 1] = "w" .. tostring(s.wid) .. "=" .. s.state ..
                      (sessionDone[s.wid] and "!" or "") .. "/" .. tostring(s.summary)
  end
  table.sort(keys)
  return table.concat(keys, ",")
end

-- Same working -> not-working edge as noteTransitions, but per terminal window
-- rather than per repo, so two sessions in one repo flag independently.
local function noteSessionTransitions(list)
  local seen = {}
  for _, s in ipairs(list) do
    local id = s.wid
    if id then
      seen[id] = true
      if s.state == "working" then sessionDone[id] = nil
      elseif sessionPrev[id] == "working" then sessionDone[id] = true end
      sessionPrev[id] = s.state
    end
  end
  for id in pairs(sessionPrev) do
    if not seen[id] then sessionPrev[id] = nil; sessionDone[id] = nil end
  end
end

-- A completion is the working -> not-working edge. Starting work again clears
-- the flag, so a session you re-prompt stops nagging on its own.
local function noteTransitions(fresh)
  for key, state in pairs(fresh) do
    if state == "working" then
      claudeDone[key] = nil
    elseif claudePrev[key] == "working" then
      claudeDone[key] = true
    end
  end
  for key in pairs(claudeDone) do
    if not fresh[key] then claudeDone[key] = nil end   -- session went away
  end
  claudePrev = fresh
end

-- Clear the flag for the Desktops you are looking at. Clicking a line switches
-- you to that Desktop, so it acknowledges through this path too — there is no
-- separate click target on the dot itself.
--
-- Takes the Space ids rather than looking them up: the caller (scanActive) has
-- already paid for activeSids(), and hs.spaces calls are slow enough that
-- repeating them on the dot's 3s timer would be a real cost.
local function acknowledgeSids(sids)
  if not M.showClaudeDot then return false end
  local changed = false
  for _, sid in ipairs(sids or {}) do
    -- Same reason as claudeStateFor: the flag is keyed by repo, so a renamed
    -- Desktop would never clear its own green dot.
    local label = labelCache[sid]
    if label then
      local key = tostring(label):lower()
      if claudeDone[key] then claudeDone[key] = nil; changed = true end
    end
  end
  return changed
end

-- Refresh asynchronously via hs.task: an Apple Event to a wedged Terminal must
-- never stall Hammerspoon the way the old per-window AX reads did. Measured:
-- the same call made synchronously from the console blocked long enough to
-- time out Hammerspoon's own IPC.
local function refreshClaudeStates()
  if not M.showClaudeDot then claudeStates = {}; return end
  if claudeTask then return end                     -- one request in flight
  local now = hs.timer.secondsSinceEpoch()
  -- Half the interval, so timer jitter can never make a tick skip itself.
  if now - claudeStatesAt < (M.claudeDotSeconds or 3) * 0.5 then return end
  claudeStatesAt = now
  local ok, t = pcall(hs.task.new, "/usr/bin/osascript", function(_, stdout, _)
    claudeTask = nil
    local before = dotKey()
    local frontId
    claudeStates, sessions, frontId = parseClaudeTitles(stdout)
    claudeHooks  = readHookStates()
    noteTransitions(claudeStates)
    noteSessionTransitions(sessions)
    acknowledgeFrontSession(frontId)   -- the window you're looking at is "seen"
    -- Acknowledgement is left to scanActive / the space watcher, which already
    -- know which Spaces are active; asking hs.spaces again here would be slow.
    -- Redraw only when a dot actually changed. draw() tears down and rebuilds
    -- every canvas, so repainting on an unchanged result is pure churn.
    if dotKey() ~= before then pcall(draw) end
  end, { "-e", CLAUDE_TITLE_SCRIPT })
  if ok and t then claudeTask = t; t:start() end
end

-- ---- git status dot (local/offline) ---------------------------------------

-- Single-quote a path for safe embedding in the /bin/sh script below.
local function shQuote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- A stable fingerprint of the git dots, so we only redraw when one changes.
local function gitDotKey()
  local keys = {}
  for k, v in pairs(gitStates) do keys[#keys + 1] = k .. "=" .. v end
  table.sort(keys)
  return table.concat(keys, ",")
end

-- Local git status for every known repo, in ONE sh pass so a dozen repos cost
-- one hs.task rather than a dozen. Purely offline: `status --porcelain` for a
-- dirty tree, `rev-list @{u}..HEAD` for unpushed commits. A folder under
-- repoRoots that is not a git repo prints "none" and gets no dot.
-- GIT_TERMINAL_PROMPT=0 guarantees a mis-set remote can never pop a credential
-- prompt and hang the task. Only one %s (the path list); every other % is %%.
local GIT_LOCAL_SNIPPET = [[
export GIT_TERMINAL_PROMPT=0
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
for d in %s; do
  if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    dirty=$(git -C "$d" status --porcelain 2>/dev/null)
    ahead=$(git -C "$d" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    if [ -n "$dirty" ] || [ "${ahead:-0}" != "0" ]; then st=changed; else st=clean; fi
  else
    st=none
  fi
  printf '%%s\t%%s\n' "$d" "$st"
done
]]

local function refreshGitStates()
  if not M.showGitDot then gitStates = {}; return end
  if gitTask then return end                         -- one request in flight
  local now = hs.timer.secondsSinceEpoch()
  if now - gitStatesAt < (M.gitDotSeconds or 15) * 0.5 then return end
  gitStatesAt = now
  if #repos == 0 then return end
  local parts, nameOf = {}, {}
  for _, r in ipairs(repos) do
    if r.path then parts[#parts + 1] = shQuote(r.path); nameOf[r.path] = tostring(r.name):lower() end
  end
  if #parts == 0 then return end
  local script = string.format(GIT_LOCAL_SNIPPET, table.concat(parts, " "))
  local ok, t = pcall(hs.task.new, "/bin/sh", function(_, stdout, _)
    gitTask = nil
    local fresh = {}
    for line in tostring(stdout or ""):gmatch("[^\n]+") do
      local p, st = line:match("^(.*)\t(%S+)$")
      if p and st and st ~= "none" then
        local key = nameOf[p]
        if key then fresh[key] = st end
      end
    end
    local before = gitDotKey()
    gitStates = fresh
    if gitDotKey() ~= before then pcall(draw) end
  end, { "-c", script })
  if ok and t then gitTask = t; t:start() end
end

-- ---- remote alerts: a session on ANOTHER Mac is blocked on you -------------
--
-- The claude dot answers "which Desktop wants me" for the machine you are
-- sitting at. It cannot answer it for a Mac in another building, which is the
-- case that actually costs time: a session stops for a permission prompt at
-- 09:00 and is found still sitting there at 11:00.
--
-- claude-dashboard-state.sh already fires at exactly that instant, so it drops a
-- marker into a shared folder; this reads them. Deliberately a DIFFERENT
-- mechanism from the ssh replica: no VPN, no reachability, no live connection —
-- the marker is a fact that was true when it was written, and a file that syncs
-- is enough to carry it.
--
-- Markers from THIS host are ignored: the red dot is already saying it, on the
-- screen in front of you.
local remoteAlerts   = {}     -- { {host=, repo=, at=, key=}, ... } newest first
local remoteSeen     = {}     -- key -> true, so a marker notifies once
local remotePrimed   = false  -- first read never notifies; see below
-- remoteDebounce is held in a file-scope local for the reason CLAUDE.md records:
-- an hs.timer with nothing referencing it can be collected before it fires.
local remoteWatcher, remoteTimer, remoteDebounce, localHostName

-- Parsed markers, keyed by name and mtime. Two reasons, and the second is the
-- one that forced it: a file being synced can be read mid-write, and every
-- failed parse writes a LuaSkin error to the Hammerspoon console — on a timer,
-- forever, for one bad file. Caching the FAILURE too means it is logged once
-- per version of the file rather than once per read. (Measured while testing:
-- a deliberately malformed marker logged on every pass.)
local remoteParse = {}      -- "name\0mtime" -> table | false

local function readMarker(dir, f)
  local at = hs.fs.attributes(dir .. "/" .. f)
  local key = f .. "\0" .. tostring(at and at.modification or 0)
  local hit = remoteParse[key]
  if hit ~= nil then return hit or nil end
  local t = hs.json.read(dir .. "/" .. f)
  remoteParse[key] = (type(t) == "table") and t or false
  return (type(t) == "table") and t or nil
end

local function readRemoteAlerts()
  local dir = M.remoteAlertDir
  if not (M.showRemoteAlerts and dir) then remoteAlerts = {}; return end
  local fresh, now = {}, os.time()
  local maxAge = (M.remoteAlertMaxAgeHours or 12) * 3600
  local seenKeys = {}
  local ok = pcall(function()
    for f in hs.fs.dir(dir) do
      if f:sub(-5) == ".json" then
        seenKeys[f] = true
        local t = readMarker(dir, f)
        -- A session killed without SessionEnd leaves its marker behind, and a
        -- stale one would pin an alert forever — the same guard the hook state
        -- files carry, for the same reason.
        if type(t) == "table" and t.repo and (now - (tonumber(t.at) or 0)) < maxAge then
          if not (localHostName and t.host == localHostName) then
            fresh[#fresh + 1] = { host = t.host or "?", repo = t.repo,
                                  at = tonumber(t.at) or 0, key = f }
          end
        end
      end
    end
  end)
  if not ok then return end        -- folder missing / mid-sync: keep what we had
  -- Drop cache entries for files that are gone, so a long-lived Hammerspoon
  -- doesn't accumulate one entry per marker per edit for the rest of the login.
  for k in pairs(remoteParse) do
    if not seenKeys[k:match("^(.-)%z") or ""] then remoteParse[k] = nil end
  end
  table.sort(fresh, function(a, b) return a.at > b.at end)
  remoteAlerts = fresh
end

-- A macOS notification for each marker not seen before. The first read after
-- launch only PRIMES the seen-set: markers already sitting in the folder are
-- history, and announcing them at every login is how a signal becomes noise —
-- the same reason sessions already idle at launch never get a green dot.
local function noteRemoteAlerts()
  local present = {}
  for _, a in ipairs(remoteAlerts) do present[a.key] = true end
  if remotePrimed and M.remoteAlertNotify ~= false then
    for _, a in ipairs(remoteAlerts) do
      if not remoteSeen[a.key] then
        pcall(function()
          hs.notify.new({ title = "Claude waiting — " .. a.repo,
                          subTitle = a.host,
                          informativeText = "A session is blocked on a question.",
                          withdrawAfter = 0 }):send()
        end)
      end
    end
  end
  remotePrimed = true
  -- Forget cleared markers, so the same repo blocking again notifies again.
  for k in pairs(remoteSeen) do if not present[k] then remoteSeen[k] = nil end end
  for k in pairs(present) do remoteSeen[k] = true end
end

local function refreshRemoteAlerts()
  local before = #remoteAlerts
  local beforeKey = remoteAlerts[1] and remoteAlerts[1].key or ""
  readRemoteAlerts()
  noteRemoteAlerts()
  -- draw() rebuilds every canvas, so only redraw when the line would change.
  if #remoteAlerts ~= before or (remoteAlerts[1] and remoteAlerts[1].key or "") ~= beforeKey then
    pcall(draw)
  end
end

local function categorize(app)
  if M.categories[app] then return M.categories[app] end
  for _, r in ipairs(M.categoryPatterns) do
    if app:find(r.pat, 1, true) then return r.cat end
  end
  return app
end

-- Match case-insensitively: macOS volumes are normally case-insensitive, so a
-- repoRoots entry of "~/Git_repos" happily lists "~/Git_Repos" via hs.fs.dir
-- but would never prefix-match the real document path returned by AXDocument.
-- The segment is sliced off the ORIGINAL path so the repo keeps its true case.
local function repoForPath(path)
  if not path or path == "" then return nil end
  local lpath = path:lower()
  for _, root in ipairs(M.repoRoots) do
    local lroot = root:lower()
    if lpath:sub(1, #lroot + 1) == lroot .. "/" then
      local seg = path:sub(#root + 2):match("^([^/]+)/")
      if seg then return seg end
    end
  end
  return nil
end

-- funcs: functional (non-ignored) windows on the Desktop.
-- ctx:   text of ALL window titles on the Desktop (incl. Terminal/Finder) plus
--        the functional apps' names — used only to spot a repo name.
--
-- Returns the label AND the kind of evidence behind it: "repo", "cwd", "app"
-- (one app, so the label is its name), "apps" (two or more apps, so the label
-- is a bucket — Utility or a shared category), or "none". Only "apps" earns
-- icons: the label there names a grouping rather than the work, which is
-- exactly the case the icons replace. Every existing caller reads the first
-- value only, so the second is additive.
local function detectLabel(funcs, ctx, claudeCwd)
  -- 1) an open document inside a repo (editor apps only).
  for _, w in ipairs(funcs) do
    local repo = repoForPath(w.doc)
    if repo then return repo, "repo" end
  end
  -- 1.5) a claude session running here. Its working directory is a fact about
  --      this Desktop, so it outranks any repo name merely *mentioned* in some
  --      window's text — and it works whether or not the directory is a repo.
  if claudeCwd and claudeCwd ~= "" then return claudeCwd, "cwd" end
  -- 2) a repo name in any title on the Desktop — the claude terminal's title
  --    or a Finder window parked in the repo both count as a hint.
  local nc = normalize(ctx or "")
  local proj, projLen = nil, 0
  for _, r in ipairs(repos) do
    if #r.norm >= 4 and nc:find(r.norm, 1, true) and #r.norm > projLen then proj, projLen = r.name, #r.norm end
  end
  if proj then return proj, "repo" end
  -- 3) token overlap.
  local ctoks = tokenSet(nc)
  local best, bestScore = nil, 1
  for _, r in ipairs(repos) do
    local score = 0
    for t in pairs(r.tokens) do if ctoks[t] then score = score + 1 end end
    if score > bestScore then best, bestScore = r.name, score end
  end
  if best then return best, "repo" end
  -- 4) no repo — fall back to the apps. One app → its own name (Mail); several
  --    apps sharing one subject → that subject (Communication); several
  --    different subjects → Utility.
  if #funcs == 0 then return "—", "none" end
  local cats, catOrder, apps, appOrder = {}, {}, {}, {}
  for _, w in ipairs(funcs) do
    local c = categorize(w.app)
    if not cats[c] then cats[c] = true; catOrder[#catOrder + 1] = c end
    if not apps[w.app] then apps[w.app] = true; appOrder[#appOrder + 1] = w.app end
  end
  if #catOrder >= (M.utilityMinSubjects or 2) then return M.utilityLabel or "Utility", "apps" end
  if #appOrder == 1 then                          -- single app → its own name
    return M.appLabels[appOrder[1]] or appOrder[1], "app"
  end
  return catOrder[1] or "?", "apps"                -- several apps, one subject
end

-- ---- reading the visible Desktops (cheap, reliable) -----------------------

local function docOf(w)
  local ok, el = pcall(hs.axuielement.windowElement, w)
  if not ok or not el then return nil end
  local d = el:attributeValue("AXDocument")
  if not d or d == "" then return nil end
  return (tostring(d):gsub("^file://", "")
    :gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

-- hs.spaces queries reach through the Dock's accessibility element and THROW
-- when that lookup transiently fails ("Unable to fetch NSRunningApplication for
-- pid: …"). They do not return nil, so the `or {}` idiom cannot catch it, and a
-- single throw inside a timer callback was enough to kill the whole ⌘⌃⌥S walk
-- part way through. Every query goes through these wrappers.
local function safeSpacesForScreen(scr)
  local ok, v = pcall(hs.spaces.spacesForScreen, scr)
  return (ok and type(v) == "table") and v or {}
end

local function safeActiveSpace(scr)
  local ok, v = pcall(hs.spaces.activeSpaceOnScreen, scr)
  return ok and v or nil
end

-- nil means "could not read this Space", which is NOT the same as "no windows
-- on it" — the caller must keep the previous label rather than blank it.
local function safeWindowsForSpace(sid)
  local ok, v = pcall(hs.spaces.windowsForSpace, sid)
  if ok and type(v) == "table" then return v end
  return nil
end

local function activeSids()
  local t = {}
  for _, s in ipairs(hs.screen.allScreens()) do
    local sid = safeActiveSpace(s)
    if sid then t[#t + 1] = sid end
  end
  return t
end

-- Build the on-screen window list ONCE (this is the ~40ms call) and index it
-- by window id, so per-Desktop reads are just cheap hash lookups instead of a
-- fresh hs.window.get() — the ~40ms-per-call trap — for every window id.
local function snapshot()
  local byId = {}
  local ok, all = pcall(hs.window.allWindows)
  if ok and all then
    for _, w in ipairs(all) do
      local oki, id = pcall(function() return w:id() end)
      if oki and id then byId[id] = w end
    end
  end
  -- A SECOND index, from CoreGraphics, for windows Accessibility cannot see at
  -- all. Measured 2026-07-30: the Claude desktop app returns nil for every AX
  -- attribute — no role, no windows, nothing — so a Desktop holding it and
  -- ChatGPT read as empty ("—") however many windows were actually on it, while
  -- CoreGraphics listed both at layer 0. This is on-screen only, which is
  -- exactly the Space(s) macOS lets us read anyway. ~14 ms, the same order as
  -- allWindows() above, and like it: ONCE per read pass, never per window.
  local byCg = {}
  local okc, list = pcall(hs.window.list, true)
  if okc and type(list) == "table" then
    for _, e in ipairs(list) do
      if e.kCGWindowNumber then byCg[e.kCGWindowNumber] = e end
    end
  end
  return byId, byCg
end

-- Functional windows on a Space (from the snapshot) + the context text used
-- for repo hints. Terminal/Finder are excluded from the subject decision but
-- their titles still feed the repo hint.
local function readSpaceFrom(byId, sid, byCg)
  local funcs, ctx, claudeCwd, extras = {}, {}, nil, {}
  local ghosts, ghostSeen = {}, {}      -- apps only CoreGraphics can see
  local ids = safeWindowsForSpace(sid)
  if not ids then return nil end        -- transient failure; caller keeps old label
  for _, id in ipairs(ids) do
    local w = byId[id]
    if not w and byCg then
      -- Accessibility didn't produce this window. CoreGraphics may still know
      -- who owns it. Layer 0 is an ordinary application window; everything
      -- above (25, 24, …) is menu-bar extras, Spotlight, the Dock, us. All we
      -- get is the owner, so these contribute an ICON and nothing else — no
      -- title, no document, so they can never affect repo detection.
      local e = byCg[id]
      if e and e.kCGWindowLayer == 0 then
        local app = tostring(e.kCGWindowOwnerName or "")
        if app ~= "" and not ghostSeen[app] then
          ghostSeen[app] = true
          local pid = e.kCGWindowOwnerPID
          local a   = pid and hs.application.applicationForPID(pid)
          local bid = a and a:bundleID() or nil
          local rec = { app = app, bundle = bid, pid = pid, title = "" }
          if not M.ignoreApps[app] then ghosts[#ghosts + 1] = rec
          elseif isTrailingIconApp(app) then extras[#extras + 1] = rec end
        end
      end
    end
    if w then
      local oks, std = pcall(function() return w:isStandard() end)
      if oks and std then
        local appObj = w:application()
        local app = appObj and appObj:name() or ""
        if app ~= "" then
          local title = w:title() or ""
          -- A claude session on this Desktop names its working directory, which
          -- is a better label than anything else available — even when that
          -- directory is not one of the repo roots.
          local sessCwd = claudeCwdFromTitle(title)
          if sessCwd and not claudeCwd then claudeCwd = sessCwd end
          -- Decide what of this window's title may suggest a repo. Three cases:
          -- never (browsers, chat apps, Finder), only-if-claude (terminals),
          -- and everything else, which contributes its whole title.
          local hint, hintText = true, title
          if M.noRepoHintApps[app] then
            hint = false
          elseif M.claudeOnlyHintApps[app] then
            -- A session contributes ONLY its working directory. Its task summary
            -- is prose about the work, and repo names matched inside prose are
            -- where every false positive so far has come from: a summary reading
            -- "config structure for Claude projects" shares two tokens with the
            -- repo `claude-config` and relabeled the Desktop after it.
            hint, hintText = sessCwd ~= nil, sessCwd
          end
          if hint and hintText then ctx[#ctx + 1] = hintText end
          -- bundleID comes from the running application object we already hold
          -- — no accessibility call, so it costs nothing. It is what
          -- hs.image.imageFromAppBundle needs to draw the app's icon.
          local okb, bid = pcall(function() return appObj:bundleID() end)
          if not M.ignoreApps[app] then
            ctx[#ctx + 1] = app
            funcs[#funcs + 1] = { win = w, app = app, title = title,
                                  bundle = (okb and bid) or nil,
                                  doc = M.docApps[app] and docOf(w) or nil }  -- editors only
          elseif isTrailingIconApp(app) then
            -- Finder and terminals are ignored for the SUBJECT — a Desktop is
            -- never *about* Finder — but "there is a Finder and two terminals
            -- here" is still worth knowing, so they earn an icon at the end of
            -- the row. Hammerspoon stays out: it is this panel.
            extras[#extras + 1] = { win = w, app = app, title = title,
                                    bundle = (okb and bid) or nil }
          end
        end
      end
    end
  end
  return funcs, table.concat(ctx, " "), claudeCwd, extras, ghosts
end

-- The distinct apps in a window list, in the order they were read, as
-- { bundle, app, wid, title }. Deduped by bundle id, because two windows of the
-- same app are one icon. `seen` is shared across calls so the trailing pass
-- can't repeat an app the leading pass already drew.
-- Each entry carries the id of the FIRST window of that app on the Desktop,
-- which is the window a click on the icon raises, and that window's title, which
-- the hover tip shows so you know which one you're about to get.
local function collectIcons(windows, out, seen)
  for _, w in ipairs(windows) do
    if w.bundle and w.bundle ~= "" and not seen[w.bundle] then
      seen[w.bundle] = true
      -- A CoreGraphics-only entry has no window object, so it carries its
      -- owner's pid instead: enough to raise the app, not a specific window.
      local wid
      if w.win then
        local okid, id = pcall(function() return w.win:id() end)
        wid = okid and id or nil
      end
      out[#out + 1] = { bundle = w.bundle, app = w.app, title = w.title,
                        wid = wid, pid = w.pid }
    end
  end
  return out
end

-- The whole icon row for a Desktop: the subject apps first, then Finder and any
-- terminals. `named` says the line keeps a text name (a repo, a session's
-- directory) that the icons follow rather than replace; `min` is how many
-- LEADING icons must resolve before the row may stand in for a word.
local function buildIconList(funcs, extras, ghosts, kind)
  local named = (kind == "repo" or kind == "cwd")
  local seen  = {}
  local list  = collectIcons(funcs, {}, seen)
  collectIcons(ghosts or {}, list, seen)       -- subject apps too, so still leading
  local lead  = #list                          -- everything after this is trailing
  local tail  = {}
  for _, w in ipairs(extras or {}) do
    -- A terminal is dropped from a Desktop named after a repo or a session's
    -- directory: that name came from the terminal, so its icon would only say
    -- the same thing twice. Finder is never redundant that way.
    if not (named and M.claudeOnlyHintApps[w.app]) then tail[#tail + 1] = w end
  end
  collectIcons(tail, list, seen)
  list.lead  = lead
  list.named = named
  -- Below this many leading icons the word is kept instead: one icon standing
  -- in for a three-app Desktop would claim the others aren't there. A named
  -- Desktop keeps its name regardless, so it has no such threshold.
  list.min   = named and 0 or ((kind == "app") and 1 or (kind == "apps") and 2 or 0)
  return list
end

local function labelSpace(byId, sid, byCg)
  local funcs, ctx, claudeCwd, extras, ghosts = readSpaceFrom(byId, sid, byCg)
  if not funcs then return end   -- unreadable this time; better a stale name than "—"
  local label, kind = detectLabel(funcs, ctx, claudeCwd)
  labelCache[sid] = label
  -- Every Desktop now gets an icon row. On one whose label names APPS (a bucket
  -- like Utility, or a single app's name) the icons REPLACE that word; on one
  -- named after a repo or a session's directory they FOLLOW the name, which no
  -- icon could express.
  iconApps[sid]   = buildIconList(funcs, extras, ghosts, kind)
  lastGather[sid] = funcs
  liveRead[sid]   = true         -- this Desktop is now first-hand, not restored
end

-- Read the Desktop(s) currently active on each display (one snapshot for all).
local function scanActive()
  refreshRepos()
  refreshClaudeStates()
  refreshGitStates()
  local byId, byCg = snapshot()
  local sids = activeSids()
  for _, sid in ipairs(sids) do labelSpace(byId, sid, byCg) end
  acknowledgeSids(sids)          -- you are looking at these Desktops right now
  if not scanningAll then M.status = nil end   -- clear any stale scan status
end

-- Functional windows on the active Desktops, tagged with their Space (restore).
local function openWindows()
  local out = {}
  local byId = snapshot()
  for _, sid in ipairs(activeSids()) do
    local funcs = readSpaceFrom(byId, sid)
    for _, w in ipairs(funcs) do w.sid = sid; out[#out + 1] = w end
  end
  return out
end

-- ---- drawing (cheap; uses cache only) ------------------------------------

-- The dot is shown only for a Desktop whose label IS a repo name and which has
-- a claude session in that repo — matching the Terminal title's cwd component
-- against the label, which needs no window-to-Space mapping.
-- "working" (yellow), "done" (green, finished and unacknowledged), or nil for
-- no dot at all — which covers both "no session here" and "you've seen it".
local function claudeStateFor(label)
  if not M.showClaudeDot then return nil end
  local key = tostring(label or ""):lower()
  if key == "" then return nil end
  local state = claudeStates[key]
  if not state then return nil end
  -- No repo-membership test: the key already had to match a live session's
  -- working directory, and a session in ~ is just as real as one in a repo.
  -- Computing beats everything: once you answer a question the session resumes,
  -- the spinner returns, and the dot goes yellow without waiting on a hook.
  if state == "working" then return "working" end
  -- Not computing. Only the hooks can say whether that is "blocked on you"
  -- (red) or "finished" (green) — the title looks identical either way.
  if claudeHooks[key] == "waiting" then return "waiting" end
  if claudeDone[key] then return "done" end
  return nil
end

-- The git dot for a label: "changed" (red), "clean" (green), or nil (the label
-- is not one of your repos, or its status has not been read yet). Looked up by
-- the DETECTED repo, exactly like claudeStateFor, so a ⌘⌃⌥N rename keeps its dot.
local function gitStateFor(label)
  if not M.showGitDot then return nil end
  local key = tostring(label or ""):lower()
  if key == "" then return nil end
  return gitStates[key]
end

-- A dot descriptor for the styledtext renderer: a glyph plus the colour it
-- should be drawn in (nil colour => a blank spacer, so lines stay aligned).
local function claudeDotSpec(state)
  local ch = state and (M.claudeDotChar or "●") or " "
  return { ch = ch, color = state and (M.claudeDotColors or {})[state] or nil }
end
local function gitDotSpec(state)
  local ch = state and (M.gitDotChar or "●") or " "
  return { ch = ch, color = state and (M.gitDotColors or {})[state] or nil }
end

-- Fill the empty slots of a line that already shows at least one live dot with
-- a dim gray dot, so both columns are visible and position tells the two apart.
-- A line with no live dot at all is left blank: gray everywhere would say
-- nothing and cost the panel two columns of noise on every Desktop.
local function withPlaceholders(dots)
  if not M.showDotPlaceholders then return dots end
  local live = false
  for _, d in ipairs(dots) do if d.color then live = true; break end end
  if not live then return dots end
  for _, d in ipairs(dots) do
    if not d.color then
      d.ch    = M.claudeDotChar or "●"
      d.color = M.dotPlaceholderColor or { white = 0.42, alpha = 1 }
      d.faint = true
    end
  end
  return dots
end

-- An app icon, memoized: icons don't change while Hammerspoon runs, and draw()
-- rebuilds every canvas. `false` records "this bundle has no icon" so a failed
-- lookup isn't retried on every redraw.
local function iconImageFor(bundle)
  local cached = iconImages[bundle]
  if cached ~= nil then return cached or nil end
  local ok, img = pcall(hs.image.imageFromAppBundle, bundle)
  iconImages[bundle] = (ok and img) or false
  return iconImages[bundle] or nil
end

-- The icon row for a Desktop, or nil if there is nothing to draw. `list.min`
-- (set when the Desktop was read) is how many LEADING icons must resolve before
-- the row may stand in for a word: two for a mixed Desktop, where a lone icon
-- would misrepresent what's there and `Utility` is at least honest about being
-- a summary; one for a single-app Desktop; none for a Desktop that keeps its
-- name anyway. Trailing icons (Finder, terminals) never count toward it —
-- a Finder must not be what lets a three-app Desktop lose the word.
local function iconsFor(sid)
  if not M.showAppIcons then return nil end
  local list = iconApps[sid]
  if not list then return nil end
  local min, lead = list.min or 0, list.lead or #list
  local items, extra, leadOK = {}, 0, 0
  for i, a in ipairs(list) do
    local img = iconImageFor(a.bundle)
    if img then
      if i <= lead then leadOK = leadOK + 1 end
      if #items < (M.maxAppIcons or 6) then
        items[#items + 1] = { img = img, app = a.app, title = a.title, wid = a.wid }
      else
        extra = extra + 1
      end
    end
  end
  if leadOK < min or #items == 0 then return nil end
  return { items = items, extra = extra, named = list.named }
end

-- How many monospaced characters the icon row occupies, so the existing
-- width calculation (which counts characters) sizes the panel to fit it.
local function iconTextPad(icons)
  local size, gap = iconMetrics()
  local w = #icons.items * (size + gap)
  if icons.extra > 0 then w = w + charWidth() * uwidth("+" .. icons.extra) end
  return math.ceil(w / charWidth())
end

-- One line per live claude session: "T1 ●● project — summary" (claude dot,
-- then git dot).
--
-- Yellow and green are per session, because the spinner is read from that
-- window's own title. Red is per repo: the hooks record a session id and a cwd,
-- and there is no key joining a hook file to a Terminal window — so if two
-- sessions share a repo and one is asking you something, both show red.
local function sessionEntries()
  local entries = {}
  for i, s in ipairs(sessions) do
    local key   = tostring(s.project or ""):lower()
    local state = nil
    if M.showClaudeDot then
      if s.state == "working" then state = "working"
      elseif claudeHooks[key] == "waiting" then state = "waiting"
      elseif sessionDone[s.wid] then state = "done" end
    end
    local dots = withPlaceholders({ claudeDotSpec(state), gitDotSpec(gitStateFor(s.project)) })
    local mid  = dots[1].ch .. " " .. dots[2].ch     -- " " ≈ the half-gap, for width sizing
    local summary = tostring(s.summary or "")
    local lim = M.sessionSummaryChars or 20
    if uwidth(summary) > lim then summary = summary:sub(1, lim) .. "…" end
    local prefix  = string.format("   T%d ", i)
    local project = " " .. (s.project or "?")

    if M.sessionTwoLine then
      entries[#entries + 1] = {
        wid = s.wid, dots = dots,
        prefix = prefix, suffix = project, text = prefix .. mid .. project,
      }
      if summary ~= "" then
        -- Indented past where the project name starts, and dimmed, so the pair
        -- reads as one item rather than two. Carries the same window id, so
        -- either line can be clicked. +2 to clear both dots.
        local indent = string.rep(" ", uwidth(prefix) + 2 + (M.sessionSummaryIndent or 5))
        local line2  = indent .. summary
        entries[#entries + 1] = {
          wid = s.wid, dots = {}, dim = true,
          prefix = line2, suffix = "", text = line2,
        }
      end
    else
      local suffix = project .. (summary ~= "" and ("  " .. summary) or "")
      entries[#entries + 1] = {
        wid = s.wid, dots = dots,
        prefix = prefix, suffix = suffix, text = prefix .. mid .. suffix,
      }
    end
  end
  if #entries == 0 then
    local msg = "   (no claude sessions found)"
    entries[1] = { dots = {}, prefix = msg, suffix = "", text = msg }
  end
  return entries
end

local function screenEntries(screen)
  local spaces = safeSpacesForScreen(screen)
  local active = safeActiveSpace(screen)
  local entries = {}
  for i, sid in ipairs(spaces) do
    local auto  = labelCache[sid]
    -- Look the dot up by the DETECTED repo, never by what is displayed. A name
    -- you set with ⌘⌃⌥N replaces the label but not the repo, and matching on the
    -- displayed name silently cost every renamed Desktop its dot.
    local state = claudeStateFor(auto)
    -- Desktops with no session / non-repo labels keep blank dot slots so the
    -- arrows stay aligned. Both dots are keyed off the DETECTED label (auto).
    local dots   = withPlaceholders({ claudeDotSpec(state), gitDotSpec(gitStateFor(auto)) })
    local mid    = dots[1].ch .. " " .. dots[2].ch   -- " " ≈ the half-gap, for width sizing
    local here   = (sid == active)
    local prefix = string.format("%sDesktop %d ",
      here and (M.activeMarker or "▸  ") or (M.inactiveMarker or "   "), i)
    -- A line is TWO independent parts: a name, then the icon row. ⌘⌃⌥N replaces
    -- the name and nothing else — the icons report what is actually on the
    -- Desktop, which renaming it cannot change. The name is empty only when the
    -- icons are standing in for a word that named apps (Utility, MacDown); a
    -- repo or session directory keeps its text and the icons follow it.
    local icons = iconsFor(sid)
    local name  = overrides[sid]
                  or ((icons and not icons.named) and "" or (auto or "…"))
    local suffix = (name == "") and " → " or (" → " .. name .. " ")
    local text   = prefix .. mid .. suffix
    if icons then text = text .. string.rep(" ", iconTextPad(icons)) end
    entries[#entries + 1] = {
      sid = sid, dots = dots, icons = icons, prefix = prefix, suffix = suffix,
      here = here,                           -- draws the caret + number in magenta
      text = text,                           -- plain form, used for sizing
    }
  end
  return entries
end

-- ---- GitHub status popup (⌘⌃⌥g, on demand) --------------------------------

-- The repos currently ON the panel, in display order, deduped. Desktop labels
-- (the detected repo) plus session projects, matched case-insensitively to a
-- real repo under repoRoots. ⌘⌃⌥g queries only these, so it never fans out to
-- every repo you own.
local function displayedRepos()
  local seen, order = {}, {}
  local function add(label)
    local key = tostring(label or ""):lower()
    if key == "" or seen[key] ~= nil then return end
    for _, r in ipairs(repos) do
      if tostring(r.name):lower() == key and r.path then
        seen[key] = r; order[#order + 1] = r; return
      end
    end
    seen[key] = false          -- not a repo; remember so we don't rescan for it
  end
  if M.mode ~= "terminals" then
    for _, s in ipairs(hs.screen.allScreens()) do
      for _, sid in ipairs(safeSpacesForScreen(s)) do add(labelCache[sid]) end
    end
  end
  if M.mode == "terminals" or M.mode == "both" then
    for _, s in ipairs(sessions) do add(s.project) end
  end
  return order
end

-- Quotes are escaped too: these strings also land in HTML attributes.
local function htmlEscape(s)
  return (tostring(s or ""):gsub("[&<>\"]",
    { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;" }))
end

-- A Lua string as a JavaScript string literal, for evaluateJavaScript.
local function jsQuote(s)
  return '"' .. tostring(s or ""):gsub("[\\\"]", "\\%0")
                                 :gsub("\n", "\\n"):gsub("\r", "")
                                 :gsub("\t", "\\t") .. '"'
end

-- Write a line into the popup's status area. Silently does nothing if the
-- popup has since been closed, which is the normal case for a slow pull.
local function ghSay(text, color)
  if not ghWebview then return end
  pcall(function()
    ghWebview:evaluateJavaScript(string.format(
      "var m=document.getElementById('msg'); if(m){m.textContent=%s; m.style.color=%s;} 'ok'",
      jsQuote(text), jsQuote(color or "#9aa0a6")))
  end)
end

-- Same area, but as markup — used only for the confirmation, which needs two
-- things to click. The links post straight back through the same bridge.
local function ghAsk(html)
  if not ghWebview then return end
  pcall(function()
    ghWebview:evaluateJavaScript(string.format(
      "var m=document.getElementById('msg'); if(m){m.innerHTML=%s; m.style.color='#ffc73a';} 'ok'",
      jsQuote(html)))
  end)
end

-- "3 files will change: a.md, b.lua and 1 more", kept to one readable clause.
local function describeChanges(files)
  if #files == 0 then return "no files change" end
  local shown = {}
  for i = 1, math.min(#files, 3) do shown[i] = files[i]:match("[^/]+$") or files[i] end
  local list = table.concat(shown, ", ")
  if #files > 3 then list = list .. " and " .. (#files - 3) .. " more" end
  return string.format("%d file%s will change: %s", #files, #files == 1 and "" or "s", list)
end

-- Is a claude session in the way? Returns a reason to refuse, or nil.
-- Keyed off claudeStates, the live read of terminal titles — NOT claudeStateFor,
-- which returns nil once you've acknowledged a session and would call a busy
-- repo clear.
local function pullBlockedByClaude(name)
  local mode = M.pullBlockOnClaude
  if mode == false then return nil end
  local st = claudeStates[tostring(name or ""):lower()]
  if not st then return nil end
  if st == "working" then return "a claude session is working in " .. name end
  if mode == "any" then return "a claude session is open in " .. name end
  return nil
end

-- Every document the panel currently knows to be open, lowercased for the
-- case-insensitive filesystem. Only editors in M.docApps report one, and only
-- for Desktops read since launch — see M.pullBlockOnOpenFiles.
local function openDocPaths()
  local set = {}
  for _, funcs in pairs(lastGather) do
    for _, w in ipairs(funcs) do
      if w.doc and w.doc ~= "" then set[tostring(w.doc):lower()] = true end
    end
  end
  return set
end

-- Ask the remote what a pull would change, WITHOUT changing the working tree:
-- fetch (which the pull would do anyway, and which only moves the origin/…
-- tracking ref) and then diff HEAD against the upstream. The file list is what
-- the open-editor check needs; nothing here touches a file of yours.
local PULL_PRECHECK = [[
export GIT_TERMINAL_PROMPT=0
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
git -C %s fetch --quiet 2>/dev/null || echo '__FETCHFAIL__'
git -C %s diff --name-only 'HEAD..@{u}' 2>/dev/null
]]

local pullPrecheckTask

-- Pull one repo, on demand, from a click in the popup. Async throughout: this
-- talks to the network and must never block the panel.
local function pullRepo(path, name)
  if M.allowPullFromPopup == false then return end
  if pullTask or pullPrecheckTask then ghSay("a pull is already running…", "#ffc73a"); return end

  -- Local knowledge first, before any network work.
  local blocked = pullBlockedByClaude(name)
  if blocked then
    ghSay("Aborting the pull: " .. blocked
          .. ". Wait for it to finish, or pull in a terminal.", "#ff6f6a")
    return
  end

  local args = (M.pullFFOnly ~= false) and "--ff-only" or ""
  local script = string.format(
    'export GIT_TERMINAL_PROMPT=0\nexport PATH="/usr/local/bin:/usr/bin:/bin:$PATH"\n'
    .. 'git -C %s pull %s 2>&1', shQuote(path), args)

  local function finish(okPull, out)
    if pullWatchdog then pullWatchdog:stop(); pullWatchdog = nil end
    pullTask = nil
    out = tostring(out or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if okPull then
      ghSay(name .. ": " .. (out ~= "" and out:gsub("\n", " · ") or "pulled"), "#4cd964")
      hs.alert.show(name .. " pulled")
      -- The panel's git dot is now stale, and its refresh is rate-limited;
      -- clear the stamp so the next tick re-reads instead of skipping.
      gitStatesAt = 0
      pcall(refreshGitStates)
      -- Re-query so every row in the popup tells the truth again, not just the
      -- one that was clicked. The delay is there to be READ: the rescan rebuilds
      -- the whole popup and takes the result line with it, and "Fast-forward, 3
      -- files changed" is worth a couple of seconds on screen.
      pullRescan = hs.timer.doAfter(2.5, function() pcall(M.scanGitHub) end)
    else
      -- Git's own words. A refusal here is the feature working: a dirty file in
      -- the way, or a history that can't fast-forward, is exactly what you want
      -- to be told rather than have resolved for you.
      ghSay(name .. ": " .. (out ~= "" and out:gsub("\n", " · ") or "pull failed"), "#ff6f6a")
    end
  end

  local function doPull()
    local ok, t = pcall(hs.task.new, "/bin/sh", function(code, stdout, stderr)
      finish(code == 0, (stdout or "") .. (stderr or ""))
    end, { "-c", script })
    if not (ok and t) then ghSay("could not start the pull", "#ff6f6a"); return end
    pullTask = t
    t:start()
    pullWatchdog = hs.timer.doAfter(M.pullTimeout or 120, function()
      if pullTask then pcall(function() pullTask:terminate() end) end
      finish(false, "timed out after " .. (M.pullTimeout or 120) .. "s")
    end)
  end

  if M.pullBlockOnOpenFiles == false then ghSay("pulling " .. name .. "…", "#ffc73a"); doPull(); return end

  -- Find out what would change before changing it.
  ghSay("checking what " .. name .. " would change…", "#ffc73a")
  local pre = string.format(PULL_PRECHECK, shQuote(path), shQuote(path))
  local okp, pt = pcall(hs.task.new, "/bin/sh", function(_, stdout, _)
    pullPrecheckTask = nil
    local text = tostring(stdout or "")
    if text:find("__FETCHFAIL__", 1, true) then
      ghSay(name .. ": couldn't reach the remote — nothing was changed.", "#ff6f6a")
      return
    end
    local open, hits = openDocPaths(), {}
    for rel in text:gmatch("[^\n]+") do
      if rel ~= "" and rel ~= "__FETCHFAIL__" then
        local abs = (path:gsub("/$", "")) .. "/" .. rel
        if open[abs:lower()] then hits[#hits + 1] = rel:match("[^/]+$") or rel end
      end
    end
    if #hits > 0 then
      local list = table.concat(hits, ", ", 1, math.min(#hits, 3))
      if #hits > 3 then list = list .. " and " .. (#hits - 3) .. " more" end
      ghSay(("Aborting the pull: %s would change %s, which you have open. "):format(name, list)
            .. "Close it, or handle this in a terminal session.", "#ff6f6a")
      return
    end
    -- Everything checked out. Ask, naming what is about to change.
    if M.pullConfirm == false then
      ghSay("pulling " .. name .. "…", "#ffc73a")
      doPull()
      return
    end
    local changed = {}
    for rel in text:gmatch("[^\n]+") do
      if rel ~= "" and rel ~= "__FETCHFAIL__" then changed[#changed + 1] = rel end
    end
    pendingPull = { name = name, run = doPull }
    -- Second line names the ONE way this can cost you work, in the order a
    -- person needs it: when it applies, what to do, and what happens if you
    -- don't. An earlier draft ("Files change on disk — reopen anything from
    -- this repo you have open afterwards") was reported as confusing and
    -- deserved it: vague about what changes, and "afterwards" attached itself
    -- to the wrong verb. Never leave the reason out of a warning — without it
    -- "reopen" reads as superstition.
    ghAsk(string.format(
      "<b>Pull %s?</b> %s.<br>If any of these are open in an editor, close them "
      .. "first — saving from an old copy would undo the pull.<br>"
      .. "<span class='act' onclick=\"window.webkit.messageHandlers.dashboard"
      .. ".postMessage({action:'confirmPull'})\">Pull</span> &nbsp;·&nbsp; "
      .. "<span class='act' onclick=\"window.webkit.messageHandlers.dashboard"
      .. ".postMessage({action:'cancelPull'})\">Cancel</span>",
      htmlEscape(name), htmlEscape(describeChanges(changed))))
  end, { "-c", pre })
  if not (okp and pt) then ghSay("could not check " .. name, "#ff6f6a"); return end
  pullPrecheckTask = pt
  pt:start()
  -- The check reaches the network too, so it needs the same watchdog the pull
  -- has. Without one a wedged fetch would leave pullPrecheckTask set and every
  -- later click would report "a pull is already running".
  pullWatchdog = hs.timer.doAfter(M.pullTimeout or 120, function()
    if pullPrecheckTask then
      pcall(function() pullPrecheckTask:terminate() end)
      pullPrecheckTask = nil
      ghSay(name .. ": checking the remote timed out — nothing was changed.", "#ff6f6a")
    end
  end)
end

-- The popup's JS calls into here. Built once and reused: a controller outlives
-- the webview, which is deleted and rebuilt on every ⌘⌃⌥g.
local function ghBridge()
  if ghUserContent then return ghUserContent end
  local ok, uc = pcall(hs.webview.usercontent.new, "dashboard")
  if not (ok and uc) then return nil end
  uc:setCallback(function(msg)
    local b = (type(msg) == "table") and msg.body or nil
    if type(b) ~= "table" then return end
    if b.action == "pull" and type(b.path) == "string" then
      pullRepo(b.path, tostring(b.name or b.path))
    elseif b.action == "confirmPull" then
      local p = pendingPull
      pendingPull = nil
      if p then ghSay("pulling " .. p.name .. "…", "#ffc73a"); p.run() end
    elseif b.action == "cancelPull" then
      local p = pendingPull
      pendingPull = nil
      ghSay(((p and p.name .. ": ") or "") .. "cancelled — nothing was changed.", "#9aa0a6")
    end
  end)
  ghUserContent = uc
  return uc
end

-- Render the popup. `rows` is a list of { name, branch, dirty, ahead, commit, gh }.
local function showGitHubPopup(rows)
  local ghText = {
    uptodate    = { t = "up to date",    c = "#4cd964" },
    localahead  = { t = "unpushed only",  c = "#ffc73a" },
    behind      = { t = "GitHub ahead",   c = "#ff6f6a" },
    unreachable = { t = "unreachable",    c = "#9aa0a6" },
  }
  local trs = {}
  for _, r in ipairs(rows) do
    local g = ghText[r.gh] or { t = r.gh or "?", c = "#9aa0a6" }
    local bits = {}
    if (r.dirty or 0) > 0 then bits[#bits + 1] = r.dirty .. " changed" end
    if (r.ahead or 0) > 0 then bits[#bits + 1] = r.ahead .. " unpushed" end
    local localTxt   = (#bits > 0) and table.concat(bits, ", ") or "clean"
    local localColor = (#bits > 0) and "#ff6f6a" or "#4cd964"
    -- Only "GitHub ahead" is actionable, and only when we know where the repo
    -- lives. Everything else is a statement, not a button.
    local ghCell = htmlEscape(g.t)
    if r.gh == "behind" and r.path and M.allowPullFromPopup ~= false then
      ghCell = string.format(
        "<span class='pull' data-path='%s' data-name='%s' title='Pull this repo'>%s ↓</span>",
        htmlEscape(r.path), htmlEscape(r.name), htmlEscape(g.t))
    end
    trs[#trs + 1] = string.format(
      "<tr><td class='n'>%s</td><td>%s</td><td style='color:%s'>%s</td>"
      .. "<td style='color:%s'>%s</td><td class='d'>%s</td></tr>",
      htmlEscape(r.name), htmlEscape(r.branch ~= "" and r.branch or "—"),
      localColor, htmlEscape(localTxt), g.c, ghCell,
      htmlEscape((r.commit ~= "" and r.commit) or "—"))
  end
  if #trs == 0 then
    trs[1] = "<tr><td colspan='5' class='d'>no repos on the panel to check</td></tr>"
  end
  local when = os.date("%Y-%m-%d %H:%M:%S")
  local html = string.format([[<!DOCTYPE html><html><head><meta charset="utf-8"><style>
    body{font:13px -apple-system,Menlo,monospace;background:#1e1e1e;color:#eee;margin:0;padding:14px}
    h1{font-size:14px;margin:0 0 2px}
    .sub{color:#9aa0a6;font-size:11px;margin:0 0 12px;line-height:1.4}
    table{border-collapse:collapse;width:100%%}
    th,td{text-align:left;padding:5px 14px 5px 0;border-bottom:1px solid #333;white-space:nowrap}
    th{color:#9aa0a6;font-weight:600;font-size:11px;text-transform:uppercase;letter-spacing:.04em}
    td.n{font-weight:600}
    td.d{color:#9aa0a6}
    .pull{cursor:pointer;text-decoration:underline dotted;text-underline-offset:3px}
    .pull:hover{text-decoration:underline solid}
    .act{cursor:pointer;color:#6cf;text-decoration:underline;font-weight:600}
    #msg{margin:12px 0 0;font-size:11px;color:#9aa0a6;min-height:14px;white-space:pre-wrap}
  </style></head><body>
    <h1>GitHub status</h1>
    <p class="sub">snapshot at %s · reading only: <code>git ls-remote</code>, your local refs untouched<br>
      local red = uncommitted or unpushed · &quot;GitHub ahead&quot; = the remote has commits you don't<br>
      %s</p>
    <table><tr><th>repo</th><th>branch</th><th>local</th><th>github</th><th>last commit</th></tr>%s</table>
    <p id="msg"></p>
    <script>
      document.querySelectorAll('.pull').forEach(function (el) {
        el.addEventListener('click', function () {
          var m = document.getElementById('msg');
          if (m) { m.textContent = 'pulling ' + el.dataset.name + '…'; m.style.color = '#ffc73a'; }
          window.webkit.messageHandlers.dashboard.postMessage(
            { action: 'pull', path: el.dataset.path, name: el.dataset.name });
        });
      });
    </script>
  </body></html>]], when,
    (M.allowPullFromPopup ~= false)
      and ("click <b>GitHub ahead</b> to pull that repo ("
           .. ((M.pullFFOnly ~= false) and "fast-forward only" or "merge allowed")
           .. "); it stops if a claude session is working there or a file it would "
           .. "change is open in an editor, then asks before changing anything")
      or "",
    table.concat(trs, ""))

  local h = math.min(580, 185 + math.max(1, #rows) * 30)   -- + room for the status line
  if ghWebview then pcall(function() ghWebview:delete() end); ghWebview = nil end
  local okv, w = pcall(function()
    -- The usercontent controller is what lets a click in the page reach Lua.
    local v = hs.webview.new({ x = 140, y = 140, w = 660, h = h }, {}, ghBridge())
    -- titled(1) | closable(2) | miniaturizable(4) | resizable(8)
    v:windowStyle(1 + 2 + 4 + 8)
    v:windowTitle("GitHub status")
    v:allowTextEntry(false)
    pcall(function() v:closeOnEscape(true) end)
    pcall(function() v:level(hs.canvas.windowLevels.floating) end)
    return v
  end)
  if not (okv and w) then hs.alert.show("Could not open GitHub popup"); return end
  ghWebview = w
  ghWebview:html(html)
  ghWebview:show()
  pcall(function() ghWebview:bringToFront(true) end)
end

-- One sh pass over the shown repos: local state plus a light-touch ls-remote of
-- the current branch. Compare the remote head SHA to HEAD to classify GitHub:
-- equal => up to date; remote is an ancestor of HEAD => you're merely ahead
-- (unpushed only); otherwise the remote has commits you don't (GitHub ahead);
-- empty/failed ls-remote => unreachable. Only one %s (the paths); rest are %%.
local GIT_REMOTE_SNIPPET = [[
export GIT_TERMINAL_PROMPT=0
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
for d in %s; do
  b=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
  dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  ahead=$(git -C "$d" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  lc=$(git -C "$d" log -1 --format='%%cd' --date=format:'%%Y-%%m-%%d %%H:%%M' 2>/dev/null)
  head=$(git -C "$d" rev-parse HEAD 2>/dev/null)
  rem=$(git -C "$d" ls-remote origin "refs/heads/$b" 2>/dev/null | awk '{print $1}')
  if [ -z "$rem" ]; then gh=unreachable
  elif [ "$rem" = "$head" ]; then gh=uptodate
  elif git -C "$d" merge-base --is-ancestor "$rem" HEAD 2>/dev/null; then gh=localahead
  else gh=behind
  fi
  printf '%%s\t%%s\t%%s\t%%s\t%%s\t%%s\n' "$d" "$b" "$dirty" "$ahead" "$lc" "$gh"
done
]]

function M.scanGitHub()
  local shown = displayedRepos()
  if #shown == 0 then hs.alert.show("No repos on the panel to check"); return end
  if ghTask then hs.alert.show("GitHub check already running…"); return end
  hs.alert.show(("Querying GitHub for %d repo%s…"):format(#shown, #shown == 1 and "" or "s"))
  local parts, nameOf = {}, {}
  for _, r in ipairs(shown) do parts[#parts + 1] = shQuote(r.path); nameOf[r.path] = r.name end
  local script = string.format(GIT_REMOTE_SNIPPET, table.concat(parts, " "))
  local rows, done = {}, false
  local function finish()
    if done then return end
    done = true
    if ghWatchdog then ghWatchdog:stop(); ghWatchdog = nil end
    showGitHubPopup(rows)
  end
  local ok, t = pcall(hs.task.new, "/bin/sh", function(_, stdout, _)
    ghTask = nil
    for line in tostring(stdout or ""):gmatch("[^\n]+") do
      local p, b, dirty, ahead, lc, gh = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(%S+)$")
      if p then
        rows[#rows + 1] = { name = nameOf[p] or p, path = p, branch = b,
                            dirty = tonumber(dirty) or 0,
                            ahead = tonumber(ahead) or 0, commit = lc, gh = gh }
      end
    end
    finish()
  end, { "-c", script })
  if ok and t then
    ghTask = t
    t:start()
    -- Watchdog: a wedged network read (despite GIT_TERMINAL_PROMPT=0) must never
    -- leave the query pinned. Kill it and show whatever came back.
    ghWatchdog = hs.timer.doAfter(M.githubTimeout or 20, function()
      if ghTask then pcall(function() ghTask:terminate() end); ghTask = nil
        hs.alert.show("GitHub query timed out")
      end
      finish()
    end)
  else
    hs.alert.show("Could not start GitHub query")
  end
end

-- ---- dragging the panel ---------------------------------------------------
--
-- A press on the panel starts a session; an hs.eventtap follows the mouse until
-- release. The tap is what makes this reliable — canvas mouse events only fire
-- while the pointer is over the canvas, so a quick drag would otherwise lose
-- the pointer and strand the session. It never consumes events (always returns
-- false), so it cannot swallow input belonging to other apps.

-- Bring a Terminal window to the front. macOS follows it to whatever Desktop it
-- lives on, so this doubles as "go to that session". Run through hs.task so a
-- busy Terminal cannot stall the panel.
-- ---- the hover tip that names an app icon ---------------------------------

local function canvasFor(uuid)
  for _, c in ipairs(canvases) do if c.uuid == uuid then return c.cv end end
  return nil
end

local function screenFrameAt(x, y)
  for _, s in ipairs(hs.screen.allScreens()) do
    local f = s:frame()
    if x >= f.x and x < f.x + f.w and y >= f.y and y < f.y + f.h then return f end
  end
  local ok, f = pcall(function() return hs.screen.mainScreen():frame() end)
  return (ok and f) or { x = 0, y = 0, w = 1440, h = 900 }
end

local function hideTip()
  if tipTimer then tipTimer:stop(); tipTimer = nil end
  if tipWatch then tipWatch:stop(); tipWatch = nil end
  if tipCanvas then pcall(function() tipCanvas:delete() end); tipCanvas = nil end
end

local function clearHover() hideTip(); hoverId, hoverUUID = nil, nil end

-- Draw (or re-place) the tip for whatever icon is currently hovered.
local function showTip()
  hideTip()
  local m  = hoverId and iconMeta[hoverId]
  local cv = hoverUUID and canvasFor(hoverUUID)
  if not (m and cv) then return end
  local okTL, tl = pcall(function() return cv:topLeft() end)
  if not (okTL and tl) then return end

  local size = math.max(9, (M.fontSize or 13) - 1)
  local font = { name = "Menlo", size = size }
  local rows = { { t = tostring(m.app or "?"), c = { white = 1, alpha = 1 } } }
  -- The title names the window a click would raise, so you can tell two windows
  -- of the same app apart before committing to the switch.
  local title = tostring(m.title or "")
  local lim   = M.iconTipMaxChars or 44
  if uwidth(title) > lim then title = title:sub(1, lim) .. "…" end
  if title ~= "" and title ~= m.app then
    rows[#rows + 1] = { t = title, c = { white = 0.66, alpha = 1 } }
  end

  local tpad, rowH, wMax = 7, size + 4, 0
  for _, r in ipairs(rows) do
    local okw, sz = pcall(hs.drawing.getTextDrawingSize, hs.styledtext.new(r.t, { font = font }))
    wMax = math.max(wMax, (okw and type(sz) == "table" and sz.w) or uwidth(r.t) * charWidth())
  end
  local tw, th = math.ceil(wMax) + tpad * 2 + 2, #rows * rowH + tpad * 2

  -- Below the icon, so the pointer never ends up on the tip itself — that would
  -- fire mouseExit on the icon and flicker. Pulled left / flipped above only
  -- when it would otherwise run off the display.
  local x, y = tl.x + m.x - tpad, tl.y + m.y + m.h + 5
  local f = screenFrameAt(tl.x + m.x, tl.y + m.y)
  if x + tw > f.x + f.w then x = f.x + f.w - tw - 2 end
  if x < f.x then x = f.x + 2 end
  if y + th > f.y + f.h then y = tl.y + m.y - th - 5 end

  local tc = hs.canvas.new({ x = x, y = y, w = tw, h = th })
  tc:behavior({ "canJoinAllSpaces", "stationary" })
  tc:level(hs.canvas.windowLevels.popUpMenu or hs.canvas.windowLevels.floating)
  tc:clickActivating(false)
  tc:appendElements({
    type = "rectangle", action = "strokeAndFill",
    fillColor = { red = 0.09, green = 0.09, blue = 0.11, alpha = 0.96 },
    strokeColor = { white = 1, alpha = 0.22 }, strokeWidth = 1,
    roundedRectRadii = { xRadius = 6, yRadius = 6 },
  })
  local ty = tpad
  for _, r in ipairs(rows) do
    tc:appendElements({
      type = "text", text = r.t, textFont = "Menlo", textSize = size, textColor = r.c,
      frame = { x = tpad + 1, y = ty, w = tw - tpad * 2, h = rowH },
    })
    ty = ty + rowH
  end
  tc:show()
  tipCanvas = tc

  -- A canvas deleted under the pointer can swallow the mouseExit, which would
  -- pin the tip on screen for good. Cheap poll, running only while one shows.
  tipWatch = hs.timer.doEvery(0.4, function()
    local mm = hoverId and iconMeta[hoverId]
    local c  = hoverUUID and canvasFor(hoverUUID)
    local okp, p  = pcall(hs.mouse.absolutePosition)
    local okt, t2 = false, nil
    if c then okt, t2 = pcall(function() return c:topLeft() end) end
    if not (mm and okp and okt and t2) then clearHover(); return end
    if p.x < t2.x + mm.x or p.x > t2.x + mm.x + mm.w
       or p.y < t2.y + mm.y or p.y > t2.y + mm.y + mm.h then clearHover() end
  end)
end

local function enterIcon(cv, id)
  if M.showIconTips == false or not iconMeta[id] then return end
  if hoverId == id and tipCanvas then return end
  clearHover()
  hoverId = id
  for _, c in ipairs(canvases) do if c.cv == cv then hoverUUID = c.uuid end end
  tipTimer = hs.timer.doAfter(M.iconTipDelay or 0.18, showTip)
end

local function exitIcon(id) if hoverId == id then clearHover() end end

-- Called at the end of draw(). The canvases have just been replaced, so a
-- visible tip is anchored to a deleted element: re-place it if the same icon is
-- still there, drop it if it isn't. Without this the tip disappeared every time
-- a dot changed (a 3 s timer) while the pointer sat still, and no fresh
-- mouseEnter would ever arrive to bring it back.
local function refreshTip()
  if not hoverId then return end
  if iconMeta[hoverId] and canvasFor(hoverUUID) then
    if tipCanvas then showTip() end       -- a still-pending tipTimer needs nothing
  else
    clearHover()
  end
end

local function focusTerminalWindow(wid)
  if not wid then return end
  sessionDone[wid] = nil                 -- looking at it is acknowledging it
  local script = string.format(
    'tell application "Terminal"\nactivate\nset index of window id %d to 1\nend tell', wid)
  local ok, t = pcall(hs.task.new, "/usr/bin/osascript", nil, { "-e", script })
  if ok and t then t:start() end
end

-- A click that never became a drag acts on whatever it landed on.
local function activateElement(elementId)
  if type(elementId) ~= "string" then return end
  if elementId == "resize" then return end   -- a click on the grip resizes nothing
  if elementId == "rescan" then pcall(M.scanAll); return end
  -- A legend word acting as its own button (M.legendClicks). This is what makes
  -- the panel usable over VNC, where ⌘⌃⌥ never reaches this machine. Each one is
  -- the hotkey's own handler, so there is no second code path to keep in step.
  -- No "restore" branch on purpose: M.restoreLayout moves and opens windows
  -- across every Desktop and has no inverse, so it stays hotkey-only.
  if elementId == "github"  then pcall(M.scanGitHub);    return end
  if elementId == "name"    then pcall(M.nameCurrent);   return end
  if elementId == "mode"    then pcall(M.cycleMode);     return end
  -- An icon: go to the Desktop AND raise that app's window. Clicking the line
  -- itself deliberately does not — arriving on a Desktop should normally leave
  -- it as you left it; picking an icon is the way to say which window you want.
  local isid, iwid = elementId:match("^icon:(%-?%d+):([pr]?%d+)$")
  if isid then
    clearHover()
    pcall(hs.spaces.gotoSpace, tonumber(isid))
    -- "r" is a restored icon: we know which app it is but not which window, so
    -- going to the Desktop is the whole of the action.
    if iwid:sub(1, 1) == "r" then return end
    if M.iconClickFocus ~= false and iwid:sub(1, 1) == "p" then
      -- CoreGraphics-only app: no window object exists to raise, so bring the
      -- application forward and let it decide which of its windows that means.
      focusTimer = hs.timer.doAfter(M.iconFocusDelay or 0.45, function()
        local a = hs.application.applicationForPID(tonumber(iwid:sub(2)))
        if a then pcall(function() a:activate() end) end
      end)
      return
    end
    if M.iconClickFocus ~= false then
      -- Held in a module local: an hs.timer with nothing referencing it can be
      -- collected before it fires (see CLAUDE.md — it silently killed the ⌘⌃⌥S
      -- walk once). The wait lets the Space switch finish; raising into a
      -- half-finished switch does nothing.
      focusTimer = hs.timer.doAfter(M.iconFocusDelay or 0.45, function()
        -- Re-resolve by id: the window object read minutes ago may be gone, and
        -- only now is its Space active enough to look it up. hs.window.get is
        -- the ~40 ms call banned from the read path, which one click can afford.
        local okw, w = pcall(hs.window.get, tonumber(iwid))
        if okw and w then pcall(function() w:focus() end) end
      end)
    end
    return
  end
  local sid = tonumber(elementId:match("^go:(%-?%d+)$") or "")
  if sid then pcall(hs.spaces.gotoSpace, sid); return end
  local wid = tonumber(elementId:match("^term:(%d+)$") or "")
  if wid then focusTerminalWindow(wid); pcall(draw) end
end

local function endDrag(commit)
  if dragTap      then dragTap:stop();      dragTap = nil end
  if dragWatchdog then dragWatchdog:stop(); dragWatchdog = nil end
  local d = drag
  drag = nil
  if not d then return end
  if d.moved then
    pcall(M.saveLayout)                  -- remember where it was put
  elseif commit then
    activateElement(d.elementId)         -- never moved: it was a click
  end
end

-- Move the panel so it follows an absolute mouse position. Split out from the
-- event tap so it can be exercised with injected coordinates instead of by
-- synthesising real mouse events, which would seize the user's pointer.
local function dragMoveTo(px, py)
  local d = drag
  if not d then return false end
  local dx, dy = px - d.mouseX, py - d.mouseY
  -- Below the threshold this is still a click on a Desktop line, not a drag.
  if not d.moved and (math.abs(dx) + math.abs(dy)) < (M.dragThreshold or 3) then
    return false
  end
  d.moved = true

  if d.mode == "resize" then
    -- The panel has no free aspect ratio: its shape follows its content, and
    -- the one thing that scales it is the font size. So the drag is projected
    -- onto the diagonal — both axes contribute, and dragging out along either
    -- one grows the panel — and turned into a size. Integer font sizes mean
    -- this redraws about twenty times across a full drag, not per pixel.
    local ratio = ((d.startW + dx) + (d.startH + dy)) / (d.startW + d.startH)
    M.setFontSize((d.startFont or 13) * ratio)
    -- draw() has just replaced every canvas, so the one this drag was started
    -- on is gone; re-point at its successor or the next move would act on a
    -- deleted object.
    if d.uuid then
      for _, c in ipairs(canvases) do if c.uuid == d.uuid then d.cv = c.cv end end
    end
    return true
  end

  local nx, ny = d.originX + dx, d.originY + dy
  pcall(function() d.cv:topLeft({ x = nx, y = ny }) end)
  if d.uuid then panelPos[d.uuid] = { x = nx, y = ny } end
  return true
end

local function startDrag(cv, uuid, elementId)
  -- The grip resizes even when the panel is pinned (M.draggable = false):
  -- those are different things to want.
  local resizing = (elementId == "resize") and (M.showResizeGrip ~= false)
  if not cv or not (M.draggable or resizing) then return end
  endDrag(false)                         -- never stack sessions
  local okTL, tl = pcall(function() return cv:topLeft() end)
  if not (okTL and tl) then return end
  local oks, sz = pcall(function() return cv:size() end)
  local m = hs.mouse.absolutePosition()
  drag = { cv = cv, uuid = uuid, elementId = elementId, moved = false,
           mode = resizing and "resize" or "move",
           startFont = M.fontSize,
           startW = (oks and sz and sz.w) or 300, startH = (oks and sz and sz.h) or 200,
           originX = tl.x, originY = tl.y, mouseX = m.x, mouseY = m.y }

  local et = hs.eventtap.event.types
  dragTap = hs.eventtap.new({ et.leftMouseDragged, et.mouseMoved, et.leftMouseUp },
    function(e)
      local d = drag
      if not d then endDrag(false); return false end
      if e:getType() == et.leftMouseUp then endDrag(true); return false end
      local p = hs.mouse.absolutePosition()
      dragMoveTo(p.x, p.y)
      return false                       -- pass through; never consume
    end)
  dragTap:start()
  -- A missed mouseUp must not leave a live tap behind.
  dragWatchdog = hs.timer.doAfter(30, function() endDrag(false) end)
end

local function onMouse(cv, message, elementId)
  if message == "mouseEnter" then
    enterIcon(cv, elementId); return
  elseif message == "mouseExit" then
    exitIcon(elementId); return
  end
  if message == "mouseDown" then
    clearHover()                         -- the tip must not survive a drag
    if not M.draggable and elementId ~= "resize" then return end
    local uuid
    for _, c in ipairs(canvases) do
      if c.cv == cv then uuid = c.uuid break end
    end
    startDrag(cv, uuid, elementId)
  elseif message == "mouseUp" then
    -- When dragging is on, the event tap decides click-vs-drag; it also catches
    -- a release that lands after the pointer has left the panel.
    if M.draggable or drag then return end
    activateElement(elementId)
  end
end

-- Cycle desktops -> terminals -> both. Kept as a hotkey because which view is
-- useful depends on how you have your sessions arranged today.
function M.cycleMode()
  local order = { desktops = "terminals", terminals = "both", both = "desktops" }
  M.mode = order[M.mode] or "desktops"
  pcall(M.saveLayout)
  pcall(scanActive)
  draw()
  hs.alert.show("Dashboard: " .. M.mode)
end

-- Resize the whole panel. Every measurement — line height, character width,
-- icon edge, legend — derives from M.fontSize, so this is the only knob needed.
-- Clamped, saved, and a no-op at the ends so clicking − at the minimum doesn't
-- churn a redraw and a file write.
function M.setFontSize(n)
  n = math.floor((tonumber(n) or 13) + 0.5)
  n = math.max(M.minFontSize or 9, math.min(M.maxFontSize or 28, n))
  if n == M.fontSize then return end
  M.fontSize = n
  clearHover()                   -- any tip is sized and placed for the old scale
  draw()
  -- Mid-drag this is called once per size step; endDrag() writes the file when
  -- the grip is released, so don't write it twenty times on the way there.
  if not (drag and drag.mode == "resize") then pcall(M.saveLayout) end
end

-- Forget any dragged position and go back to M.corner.
function M.resetPanelPosition()
  panelPos = {}
  pcall(M.saveLayout)
  draw()
  hs.alert.show("Dashboard position reset")
end

draw = function()
  for _, c in ipairs(canvases) do pcall(function() c.cv:delete() end) end
  canvases = {}
  iconMeta = {}                  -- rebuilt below; ids are per-element and per-draw
  if not M.visible then clearHover(); return end   -- ⌘⌃⌥D must take the tip with it

  local screens = hs.screen.allScreens()
  local multi   = (#screens > 1)
  local hasStatus = (M.status ~= nil and M.status ~= "")
  local blocks, maxChars, totalRows = {}, 8, 0
  local function addBlock(header, entries)
    if header then maxChars = math.max(maxChars, uwidth(header)) end
    for _, e in ipairs(entries) do maxChars = math.max(maxChars, uwidth(e.text)) end
    totalRows = totalRows + #entries + (header and 1 or 0)
    blocks[#blocks + 1] = { header = header, entries = entries }
  end

  if M.mode ~= "terminals" then
    for _, s in ipairs(screens) do
      addBlock(multi and ((s:name() or "Screen") .. ":") or nil, screenEntries(s))
    end
  end
  if M.mode == "terminals" or M.mode == "both" then
    -- In "both" the section needs a header to separate it from the Desktops;
    -- alone it is the whole panel and a header would just be noise.
    addBlock(M.mode == "both" and M.sessionHeader or nil, sessionEntries())
  end
  if hasStatus then maxChars = math.max(maxChars, uwidth(M.status)) end

  -- Desktops still showing restored state. Counted from the entries already
  -- built, so this costs no extra hs.spaces calls. Hidden while a scan is
  -- running: the status line is saying the same thing more precisely.
  local staleText
  if M.showStaleHint ~= false and not hasStatus then
    local n = 0
    for _, blk in ipairs(blocks) do
      for _, e in ipairs(blk.entries) do
        if e.sid and not liveRead[e.sid] then n = n + 1 end
      end
    end
    if n > 0 then
      -- Both ways of doing it, named as what they are: the line is a click
      -- target AND ⌘⌃⌥S does the same thing. An earlier draft put the hotkey in
      -- a trailing parenthesis, which read as a footnote rather than an action.
      staleText = string.format(
        "%d Desktop%s not read yet · click here or press ⌘⌃⌥s to read them",
        n, n == 1 and "" or "s")
      maxChars = math.max(maxChars, uwidth(staleText))
    end
  end
  -- A session on another Mac is blocked on you. Above the stale line and never
  -- suppressed by it: this is the only thing on the panel that reports something
  -- happening somewhere you cannot see, so it must not lose a race to a hint
  -- about local freshness.
  local alertText
  if #remoteAlerts > 0 then
    local a = remoteAlerts[1]
    if #remoteAlerts == 1 then
      alertText = string.format("%s · %s is waiting on you", a.host, a.repo)
    else
      alertText = string.format("%s · %s +%d more waiting on you",
        a.host, a.repo, #remoteAlerts - 1)
    end
    maxChars = math.max(maxChars, uwidth(alertText))
  end

  local legendLines = (M.showLegend and M.legendLines) or {}
  for _, ln in ipairs(legendLines) do maxChars = math.max(maxChars, uwidth(ln)) end

  local lineH   = M.fontSize + 6
  local pad     = 12
  local charW   = charWidth()
  local statusH = hasStatus and (lineH + 9) or 0
  local staleH  = staleText and (lineH + 9) or 0
  local alertH  = alertText and (lineH + 9) or 0
  local legendH = (#legendLines > 0) and (10 + #legendLines * (M.fontSize + 3)) or 0
  -- The grip sits in the bottom-right corner, past the end of the legend, so
  -- unlike the buttons it replaced it needs no width reserved for it.
  local zoomW   = 0
  local wScale  = (M.fontSize or 13) / (M.baseFontSize or 13)
  local minW    = (M.minWidth or 220) * wScale
  local maxW    = (M.maxWidth or 760) * wScale
  local bodyW   = math.max(minW - pad * 2, math.ceil(maxChars * charW) + 6 + zoomW)
  local panelW  = math.min(maxW, bodyW + pad * 2)
  local panelH  = pad * 2 + totalRows * lineH + math.max(0, #blocks - 1) * M.sectionGap
                  + statusH + staleH + alertH + legendH

  -- Which displays get a panel. The content above still describes every screen,
  -- so hiding one display's panel does not remove its Desktops from the list.
  local drawScreens = {}
  for _, s in ipairs(screens) do
    local uuid = s:getUUID()
    if not (uuid and hiddenScreens[uuid]) then drawScreens[#drawScreens + 1] = s end
  end

  for _, s in ipairs(drawScreens) do
    local f = s:frame()
    local uuid = s:getUUID()
    local x, y
    if M.corner == "topleft" then x, y = f.x + M.margin, f.y + M.margin
    elseif M.corner == "topright" then x, y = f.x + f.w - panelW - M.margin, f.y + M.margin
    elseif M.corner == "bottomleft" then x, y = f.x + M.margin, f.y + f.h - panelH - M.margin
    else x, y = f.x + f.w - panelW - M.margin, f.y + f.h - panelH - M.margin end

    -- A dragged position wins over M.corner, clamped so a grabbable strip always
    -- stays on screen — otherwise the panel could be dragged out of reach.
    local pos = uuid and panelPos[uuid]
    if pos then
      x = math.max(f.x - panelW + 60, math.min(pos.x, f.x + f.w - 60))
      y = math.max(f.y,               math.min(pos.y, f.y + f.h - 30))
    end

    local cv = hs.canvas.new({ x = x, y = y, w = panelW, h = panelH })
    cv:behavior({ "canJoinAllSpaces", "stationary" })
    cv:level(hs.canvas.windowLevels.floating)
    cv:clickActivating(false)
    cv:mouseCallback(onMouse)

    -- The background catches presses on any empty part of the panel, so it can
    -- be grabbed by the header, the legend, or the gaps — not only the lines.
    cv:appendElements({
      type = "rectangle", action = "fill",
      fillColor = { red = 0, green = 0, blue = 0, alpha = 0.74 },
      roundedRectRadii = { xRadius = 10, yRadius = 10 },
      trackMouseDown = true, id = "bg",
    })

    local cy = pad
    for bi, blk in ipairs(blocks) do
      if blk.header then
        cv:appendElements({
          type = "text", text = blk.header,
          textFont = "Menlo-Bold", textSize = M.fontSize,
          textColor = { red = 0.55, green = 0.8, blue = 1.0, alpha = 1 },
          frame = { x = pad, y = cy, w = panelW - pad * 2, h = lineH },
        })
        cy = cy + lineH
      end
      for _, e in ipairs(blk.entries) do
        -- Each entry carries an ordered list of dot specs (claude dot, then git
        -- dot); a dot with no colour is a blank spacer. A half-size space is set
        -- BETWEEN the dots so the two signals don't read as one blob. Every line
        -- with dots is rendered through styledtext — even all-blank ones — so the
        -- gap is identical on every line and the → arrows stay column-aligned.
        -- It stays a single text element, so the click target is unchanged.
        local body, styledBody = e.text, nil
        if e.dots and #e.dots > 0 then
          local font  = { name = "Menlo", size = M.fontSize }
          local plain = { font = font, color = { white = 1, alpha = 1 } }
          local gap   = { font = { name = "Menlo", size = math.max(1, math.floor(M.fontSize * 0.5)) } }
          -- Only the marker and "Desktop N" go magenta; the label keeps its own
          -- color so a repo name reads the same wherever you are standing.
          local head = (e.here and M.highlightActive ~= false)
            and { font = font, color = M.activeColor or { red = 1, green = 0.45, blue = 0.9, alpha = 1 } }
            or plain
          local ok, styled = pcall(function()
            local st = hs.styledtext.new(e.prefix, head)
            for i, d in ipairs(e.dots) do
              if i > 1 then st = st .. hs.styledtext.new(" ", gap) end
              st = st .. hs.styledtext.new(d.ch, { font = font, color = d.color or { white = 1, alpha = 1 } })
            end
            return st .. hs.styledtext.new(e.suffix, plain)
          end)
          if ok and styled then body, styledBody = styled, styled end
        end
        -- Every element of a line carries the SAME id, so clicking an app icon
        -- switches Desktops exactly like clicking its text, and a drag begun on
        -- an icon moves the panel.
        local elemId = e.sid and ("go:" .. tostring(e.sid))
                       or (e.wid and ("term:" .. tostring(e.wid)) or "line")
        cv:appendElements({
          type = "text", text = body,
          textFont = "Menlo", textSize = M.fontSize,
          -- Continuation lines (a session's task summary) are dimmed so the
          -- pair reads as one item.
          textColor = e.dim and { white = 0.62, alpha = 1 } or { white = 1, alpha = 1 },
          frame = { x = pad, y = cy, w = panelW - pad * 2, h = lineH },
          trackMouseUp = true, trackMouseDown = true,
          id = elemId,
        })
        -- Icons follow the "→", so they start where the text ends. Measure the
        -- styled line itself rather than counting characters: it mixes two font
        -- sizes (the half-space between the dots), so a character count would
        -- put the row a few px off and it would drift with the dot states.
        if e.icons then
          local iconSize, iconGap = iconMetrics()
          local w
          if styledBody then
            local okw, sz = pcall(hs.drawing.getTextDrawingSize, styledBody)
            w = (okw and type(sz) == "table" and sz.w) or nil
          end
          local x  = pad + (w or (uwidth(e.prefix .. e.suffix) + 3) * charW) + iconGap
          local iy = cy + math.max(0, math.floor((lineH - iconSize) / 2))
          for ii, it in ipairs(e.icons.items) do
            cv:appendElements({
              type = "image", image = it.img, imageScaling = "scaleProportionally",
              frame = { x = x, y = iy, w = iconSize, h = iconSize },
            })
            -- All mouse handling for an icon rides on a FULLY TRANSPARENT
            -- rectangle laid over it. Measured 2026-07-30: an hs.canvas image
            -- element reports mouseDown/mouseUp but never mouseEnter/mouseExit,
            -- while a rectangle reports all four — and an alpha-0 one still
            -- hit-tests. So the rectangle owns both the hover and the click.
            -- "icon:<space>:<windowid>" normally; "icon:<space>:p<pid>" for an
            -- app only CoreGraphics could see, where there is no window object
            -- to raise and the app itself is the best a click can do; and
            -- "icon:<space>:r<n>" for one restored from the state file, which
            -- has no window behind it at all — it still gets a distinct id so
            -- it can name itself on hover, and clicking it just goes there.
            local iid = (it.wid and ("icon:" .. tostring(e.sid) .. ":" .. tostring(it.wid)))
                        or (it.pid and ("icon:" .. tostring(e.sid) .. ":p" .. tostring(it.pid)))
                        or ("icon:" .. tostring(e.sid) .. ":r" .. ii)
            cv:appendElements({
              type = "rectangle", action = "fill", fillColor = { white = 0, alpha = 0 },
              frame = { x = x, y = iy, w = iconSize, h = iconSize },
              trackMouseEnterExit = (M.showIconTips ~= false),
              trackMouseUp = true, trackMouseDown = true, id = iid,
            })
            iconMeta[iid] = { app = it.app, title = it.title,
                              x = x, y = iy, w = iconSize, h = iconSize }
            x = x + iconSize + iconGap
          end
          if e.icons.extra > 0 then
            cv:appendElements({
              type = "text", text = "+" .. e.icons.extra,
              textFont = "Menlo", textSize = M.fontSize - 2,
              textColor = { white = 0.6, alpha = 1 },
              frame = { x = x, y = cy, w = 40, h = lineH },
              trackMouseUp = true, trackMouseDown = true, id = elemId,
            })
          end
        end
        cy = cy + lineH
      end
      if bi < #blocks then cy = cy + M.sectionGap end
    end

    if hasStatus then
      cv:appendElements({
        type = "rectangle", action = "fill",
        fillColor = { white = 1, alpha = 0.16 },
        frame = { x = pad, y = cy + 4, w = panelW - pad * 2, h = 1 },
      })
      cv:appendElements({
        type = "text", text = M.status,
        textFont = "Menlo", textSize = M.fontSize - 1,
        textColor = { red = 1, green = 0.82, blue = 0.35, alpha = 1 },
        frame = { x = pad, y = cy + 9, w = panelW - pad * 2, h = lineH },
      })
      cy = cy + statusH
    end

    if staleText then
      cv:appendElements({
        type = "rectangle", action = "fill",
        fillColor = { white = 1, alpha = 0.16 },
        frame = { x = pad, y = cy + 4, w = panelW - pad * 2, h = 1 },
      })
      cv:appendElements({
        type = "text", text = staleText,
        textFont = "Menlo", textSize = M.fontSize - 1,
        textColor = { red = 1, green = 0.72, blue = 0.35, alpha = 1 },
        frame = { x = pad, y = cy + 9, w = panelW - pad * 2, h = lineH },
        trackMouseUp = true, trackMouseDown = true, id = "rescan",
      })
      cy = cy + staleH
    end

    if alertText then
      cv:appendElements({
        type = "rectangle", action = "fill",
        fillColor = { white = 1, alpha = 0.16 },
        frame = { x = pad, y = cy + 4, w = panelW - pad * 2, h = 1 },
      })
      cv:appendElements({
        type = "text", text = alertText,
        textFont = "Menlo", textSize = M.fontSize - 1,
        textColor = M.remoteAlertColor or { red = 1, green = 0.45, blue = 0.45, alpha = 1 },
        frame = { x = pad, y = cy + 9, w = panelW - pad * 2, h = lineH },
      })
      cy = cy + alertH
    end

    if #legendLines > 0 then
      cv:appendElements({
        type = "rectangle", action = "fill",
        fillColor = { white = 1, alpha = 0.16 },
        frame = { x = pad, y = cy + 4, w = panelW - pad * 2, h = 1 },
      })
      local ly = cy + 9
      local lineH2 = M.fontSize + 3
      for _, ln in ipairs(legendLines) do
        cv:appendElements({
          type = "text", text = ln,
          textFont = "Menlo", textSize = M.fontSize - 2,
          textColor = { white = 0.6, alpha = 1 },
          frame = { x = pad, y = ly, w = panelW - pad * 2, h = lineH2 },
        })
        -- Any clickable word in this line is drawn a SECOND time, in blue, over
        -- the gray one, with a transparent tracked rectangle on top to own the
        -- click. Overdrawing rather than splitting the line into runs keeps the
        -- line's own layout untouched — it is the same string at the same x, so
        -- nothing shifts if legendClicks is empty or a word isn't found.
        for word, elemId in pairs(M.legendClicks or {}) do
          local at = ln:find(word, 1, true)
          if at then
            local wx = pad + legendWidth(ln:sub(1, at - 1))
            local ww = legendWidth(word)
            cv:appendElements({
              type = "text", text = word,
              textFont = "Menlo", textSize = M.fontSize - 2,
              textColor = M.legendClickColor or { red = 0.45, green = 0.75, blue = 1, alpha = 1 },
              frame = { x = wx, y = ly, w = ww + 4, h = lineH2 },
            })
            -- Same reason every icon carries one: a canvas text element is not a
            -- reliable mouse target, and a fully transparent rectangle still
            -- hit-tests. trackMouseDown too, so a drag begun here still moves
            -- the panel instead of dead-ending on the word.
            cv:appendElements({
              type = "rectangle", action = "fill",
              fillColor = { white = 1, alpha = 0 },
              frame = { x = wx - 2, y = ly, w = ww + 6, h = lineH2 },
              trackMouseUp = true, trackMouseDown = true, id = elemId,
            })
          end
        end
        ly = ly + lineH2
      end
    end

    -- The resize grip, last so it sits above everything: three diagonal strokes
    -- in the bottom-right corner, plus the usual transparent rectangle to own
    -- the drag. Deliberately at the OPPOSITE corner from the panel's anchor, so
    -- resizing grows the panel away from its top-left and the corner you are
    -- holding is the one that moves.
    if M.showResizeGrip ~= false then
      local g  = math.max(12, math.floor(M.fontSize * 1.1))
      local gx, gy = panelW - g - 4, panelH - g - 4
      for i = 1, 3 do
        local off = (i - 1) * math.max(3, math.floor(g / 4))
        cv:appendElements({
          type = "segments", action = "stroke",
          strokeColor = { white = 1, alpha = 0.30 }, strokeWidth = 1.5,
          coordinates = { { x = gx + off, y = gy + g }, { x = gx + g, y = gy + off } },
        })
      end
      cv:appendElements({
        type = "rectangle", action = "fill", fillColor = { white = 0, alpha = 0 },
        frame = { x = gx - 4, y = gy - 4, w = g + 8, h = g + 8 },
        trackMouseUp = true, trackMouseDown = true, id = "resize",
      })
    end

    cv:show()
    canvases[#canvases + 1] = { cv = cv, uuid = uuid }
  end

  refreshTip()                   -- a tip on screen is anchored to a dead canvas
end

-- ---- public actions -------------------------------------------------------

function M.refresh() scanActive(); draw() end
function M.redraw() draw() end

-- Coalesce bursts of window open/close events into a single refresh shortly
-- after they settle, so opening CLAUDE.md (or closing a repo's windows) on the
-- current Desktop updates its label on its own.
local function debouncedRefresh()
  if debounceTimer then debounceTimer:stop() end
  debounceTimer = hs.timer.doAfter(0.8, function()
    if not scanningAll then M.refresh() end
  end)
end

-- ⌘⌃⌥D hides ONE display's panel — the one the mouse is on — rather than all of
-- them. With two screens the panel is drawn on each, and wanting it gone from
-- the screen you are working on does not mean wanting it gone everywhere. Press
-- again on that screen to bring it back; M.showAll() restores every display.
function M.toggle()
  local scr = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local uuid = scr and scr:getUUID()
  if not uuid then                       -- no screen identity: fall back to all-or-nothing
    M.visible = not M.visible
    clearHover(); draw(); return
  end
  hiddenScreens[uuid] = (not hiddenScreens[uuid]) or nil
  M.visible = true                       -- a per-screen hide must not leave the master off
  clearHover()
  pcall(M.saveLayout)
  draw()
  local msg = hiddenScreens[uuid]
    and ("Dashboard hidden on " .. (scr:name() or "this display"))
    or  ("Dashboard shown on " .. (scr:name() or "this display"))
  if not pcall(hs.alert.show, msg, nil, scr, 1.2) then pcall(hs.alert.show, msg) end
end

-- Bring every display's panel back, whichever way it was hidden.
function M.showAll()
  hiddenScreens = {}
  M.visible = true
  pcall(M.saveLayout)
  draw()
  hs.alert.show("Dashboard shown on all displays")
end

function M.nameCurrent()
  -- The Desktop you mean is the one you are WORKING on — the focused Space —
  -- not the one under the mouse pointer. Those were the same thing until the
  -- panel could be dragged across a display boundary: with it straddling two
  -- screens, resting the pointer over the panel put ⌘⌃⌥N on the other display's
  -- Desktop, so it renamed something you weren't looking at. The mouse is only
  -- the fallback now.
  local sid = (function()
    local ok, s = pcall(hs.spaces.focusedSpace)
    if ok and s then return s end
    return safeActiveSpace(hs.mouse.getCurrentScreen() or hs.screen.mainScreen())
  end)()
  if not sid then hs.alert.show("Couldn't identify the current Desktop"); return end
  local cur = overrides[sid] or labelCache[sid] or ""
  local btn, txt = hs.dialog.textPrompt(
    "Name this Desktop",
    "Custom name for the Desktop you're on. Leave blank to clear it and go back to auto-detection.",
    cur, "Save", "Cancel")
  if btn ~= "Save" then return end
  txt = (txt or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if txt == "" then overrides[sid] = nil else overrides[sid] = txt end
  draw()
  M.saveLayout()
end

-- Walk every Desktop once, reading each as it becomes active.
function M.scanAll()
  scanningAll = true
  loadRepos()                    -- an explicit ⌘⌃⌥S always re-reads the repo list
  local start = {}
  for _, s in ipairs(hs.screen.allScreens()) do start[s] = safeActiveSpace(s) end
  local okF, startFocused = pcall(hs.spaces.focusedSpace)
  if not okF then startFocused = nil end
  local queue = {}
  for _, s in ipairs(hs.screen.allScreens()) do
    for i, sid in ipairs(safeSpacesForScreen(s)) do
      queue[#queue + 1] = { sid = sid, name = string.format("%s Desktop %d", s:name() or "Screen", i) }
    end
  end
  local k = 0
  local function step()
    k = k + 1
    if k > #queue then
      -- Restore one display at a time. Firing every gotoSpace in a tight loop
      -- leaves macOS mid-animation on the first switch, and the second one
      -- swallows it — which restored the built-in display but left the iMac
      -- parked on the last Desktop the walk visited.
      --
      -- The Space that had focus goes LAST, so focus lands back where it began
      -- rather than on whichever display happened to be restored last.
      local restores = {}
      for _, sid in pairs(start) do
        if sid and sid ~= startFocused then restores[#restores + 1] = sid end
      end
      if startFocused then restores[#restores + 1] = startFocused end

      local ri = 0
      local function restoreNext()
        ri = ri + 1
        if ri > #restores then
          scanTimer = hs.timer.doAfter(0.35, function()
            scanningAll = false; M.status = nil; pcall(scanActive); draw()
          end)
          return
        end
        pcall(hs.spaces.gotoSpace, restores[ri])
        scanTimer = hs.timer.doAfter(M.restoreDwell or 0.5, restoreNext)
      end
      restoreNext()
      return
    end
    local item = queue[k]
    M.status = string.format("Reading %s (%d/%d)…", item.name, k, #queue)
    draw()
    pcall(hs.spaces.gotoSpace, item.sid)
    -- step() MUST run even if reading this Desktop blows up. Without the pcall
    -- one failed read killed the timer callback, and the walk simply stopped
    -- wherever it happened to be — the reported "it stops on Retina #9".
    scanTimer = hs.timer.doAfter(M.scanDwell, function()
      pcall(function()
        local byId, byCg = snapshot()
        labelSpace(byId, item.sid, byCg)
        draw()
      end)
      step()
    end)
  end
  step()
end

function M.saveLayout()
  -- No early return on an empty lastGather any more. That guard existed to stop
  -- a blank layout being written before the first scan, but this file now also
  -- carries the chosen mode and the panel position, which have nothing to do
  -- with window lists — and the guard silently discarded both. Writing an empty
  -- layout is no longer a risk either: unread Desktops carry their previous
  -- window lists forward (see below).
  -- Previously saved layout. We only hold window lists for Desktops read since
  -- the last reload (macOS won't let us read a Space we aren't viewing), and
  -- this rewrites every Desktop — so without carrying the old lists forward,
  -- each autosave blanked every Desktop not visited this session. Measured:
  -- 6 of 12 Desktops had been emptied that way.
  local prev = loadState()
  local state = { savedAt = os.time(), mode = M.mode, fontSize = M.fontSize, screens = {} }
  for _, s in ipairs(hs.screen.allScreens()) do
    local key    = s:getUUID() or s:name() or "screen"
    local spaces = safeSpacesForScreen(s)
    local desktops = {}
    local pscr = prev and prev.screens and prev.screens[key]
    for i, sid in ipairs(spaces) do
      local pd = pscr and pscr.desktops and pscr.desktops[i]
      local windows = {}
      local gathered = lastGather[sid]
      if gathered then
        for _, w in ipairs(gathered) do
          windows[#windows + 1] = { app = w.app, doc = w.doc or "", title = w.title or "" }
        end
      elseif pd and type(pd.windows) == "table" then
        windows = pd.windows
      end
      -- The icon row is saved for the same reason the NAME is: so a Desktop you
      -- haven't visited yet still shows something on launch. Bundle ids are all
      -- it takes to draw an icon — no window read needed — which is why this
      -- was the missing half. Window ids are deliberately NOT saved: they are
      -- reused after a reboot, so a stale one could raise a window that has
      -- nothing to do with the icon you clicked. A restored icon shows and
      -- names itself; it just doesn't raise anything until the Desktop is read.
      local icons, live = nil, iconApps[sid]
      if live then
        local apps = {}
        for _, a in ipairs(live) do
          if a.bundle and a.bundle ~= "" then apps[#apps + 1] = { bundle = a.bundle, app = a.app or "" } end
        end
        icons = { named = live.named and true or false, min = live.min or 0,
                  lead = live.lead or #apps, apps = apps }
      elseif pd and type(pd.icons) == "table" then
        icons = pd.icons                       -- carry an unread Desktop forward
      end
      desktops[i] = {
        index = i, name = overrides[sid] or labelCache[sid] or "",
        manual = overrides[sid] ~= nil, windows = windows, icons = icons,
      }
    end
    state.screens[key] = { name = s:name() or "", desktops = desktops,
                           panel = panelPos[key],
                           hidden = hiddenScreens[key] or nil }
  end
  saveState(state)
end

local function restoreNames()
  local state = loadState()
  if not state then return end
  -- The view you chose should survive a reload; it used to snap back to the
  -- M.mode default every time.
  if type(state.mode) == "string" and
     (state.mode == "desktops" or state.mode == "terminals" or state.mode == "both") then
    M.mode = state.mode
  end
  -- A size you zoomed to should survive a reload, like the position you dragged
  -- to. Clamped on the way in: the file is editable and a bad value would make
  -- the panel unusable with no way back except editing it again.
  local fs = tonumber(state.fontSize)
  if fs then
    M.fontSize = math.max(M.minFontSize or 9, math.min(M.maxFontSize or 28, math.floor(fs)))
  end
  if not state.screens then return end
  for _, s in ipairs(hs.screen.allScreens()) do
    local key   = s:getUUID() or s:name() or "screen"
    local saved = state.screens[key]
    if saved and type(saved.panel) == "table"
       and tonumber(saved.panel.x) and tonumber(saved.panel.y) then
      panelPos[key] = { x = tonumber(saved.panel.x), y = tonumber(saved.panel.y) }
    end
    if saved and saved.hidden == true then hiddenScreens[key] = true end
    if saved and saved.desktops then
      local spaces = safeSpacesForScreen(s)
      for i, sid in ipairs(spaces) do
        local d = saved.desktops[i]
        if d and d.name and d.name ~= "" then
          labelCache[sid] = d.name
          if d.manual then overrides[sid] = d.name end
        end
        -- Icons come back with the names, so a fresh launch looks like the panel
        -- you left rather than a column of bare words waiting on ⌘⌃⌥S.
        if d and type(d.icons) == "table" and type(d.icons.apps) == "table" then
          local list = {}
          for _, a in ipairs(d.icons.apps) do
            if type(a) == "table" and a.bundle and a.bundle ~= "" then
              list[#list + 1] = { bundle = a.bundle, app = a.app or "?" }
            end
          end
          if #list > 0 then
            list.named    = d.icons.named and true or false
            list.min      = tonumber(d.icons.min) or 0
            list.lead     = tonumber(d.icons.lead) or #list
            list.restored = true
            iconApps[sid] = list
          end
        end
      end
    end
  end
end

local function findVisibleWindow(app, doc)
  for _, w in ipairs(openWindows()) do
    if w.app == app and (w.doc or "") == (doc or "") then return w.win end
  end
  return nil
end

function M.restoreLayout()
  local state = loadState()
  if not (state and state.screens) then hs.alert.show("No saved layout found"); return end

  local open = {}
  for _, w in ipairs(openWindows()) do
    open[w.app .. "\0" .. (w.doc or "")] = { win = w.win, sid = w.sid }
  end

  local toCreate, moved = {}, 0
  for _, s in ipairs(hs.screen.allScreens()) do
    local saved  = state.screens[s:getUUID() or s:name() or "screen"]
    local spaces = safeSpacesForScreen(s)
    if saved and saved.desktops then
      for i, sid in ipairs(spaces) do
        local d = saved.desktops[i]
        if d and d.windows then
          for _, sw in ipairs(d.windows) do
            local o = open[sw.app .. "\0" .. (sw.doc or "")]
            if o and o.win then
              if o.sid ~= sid then pcall(hs.spaces.moveWindowToSpace, o.win, sid); moved = moved + 1 end
            elseif sw.doc and sw.doc ~= "" then
              toCreate[#toCreate + 1] = { app = sw.app, doc = sw.doc, sid = sid }
            end
          end
        end
      end
    end
  end

  hs.alert.show(string.format("Restore: moved %d, opening %d…", moved, #toCreate))
  local ci = 0
  local function createNext()
    ci = ci + 1
    local item = toCreate[ci]
    if not item then hs.timer.doAfter(0.6, M.refresh); return end
    -- shQuote, not bare '…'. A document path containing an apostrophe —
    -- "Peter's notes.md" — closed the quote early and made the whole command a
    -- shell SYNTAX ERROR, so that file silently failed to open and every later
    -- word was reinterpreted. Verified 2026-08-03: the old form dies with
    -- "unexpected EOF while looking for matching `''", the quoted form works.
    pcall(hs.execute, "open -a " .. shQuote(item.app) .. " " .. shQuote(item.doc), true)
    hs.timer.doAfter(1.5, function()
      local win = findVisibleWindow(item.app, item.doc)
      if win then pcall(hs.spaces.moveWindowToSpace, win, item.sid) end
      createNext()
    end)
  end
  createNext()
end

function M.start()
  loadRepos()
  restoreNames()
  M.visible = true

  -- Our own LocalHostName, so markers written by THIS Mac are ignored — the red
  -- dot is already showing them. `hostname` is not usable here: on the laptop it
  -- returns a VPN DHCP name. Read once, asynchronously; until it arrives the
  -- filter simply doesn't apply, which shows one redundant alert at worst.
  local okh, th = pcall(hs.task.new, "/usr/sbin/scutil", function(_, out, _)
    localHostName = tostring(out or ""):gsub("%s+$", "")
    if localHostName == "" then localHostName = nil end
  end, { "--get", "LocalHostName" })
  if okh and th then th:start() end
  draw()                         -- show restored names instantly, no scanning yet
  -- Defer the first read so config load always finishes and the menubar stays
  -- responsive (you can always Reload Config even if a read later misbehaves).
  hs.timer.doAfter(1.5, function() pcall(scanActive); draw() end)

  spaceWatcher  = hs.spaces.watcher.new(function() scanActive(); draw() end); spaceWatcher:start()
  screenWatcher = hs.screen.watcher.new(function() scanActive(); draw() end); screenWatcher:start()

  -- Refresh when windows open or close (e.g. you open CLAUDE.md, or close a
  -- repo's windows), so a Desktop's label updates without waiting for a switch.
  winWatcher = hs.window.filter.new()
  winWatcher:subscribe({ hs.window.filter.windowCreated, hs.window.filter.windowDestroyed }, debouncedRefresh)

  refreshTimer  = hs.timer.doEvery(M.refreshSeconds, M.refresh)
  -- The dot gets its own, faster timer. Riding the 10s scan made it lag far
  -- enough that a session looked idle for seconds after it started working.
  claudeTimer   = hs.timer.doEvery(M.claudeDotSeconds, refreshClaudeStates)
  -- The git dot has its own, slower timer: it is offline and cheap, but there is
  -- no reason to re-read it as often as the claude spinner.
  gitTimer      = hs.timer.doEvery(M.gitDotSeconds, refreshGitStates)

  -- Remote alerts: a path watcher fires within a second of Dropbox landing the
  -- file, and a slow timer is the backstop for the case where it doesn't (a
  -- sync client that swaps the directory can leave the watcher pointed at a
  -- vanished inode). Both are cheap — one directory read of a folder that is
  -- empty almost all the time.
  if M.showRemoteAlerts and M.remoteAlertDir then
    remoteTimer = hs.timer.doEvery(M.remoteAlertSeconds or 20, refreshRemoteAlerts)
    local okw, w = pcall(hs.pathwatcher.new, M.remoteAlertDir, function()
      -- Coalesce: a sync writes a file in more than one step and would
      -- otherwise fire this several times for one marker.
      remoteDebounce = hs.timer.doAfter(0.5, refreshRemoteAlerts)
    end)
    if okw and w then remoteWatcher = w; pcall(function() w:start() end) end
    hs.timer.doAfter(2.0, refreshRemoteAlerts)   -- primes the seen-set
  end
  autosaveTimer = hs.timer.doEvery(M.autosaveMinutes * 60, M.saveLayout)
  hs.shutdownCallback = function() pcall(M.saveLayout) end

  hs.hotkey.bind(M.toggleHotkey.mods,  M.toggleHotkey.key,  M.toggle)
  hs.hotkey.bind(M.nameHotkey.mods,    M.nameHotkey.key,    M.nameCurrent)
  hs.hotkey.bind(M.restoreHotkey.mods, M.restoreHotkey.key, M.restoreLayout)
  hs.hotkey.bind(M.scanHotkey.mods,    M.scanHotkey.key,    M.scanAll)
  hs.hotkey.bind(M.modeHotkey.mods,    M.modeHotkey.key,    M.cycleMode)
  if M.githubHotkey then
    hs.hotkey.bind(M.githubHotkey.mods, M.githubHotkey.key, M.scanGitHub)
  end

  print("desktop_dashboard " .. M.version .. " loaded")
  hs.alert.show("Desktop dashboard " .. M.version .. " on")
  return M
end

function M.stop()
  endDrag(false)                 -- never leave a mouse tap running
  clearHover()                   -- nor a tip, nor its poll timer
  if focusTimer then focusTimer:stop(); focusTimer = nil end
  if refreshTimer  then refreshTimer:stop() end
  if claudeTimer   then claudeTimer:stop() end
  if gitTimer      then gitTimer:stop() end
  if remoteTimer   then remoteTimer:stop(); remoteTimer = nil end
  if remoteDebounce then remoteDebounce:stop(); remoteDebounce = nil end
  if remoteWatcher then pcall(function() remoteWatcher:stop() end); remoteWatcher = nil end
  if ghWatchdog    then ghWatchdog:stop(); ghWatchdog = nil end
  if ghTask        then pcall(function() ghTask:terminate() end); ghTask = nil end
  if ghWebview     then pcall(function() ghWebview:delete() end); ghWebview = nil end
  if autosaveTimer then autosaveTimer:stop() end
  if spaceWatcher  then spaceWatcher:stop() end
  if screenWatcher then screenWatcher:stop() end
  if winWatcher    then winWatcher:unsubscribeAll() end
  for _, c in ipairs(canvases) do pcall(function() c.cv:delete() end) end
  canvases = {}
end

return M
