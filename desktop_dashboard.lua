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
    • ⌘⌃⌥S walks every Desktop, reading each as it becomes active, to fill
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

  CONTROLS
  --------
  • Click a line — switch to that Desktop.
  • ⌘⌃⌥ D — show / hide the dashboard.
  • ⌘⌃⌥ N — name the current Desktop (blank clears it).
  • ⌘⌃⌥ R — restore the saved window layout (move/open windows).
  • ⌘⌃⌥ S — walk every Desktop once and label them all.
  • ⌘⌃⌥ M — cycle what the panel lists: Desktops / claude sessions / both.
  • Drag the panel to move it; its position is remembered per display.

  Names + window layout auto-save (periodically and at logout/shutdown) to
  ~/.hammerspoon/desktop_dashboard_state.json.
============================================================]]--

local M = {}
M.version = "v27 (terminals mode: one line per claude session, 2026-07-28)"

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
M.claudeDotSeconds = 3           -- how often titles are read (async, never blocks)
M.claudeStateDir   = os.getenv("HOME") .. "/.hammerspoon/claude_state"
M.claudeHookMaxAgeHours = 12     -- ignore state files older than this
M.claudeDotColors  = {
  working = { red = 1.00, green = 0.78, blue = 0.20, alpha = 1 },   -- yellow: computing
  waiting = { red = 1.00, green = 0.28, blue = 0.26, alpha = 1 },   -- red: wants you
  done    = { red = 0.30, green = 0.85, blue = 0.40, alpha = 1 },   -- green: finished, unseen
}

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
M.sessionSummaryChars = 32      -- task summary shown after the project name; the
                                -- summary is what tells two sessions in the same
                                -- repo apart, so it is worth the width
M.modeHotkey      = { mods = {"cmd","ctrl","alt"}, key = "m" }

-- Drag the panel with the mouse. A position you drag to is remembered per
-- display and survives a reload; M.resetPanelPosition() puts it back in the
-- corner. Set false to pin the panel and disable all mouse-drag handling.
M.draggable       = true
M.dragThreshold   = 3           -- px of movement before a press counts as a drag
                                -- rather than a click on a Desktop line

M.corner          = "topleft"
M.margin          = 14
M.fontSize        = 13
M.minWidth        = 220
M.maxWidth        = 760
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

-- Command legend shown at the bottom of the panel. Set showLegend=false to
-- hide it; edit legendLines if you remap the hotkeys above.
M.showLegend  = true
-- Split across two lines on purpose: the legend is the widest thing in the
-- panel in Desktops mode, so appending to one line widens the whole panel.
M.legendLines = {
  "⌘⌃⌥  S scan · D hide · N name",
  "     R restore · M mode",
  "click a line to switch Desktops",
}

-- ===============================================================

local canvases   = {}          -- { { cv = canvas, uuid = screenUUID }, ... }
local panelPos   = {}          -- screen UUID -> { x =, y = } once dragged
local drag       = nil         -- in-flight drag session, nil when idle
local dragTap, dragWatchdog
local labelCache = {}          -- spaceID -> label string
local lastGather = {}          -- spaceID -> { {app,title,doc,win}, ... }
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
            repos[#repos + 1] = { name = name, norm = normalize(name), tokens = tokenSet(name) }
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
local function parseClaudeTitles(text)
  local byRepo, sessions = {}, {}
  for line in tostring(text or ""):gmatch("[^\r\n]+") do
    local wid, title = line:match("^(%d+)|(.*)$")
    if not title then title = line end            -- tolerate an id-less read
    -- Terminal builds its title from parts: cwd — <spinner + task> — process — WxH
    local comps = {}
    for part in (title .. " — "):gmatch("(.-) — ") do comps[#comps + 1] = part end
    -- A real session has all four parts AND names claude as the running process.
    -- Matching "claude" anywhere in the title also caught a plain shell sitting
    -- in a directory called .claude, which it did.
    local proc = comps[#comps - 1]
    if #comps >= 4 and proc and proc:lower():find("claude", 1, true) then
      local cwd  = comps[1]
      local body = comps[2] or ""
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
  return byRepo, sessions
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
    local label = overrides[sid] or labelCache[sid]
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
    claudeStates, sessions = parseClaudeTitles(stdout)
    claudeHooks  = readHookStates()
    noteTransitions(claudeStates)
    noteSessionTransitions(sessions)
    -- Acknowledgement is left to scanActive / the space watcher, which already
    -- know which Spaces are active; asking hs.spaces again here would be slow.
    -- Redraw only when a dot actually changed. draw() tears down and rebuilds
    -- every canvas, so repainting on an unchanged result is pure churn.
    if dotKey() ~= before then pcall(draw) end
  end, { "-e", CLAUDE_TITLE_SCRIPT })
  if ok and t then claudeTask = t; t:start() end
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
local function detectLabel(funcs, ctx)
  -- 1) an open document inside a repo (editor apps only).
  for _, w in ipairs(funcs) do
    local repo = repoForPath(w.doc)
    if repo then return repo end
  end
  -- 2) a repo name in any title on the Desktop — the claude terminal's title
  --    or a Finder window parked in the repo both count as a hint.
  local nc = normalize(ctx or "")
  local proj, projLen = nil, 0
  for _, r in ipairs(repos) do
    if #r.norm >= 4 and nc:find(r.norm, 1, true) and #r.norm > projLen then proj, projLen = r.name, #r.norm end
  end
  if proj then return proj end
  -- 3) token overlap.
  local ctoks = tokenSet(nc)
  local best, bestScore = nil, 1
  for _, r in ipairs(repos) do
    local score = 0
    for t in pairs(r.tokens) do if ctoks[t] then score = score + 1 end end
    if score > bestScore then best, bestScore = r.name, score end
  end
  if best then return best end
  -- 4) no repo — fall back to the apps. One app → its own name (Mail); several
  --    apps sharing one subject → that subject (Communication); several
  --    different subjects → Utility.
  if #funcs == 0 then return "—" end
  local cats, catOrder, apps, appOrder = {}, {}, {}, {}
  for _, w in ipairs(funcs) do
    local c = categorize(w.app)
    if not cats[c] then cats[c] = true; catOrder[#catOrder + 1] = c end
    if not apps[w.app] then apps[w.app] = true; appOrder[#appOrder + 1] = w.app end
  end
  if #catOrder >= (M.utilityMinSubjects or 2) then return M.utilityLabel or "Utility" end
  if #appOrder == 1 then                          -- single app → its own name
    return M.appLabels[appOrder[1]] or appOrder[1]
  end
  return catOrder[1] or "?"                        -- several apps, one subject
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
  return byId
end

-- Functional windows on a Space (from the snapshot) + the context text used
-- for repo hints. Terminal/Finder are excluded from the subject decision but
-- their titles still feed the repo hint.
local function readSpaceFrom(byId, sid)
  local funcs, ctx = {}, {}
  local ids = safeWindowsForSpace(sid)
  if not ids then return nil end        -- transient failure; caller keeps old label
  for _, id in ipairs(ids) do
    local w = byId[id]
    if w then
      local oks, std = pcall(function() return w:isStandard() end)
      if oks and std then
        local appObj = w:application()
        local app = appObj and appObj:name() or ""
        if app ~= "" then
          local title = w:title() or ""
          -- Decide whether this window's title may suggest a repo. Three cases:
          -- never (browsers, chat apps, Finder), only-if-claude (terminals),
          -- and everything else, which contributes normally.
          local hint = true
          if M.noRepoHintApps[app] then
            hint = false
          elseif M.claudeOnlyHintApps[app] then
            hint = title:lower():find(M.claudeTitleMarker or "claude", 1, true) ~= nil
          end
          if hint then ctx[#ctx + 1] = title end
          if not M.ignoreApps[app] then
            ctx[#ctx + 1] = app
            funcs[#funcs + 1] = { win = w, app = app, title = title,
                                  doc = M.docApps[app] and docOf(w) or nil }  -- editors only
          end
        end
      end
    end
  end
  return funcs, table.concat(ctx, " ")
end

local function labelSpace(byId, sid)
  local funcs, ctx = readSpaceFrom(byId, sid)
  if not funcs then return end   -- unreadable this time; better a stale name than "—"
  labelCache[sid] = detectLabel(funcs, ctx)
  lastGather[sid] = funcs
end

-- Read the Desktop(s) currently active on each display (one snapshot for all).
local function scanActive()
  refreshRepos()
  refreshClaudeStates()
  local byId = snapshot()
  local sids = activeSids()
  for _, sid in ipairs(sids) do labelSpace(byId, sid) end
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
  local isRepo = false
  for _, r in ipairs(repos) do
    if r.name:lower() == key then isRepo = true break end
  end
  if not isRepo then return nil end
  -- Computing beats everything: once you answer a question the session resumes,
  -- the spinner returns, and the dot goes yellow without waiting on a hook.
  if state == "working" then return "working" end
  -- Not computing. Only the hooks can say whether that is "blocked on you"
  -- (red) or "finished" (green) — the title looks identical either way.
  if claudeHooks[key] == "waiting" then return "waiting" end
  if claudeDone[key] then return "done" end
  return nil
end

-- One line per live claude session: "T1 ● project — summary".
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
    local dot = state and (M.claudeDotChar or "●") or " "
    local summary = tostring(s.summary or "")
    local lim = M.sessionSummaryChars or 32
    if uwidth(summary) > lim then summary = summary:sub(1, lim) .. "…" end
    local prefix = string.format("   T%d ", i)
    local suffix = string.format(" %s%s", s.project or "?",
                                 summary ~= "" and ("  " .. summary) or "")
    entries[#entries + 1] = {
      sid = nil, wid = s.wid, state = state, dot = dot,
      prefix = prefix, suffix = suffix, text = prefix .. dot .. suffix,
    }
  end
  if #entries == 0 then
    local msg = "   (no claude sessions found)"
    entries[1] = { state = nil, dot = " ", prefix = msg, suffix = "", text = msg }
  end
  return entries
end

local function screenEntries(screen)
  local spaces = safeSpacesForScreen(screen)
  local active = safeActiveSpace(screen)
  local entries = {}
  for i, sid in ipairs(spaces) do
    local label = overrides[sid] or labelCache[sid] or "…"
    local state = claudeStateFor(label)
    -- Desktops with no session keep a blank slot so the arrows stay aligned.
    local dot    = state and (M.claudeDotChar or "●") or " "
    local prefix = string.format("%sDesktop %d ", (sid == active) and "▸ " or "   ", i)
    local suffix = string.format(" → %s", label)
    entries[#entries + 1] = {
      sid = sid, state = state, dot = dot, prefix = prefix, suffix = suffix,
      text = prefix .. dot .. suffix,        -- plain form, used for sizing
    }
  end
  return entries
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
  local nx, ny = d.originX + dx, d.originY + dy
  pcall(function() d.cv:topLeft({ x = nx, y = ny }) end)
  if d.uuid then panelPos[d.uuid] = { x = nx, y = ny } end
  return true
end

local function startDrag(cv, uuid, elementId)
  if not (M.draggable and cv) then return end
  endDrag(false)                         -- never stack sessions
  local okTL, tl = pcall(function() return cv:topLeft() end)
  if not (okTL and tl) then return end
  local m = hs.mouse.absolutePosition()
  drag = { cv = cv, uuid = uuid, elementId = elementId, moved = false,
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
  if message == "mouseDown" then
    if not M.draggable then return end
    local uuid
    for _, c in ipairs(canvases) do
      if c.cv == cv then uuid = c.uuid break end
    end
    startDrag(cv, uuid, elementId)
  elseif message == "mouseUp" then
    -- When dragging is on, the event tap decides click-vs-drag; it also catches
    -- a release that lands after the pointer has left the panel.
    if M.draggable then return end
    activateElement(elementId)
  end
end

-- Cycle desktops -> terminals -> both. Kept as a hotkey because which view is
-- useful depends on how you have your sessions arranged today.
function M.cycleMode()
  local order = { desktops = "terminals", terminals = "both", both = "desktops" }
  M.mode = order[M.mode] or "desktops"
  pcall(scanActive)
  draw()
  hs.alert.show("Dashboard: " .. M.mode)
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
  if not M.visible then return end

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
  local legendLines = (M.showLegend and M.legendLines) or {}
  for _, ln in ipairs(legendLines) do maxChars = math.max(maxChars, uwidth(ln)) end

  local lineH   = M.fontSize + 6
  local pad     = 12
  local charW   = M.fontSize * 0.62
  local statusH = hasStatus and (lineH + 9) or 0
  local legendH = (#legendLines > 0) and (10 + #legendLines * (M.fontSize + 3)) or 0
  local bodyW   = math.max(M.minWidth - pad * 2, math.ceil(maxChars * charW) + 6)
  local panelW  = math.min(M.maxWidth, bodyW + pad * 2)
  local panelH  = pad * 2 + totalRows * lineH + math.max(0, #blocks - 1) * M.sectionGap + statusH + legendH

  for _, s in ipairs(screens) do
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
        -- Colour only the dot. hs.styledtext keeps this one text element, so
        -- the click target is unchanged and no glyph positions are computed.
        local body = e.text
        if e.state then
          local font  = { name = "Menlo", size = M.fontSize }
          local plain = { font = font, color = { white = 1, alpha = 1 } }
          local hot   = { font = font,
                          color = (M.claudeDotColors or {})[e.state]
                                  or { white = 1, alpha = 1 } }
          local ok, styled = pcall(function()
            return hs.styledtext.new(e.prefix, plain)
                .. hs.styledtext.new(e.dot, hot)
                .. hs.styledtext.new(e.suffix, plain)
          end)
          if ok and styled then body = styled end
        end
        cv:appendElements({
          type = "text", text = body,
          textFont = "Menlo", textSize = M.fontSize,
          textColor = { white = 1, alpha = 1 },
          frame = { x = pad, y = cy, w = panelW - pad * 2, h = lineH },
          trackMouseUp = true, trackMouseDown = true,
          id = e.sid and ("go:" .. tostring(e.sid))
               or (e.wid and ("term:" .. tostring(e.wid)) or "line"),
        })
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

    if #legendLines > 0 then
      cv:appendElements({
        type = "rectangle", action = "fill",
        fillColor = { white = 1, alpha = 0.16 },
        frame = { x = pad, y = cy + 4, w = panelW - pad * 2, h = 1 },
      })
      local ly = cy + 9
      for _, ln in ipairs(legendLines) do
        cv:appendElements({
          type = "text", text = ln,
          textFont = "Menlo", textSize = M.fontSize - 2,
          textColor = { white = 0.6, alpha = 1 },
          frame = { x = pad, y = ly, w = panelW - pad * 2, h = M.fontSize + 3 },
        })
        ly = ly + (M.fontSize + 3)
      end
    end

    cv:show()
    canvases[#canvases + 1] = { cv = cv, uuid = uuid }
  end
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

function M.toggle()
  M.visible = not M.visible
  draw()
end

function M.nameCurrent()
  local scr = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local sid = safeActiveSpace(scr)
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
      pcall(function() labelSpace(snapshot(), item.sid); draw() end)
      step()
    end)
  end
  step()
end

function M.saveLayout()
  if next(lastGather) == nil then return end
  -- Previously saved layout. We only hold window lists for Desktops read since
  -- the last reload (macOS won't let us read a Space we aren't viewing), and
  -- this rewrites every Desktop — so without carrying the old lists forward,
  -- each autosave blanked every Desktop not visited this session. Measured:
  -- 6 of 12 Desktops had been emptied that way.
  local prev = loadState()
  local state = { savedAt = os.time(), screens = {} }
  for _, s in ipairs(hs.screen.allScreens()) do
    local key    = s:getUUID() or s:name() or "screen"
    local spaces = safeSpacesForScreen(s)
    local desktops = {}
    for i, sid in ipairs(spaces) do
      local windows = {}
      local gathered = lastGather[sid]
      if gathered then
        for _, w in ipairs(gathered) do
          windows[#windows + 1] = { app = w.app, doc = w.doc or "", title = w.title or "" }
        end
      else
        local pscr = prev and prev.screens and prev.screens[key]
        local pd   = pscr and pscr.desktops and pscr.desktops[i]
        if pd and type(pd.windows) == "table" then windows = pd.windows end
      end
      desktops[i] = {
        index = i, name = overrides[sid] or labelCache[sid] or "",
        manual = overrides[sid] ~= nil, windows = windows,
      }
    end
    state.screens[key] = { name = s:name() or "", desktops = desktops,
                           panel = panelPos[key] }
  end
  saveState(state)
end

local function restoreNames()
  local state = loadState()
  if not (state and state.screens) then return end
  for _, s in ipairs(hs.screen.allScreens()) do
    local key   = s:getUUID() or s:name() or "screen"
    local saved = state.screens[key]
    if saved and type(saved.panel) == "table"
       and tonumber(saved.panel.x) and tonumber(saved.panel.y) then
      panelPos[key] = { x = tonumber(saved.panel.x), y = tonumber(saved.panel.y) }
    end
    if saved and saved.desktops then
      local spaces = safeSpacesForScreen(s)
      for i, sid in ipairs(spaces) do
        local d = saved.desktops[i]
        if d and d.name and d.name ~= "" then
          labelCache[sid] = d.name
          if d.manual then overrides[sid] = d.name end
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
    pcall(hs.execute, "open -a '" .. item.app .. "' '" .. item.doc .. "'", true)
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
  autosaveTimer = hs.timer.doEvery(M.autosaveMinutes * 60, M.saveLayout)
  hs.shutdownCallback = function() pcall(M.saveLayout) end

  hs.hotkey.bind(M.toggleHotkey.mods,  M.toggleHotkey.key,  M.toggle)
  hs.hotkey.bind(M.nameHotkey.mods,    M.nameHotkey.key,    M.nameCurrent)
  hs.hotkey.bind(M.restoreHotkey.mods, M.restoreHotkey.key, M.restoreLayout)
  hs.hotkey.bind(M.scanHotkey.mods,    M.scanHotkey.key,    M.scanAll)
  hs.hotkey.bind(M.modeHotkey.mods,    M.modeHotkey.key,    M.cycleMode)

  print("desktop_dashboard " .. M.version .. " loaded")
  hs.alert.show("Desktop dashboard " .. M.version .. " on")
  return M
end

function M.stop()
  endDrag(false)                 -- never leave a mouse tap running
  if refreshTimer  then refreshTimer:stop() end
  if claudeTimer   then claudeTimer:stop() end
  if autosaveTimer then autosaveTimer:stop() end
  if spaceWatcher  then spaceWatcher:stop() end
  if screenWatcher then screenWatcher:stop() end
  if winWatcher    then winWatcher:unsubscribeAll() end
  for _, c in ipairs(canvases) do pcall(function() c.cv:delete() end) end
  canvases = {}
end

return M
