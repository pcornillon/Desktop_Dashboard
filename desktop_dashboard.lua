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

  Names + window layout auto-save (periodically and at logout/shutdown) to
  ~/.hammerspoon/desktop_dashboard_state.json.
============================================================]]--

local M = {}
M.version = "v15 (auto-refresh on window changes, 2026-07-27)"

-- ============================ CONFIG ============================

M.repoRoots = {
  os.getenv("HOME") .. "/Git_Repos",
  -- add more, e.g.  os.getenv("HOME") .. "/Dropbox/Data",
}

M.ignoreApps = {
  ["Finder"] = true, ["Terminal"] = true, ["iTerm2"] = true, ["Hammerspoon"] = true,
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

M.corner          = "topleft"
M.margin          = 14
M.fontSize        = 13
M.minWidth        = 220
M.maxWidth        = 760
M.sectionGap      = 10
M.refreshSeconds  = 10          -- re-read the visible Desktop(s) this often (cheap)
M.scanDwell       = 0.6         -- dwell per Desktop during ⌘⌃⌥S
M.autosaveMinutes = 4
M.toggleHotkey    = { mods = {"cmd","ctrl","alt"}, key = "d" }
M.nameHotkey      = { mods = {"cmd","ctrl","alt"}, key = "n" }
M.restoreHotkey   = { mods = {"cmd","ctrl","alt"}, key = "r" }
M.scanHotkey      = { mods = {"cmd","ctrl","alt"}, key = "s" }

-- Command legend shown at the bottom of the panel. Set showLegend=false to
-- hide it; edit legendLines if you remap the hotkeys above.
M.showLegend  = true
M.legendLines = {
  "⌘⌃⌥  S scan · D hide · N name · R restore",
  "click a line to switch Desktops",
}

-- ===============================================================

local canvases   = {}
local labelCache = {}          -- spaceID -> label string
local lastGather = {}          -- spaceID -> { {app,title,doc,win}, ... }
local overrides  = {}          -- spaceID -> manual name
local repos      = {}
local refreshTimer, autosaveTimer, spaceWatcher, screenWatcher, winWatcher, debounceTimer
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

local function categorize(app)
  if M.categories[app] then return M.categories[app] end
  for _, r in ipairs(M.categoryPatterns) do
    if app:find(r.pat, 1, true) then return r.cat end
  end
  return app
end

local function repoForPath(path)
  if not path or path == "" then return nil end
  for _, root in ipairs(M.repoRoots) do
    if path:sub(1, #root + 1) == root .. "/" then
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
  if #appOrder == 1 then return appOrder[1] end   -- single app → its own name
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

local function activeSids()
  local t = {}
  for _, s in ipairs(hs.screen.allScreens()) do
    local sid = hs.spaces.activeSpaceOnScreen(s)
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
  for _, id in ipairs(hs.spaces.windowsForSpace(sid) or {}) do
    local w = byId[id]
    if w then
      local oks, std = pcall(function() return w:isStandard() end)
      if oks and std then
        local appObj = w:application()
        local app = appObj and appObj:name() or ""
        if app ~= "" then
          local title = w:title() or ""
          ctx[#ctx + 1] = title
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
  labelCache[sid] = detectLabel(funcs, ctx)
  lastGather[sid] = funcs
end

-- Read the Desktop(s) currently active on each display (one snapshot for all).
local function scanActive()
  local byId = snapshot()
  for _, sid in ipairs(activeSids()) do labelSpace(byId, sid) end
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

local function screenEntries(screen)
  local spaces = hs.spaces.spacesForScreen(screen) or {}
  local active = hs.spaces.activeSpaceOnScreen(screen)
  local entries = {}
  for i, sid in ipairs(spaces) do
    local label = overrides[sid] or labelCache[sid] or "…"
    entries[#entries + 1] = {
      sid = sid,
      text = string.format("%sDesktop %d → %s", (sid == active) and "▸ " or "   ", i, label),
    }
  end
  return entries
end

local function onMouse(_, message, elementId)
  if message == "mouseUp" and type(elementId) == "string" then
    local sid = elementId:match("^go:(%-?%d+)$")
    if sid then pcall(hs.spaces.gotoSpace, tonumber(sid)) end
  end
end

draw = function()
  for _, c in ipairs(canvases) do c:delete() end
  canvases = {}
  if not M.visible then return end

  local screens = hs.screen.allScreens()
  local multi   = (#screens > 1)
  local hasStatus = (M.status ~= nil and M.status ~= "")
  local blocks, maxChars, totalRows = {}, 8, 0
  for _, s in ipairs(screens) do
    local entries = screenEntries(s)
    local header  = multi and ((s:name() or "Screen") .. ":") or nil
    if header then maxChars = math.max(maxChars, uwidth(header)) end
    for _, e in ipairs(entries) do maxChars = math.max(maxChars, uwidth(e.text)) end
    totalRows = totalRows + #entries + (header and 1 or 0)
    blocks[#blocks + 1] = { header = header, entries = entries }
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
    local x, y
    if M.corner == "topleft" then x, y = f.x + M.margin, f.y + M.margin
    elseif M.corner == "topright" then x, y = f.x + f.w - panelW - M.margin, f.y + M.margin
    elseif M.corner == "bottomleft" then x, y = f.x + M.margin, f.y + f.h - panelH - M.margin
    else x, y = f.x + f.w - panelW - M.margin, f.y + f.h - panelH - M.margin end

    local cv = hs.canvas.new({ x = x, y = y, w = panelW, h = panelH })
    cv:behavior({ "canJoinAllSpaces", "stationary" })
    cv:level(hs.canvas.windowLevels.floating)
    cv:clickActivating(false)
    cv:mouseCallback(onMouse)

    cv:appendElements({
      type = "rectangle", action = "fill",
      fillColor = { red = 0, green = 0, blue = 0, alpha = 0.74 },
      roundedRectRadii = { xRadius = 10, yRadius = 10 },
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
        cv:appendElements({
          type = "text", text = e.text,
          textFont = "Menlo", textSize = M.fontSize,
          textColor = { white = 1, alpha = 1 },
          frame = { x = pad, y = cy, w = panelW - pad * 2, h = lineH },
          trackMouseUp = true, id = "go:" .. tostring(e.sid),
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
    canvases[#canvases + 1] = cv
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
  local sid = hs.spaces.activeSpaceOnScreen(scr)
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
  local start = {}
  for _, s in ipairs(hs.screen.allScreens()) do start[s] = hs.spaces.activeSpaceOnScreen(s) end
  local queue = {}
  for _, s in ipairs(hs.screen.allScreens()) do
    for i, sid in ipairs(hs.spaces.spacesForScreen(s) or {}) do
      queue[#queue + 1] = { sid = sid, name = string.format("%s Desktop %d", s:name() or "Screen", i) }
    end
  end
  local k = 0
  local function step()
    k = k + 1
    if k > #queue then
      for _, sid in pairs(start) do if sid then pcall(hs.spaces.gotoSpace, sid) end end
      hs.timer.doAfter(0.35, function()
        scanningAll = false; M.status = nil; scanActive(); draw()
      end)
      return
    end
    local item = queue[k]
    M.status = string.format("Reading %s (%d/%d)…", item.name, k, #queue)
    draw()
    pcall(hs.spaces.gotoSpace, item.sid)
    hs.timer.doAfter(M.scanDwell, function() labelSpace(snapshot(), item.sid); draw(); step() end)
  end
  step()
end

function M.saveLayout()
  if next(lastGather) == nil then return end
  local state = { savedAt = os.time(), screens = {} }
  for _, s in ipairs(hs.screen.allScreens()) do
    local key    = s:getUUID() or s:name() or "screen"
    local spaces = hs.spaces.spacesForScreen(s) or {}
    local desktops = {}
    for i, sid in ipairs(spaces) do
      local windows = {}
      for _, w in ipairs(lastGather[sid] or {}) do
        windows[#windows + 1] = { app = w.app, doc = w.doc or "", title = w.title or "" }
      end
      desktops[i] = {
        index = i, name = overrides[sid] or labelCache[sid] or "",
        manual = overrides[sid] ~= nil, windows = windows,
      }
    end
    state.screens[key] = { name = s:name() or "", desktops = desktops }
  end
  saveState(state)
end

local function restoreNames()
  local state = loadState()
  if not (state and state.screens) then return end
  for _, s in ipairs(hs.screen.allScreens()) do
    local saved = state.screens[s:getUUID() or s:name() or "screen"]
    if saved and saved.desktops then
      local spaces = hs.spaces.spacesForScreen(s) or {}
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
    local spaces = hs.spaces.spacesForScreen(s) or {}
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
  autosaveTimer = hs.timer.doEvery(M.autosaveMinutes * 60, M.saveLayout)
  hs.shutdownCallback = function() pcall(M.saveLayout) end

  hs.hotkey.bind(M.toggleHotkey.mods,  M.toggleHotkey.key,  M.toggle)
  hs.hotkey.bind(M.nameHotkey.mods,    M.nameHotkey.key,    M.nameCurrent)
  hs.hotkey.bind(M.restoreHotkey.mods, M.restoreHotkey.key, M.restoreLayout)
  hs.hotkey.bind(M.scanHotkey.mods,    M.scanHotkey.key,    M.scanAll)

  print("desktop_dashboard " .. M.version .. " loaded")
  hs.alert.show("Desktop dashboard " .. M.version .. " on")
  return M
end

function M.stop()
  if refreshTimer  then refreshTimer:stop() end
  if autosaveTimer then autosaveTimer:stop() end
  if spaceWatcher  then spaceWatcher:stop() end
  if screenWatcher then screenWatcher:stop() end
  if winWatcher    then winWatcher:unsubscribeAll() end
  for _, c in ipairs(canvases) do c:delete() end
  canvases = {}
end

return M
