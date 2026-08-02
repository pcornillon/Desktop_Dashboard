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
- **Reads** — `scanActive()` (visible Desktops), `M.scanAll()` (⌘⌃⌥s, walks all),
  event‑driven refresh via an `hs.window.filter` on create/destroy (debounced), plus a
  space watcher, screen watcher, and a periodic backstop timer.
- **Dots** — `refreshClaudeStates()` (session dot, from Terminal titles + hook files) and
  `refreshGitStates()` (git dot, local `git` status for every repo) both run async via
  `hs.task` on their own timers. `M.scanGitHub()` (⌘⌃⌥g) is the on-demand GitHub popup —
  `git ls-remote` for the shown repos, rendered in an `hs.webview`.
- **Persistence** — `M.saveLayout()` writes names + window lists to
  `~/.hammerspoon/desktop_dashboard_state.json` keyed by screen + Desktop position;
  `restoreNames()` reloads names on launch; `M.restoreLayout()` (⌘⌃⌥r) moves/opens
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

`funcs` excludes Finder/Terminal (they don't decide the subject). `ctx` collects titles
that may suggest a repo, in three tiers: `noRepoHintApps` never contribute (browsers,
chat apps, Finder), `claudeOnlyHintApps` contribute only when the title looks like a
claude session (terminals), and everything else contributes normally.

## Key decisions and why

- **Overlay, not renaming.** macOS still exposes no API for changing a Space's Mission
  Control label. `spaces-renamer` did it by injecting into the Dock, which needs SIP
  disabled — a Recovery-Mode reboot and a standing security downgrade — and is reported
  broken on Apple Silicon and macOS 14.4+. SpaceJump is the paid alternative.
  **Checked 2026-08-02, and the earlier version of this entry is now wrong:** SpaceJump
  says it puts custom names *inside Mission Control* on Apple Silicon **without** SIP
  changes, by drawing overlay windows rather than injecting into the Dock. That is vendor
  copy, not something measured here, but it is enough that "the only way is SIP-off"
  can no longer be stated. What has not changed is the part that decided this project:
  neither tool offers a scripting hook, and naming was never the point — the panel exists
  to report live session, git and window state, which no renamer does. An overlay is free,
  SIP-free and fully scriptable. Consequence, unchanged: the name shows in our panel, not
  in the Mission Control thumbnail. If a future rewrite wants names in the thumbnail,
  SpaceJump's approach (overlay windows positioned over Mission Control) is the lead
  worth following.
- **Hammerspoon as runtime.** Free, notarized, no SIP, and exposes `hs.spaces`,
  `hs.window`, `hs.canvas`, and space/window watchers — everything needed.
- **Read a Desktop only while it's active.** macOS Accessibility cannot read the windows
  of a Space you're not viewing. So detection reads the visible Space(s); ⌘⌃⌥s walks all
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
- **Ignore Finder/Terminal for the subject.** A Desktop's *subject* shouldn't be
  "Finder" or "Terminal", so neither appears in `funcs`.
- **Finder no longer contributes a repo hint either; a terminal does only when it is
  running claude.** This reverses the original rule, which fed both their titles to the
  hint on the theory that a window "sitting in a repo" names which repo the Desktop is
  for. In practice it named the wrong one: a Finder window is the folder you happen to be
  *browsing*, and a shell is wherever you last `cd`'d. Observed 2026-07-28 — a Desktop
  holding MATLAB, some `-zsh` windows and one Finder window parked in `Desktop_Dashboard`
  was labeled `Desktop_Dashboard`, while the actual work on it was MATLAB. A terminal
  running `claude` is different in kind: that is a session someone is working in, and it
  stays the strongest signal available. Hence `M.claudeOnlyHintApps` +
  `M.claudeTitleMarker`, checked against the window title.
- **A title names a location or a subject, and only the first is a repo hint.** A
  Terminal running `claude` in a repo puts the *working directory* in its title — that
  really does say which repo the Desktop is for. A browser puts a *page title* there
  (`pcornillon/Desktop_Dashboard · GitHub`), and a chat app puts a *conversation name*;
  both can contain a repo name purely as subject matter. Rule 2 cannot tell those apart
  on text alone, so `M.noRepoHintApps` draws the line by app. Members still count toward
  the subject (unlike `ignoreApps`); only their titles are withheld from `ctx`.
- **Rule 2 matches a repo name anywhere in a title, including inside a filename that is
  not in the repo.** Measured case: two windows open in TeXShop titled
  `desktop_dashboard_17.lua` / `_18.lua` — both files sitting in `~/.Trash` — kept
  relabeling their Desktop `Desktop_Dashboard`. Nothing in the title text distinguishes
  "a file belonging to this repo" from "a file whose name resembles this repo", and the
  editor was not in `docApps`, so no real path was available to check. If you tighten
  this, do it with a path (rule 1), not by pattern-matching the title harder. Until
  then, a mixed Desktop like that is what ⌘⌃⌥n manual naming is for.
- **`M.appLabels` renames the single-app case.** Rule 4 returns the bare process name
  when one app owns the Desktop, which makes `Claude` ambiguous with `claude` in a
  terminal; the override displays `Claude Chat/Cowork`. Categories can't do this — a
  category is only shown when it groups two or more apps. Note this applies *only* when
  a single app is present; a Desktop that also holds an editor and Stickies resolves to
  `Utility` by rule 4 long before `appLabels` is consulted.
- **Re-list the repo roots on a timer.** `loadRepos()` originally ran once in `start()`,
  so a repo created after Hammerspoon loaded its config was invisible to rules 2 and 3
  until the next Reload Config — the Desktop showed `—` or a bare app name however
  clearly its titles named the repo. `refreshRepos()` re-lists on an
  `M.repoRescanSeconds` TTL from `scanActive()`; ⌘⌃⌥s always reloads. A dir listing plus
  a stat per entry is negligible next to the `allWindows()` call each read already pays.
- **Compare repo paths case-insensitively.** macOS volumes are normally
  case-insensitive, so a `repoRoots` entry of `~/Git_repos` lists `~/Git_Repos` happily
  via `hs.fs.dir` but never prefix-matches the real `AXDocument` path — rule 1 fails
  silently while the repo list looks fine. Slice the repo segment off the original path
  so its true casing survives.
- **The claude dot has two colors because the signal has two states.** Claude Code puts
  an animated Braille spinner (U+2800–U+28FF) in the terminal title while computing and
  `✳` (U+2733) when not. Measured 2026-07-28 over ~750 one-second samples across three
  live sessions, including a deliberately blocked one: a session **waiting on a user
  question shows the same `✳` as a finished one**. The title encodes whether work is
  happening, never why it stopped, so "needs you" is not derivable and there is no red
  dot. Do not add one by guessing — if a marker appears in a future Claude Code release,
  verify it the same way before wiring it to `M.claudeDotColors`.
- **Red comes from hooks, because the title provably cannot carry it.** Measured
  2026-07-28: a session held at a question for 26 s showed the same `✳` as a finished
  one. So `claude-dashboard-state.sh` (registered on `UserPromptSubmit`, `Notification`,
  `Stop`, `SessionEnd`) writes one JSON file per session into `M.claudeStateDir`, and
  `readHookStates()` reads them. `Notification` is the authoritative "wants you" signal.
  Precedence in `claudeStateFor` is **working → waiting → done**: computing wins, so
  answering a question turns the dot yellow again without waiting on any hook. Hooks are
  optional — without them the dot degrades to yellow/green, never red. Do not try to
  recover red from the title; that was measured and it is not there.
- **`Notification` fires for two different things; only one is a question.** Claude Code
  also sends an idle "waiting for your input" nudge roughly a minute AFTER a turn ends.
  Taking that at face value turned every finished session red as soon as you looked away
  long enough — observed 2026-07-28: a Desktop went green on completion and then red when
  the user came back to it. `claude-dashboard-state.sh` distinguishes them **by ordering,
  not by message text**: a real question or permission prompt can only occur mid-turn, so
  the last recorded state is `working`; a nudge can only occur after `Stop`, when the last
  state is `done`. A `waiting` write arriving on top of `done` is therefore dropped.
  Message wording is not a stable contract — do not branch on it. The payload's `message`
  is recorded in the state file for diagnosis only.
- **Stale hook files age out.** A session killed without `SessionEnd` leaves its file
  behind, and a stale `waiting` would pin a Desktop red forever;
  `M.claudeHookMaxAgeHours` (12 h) bounds it. A second guard is structural: the dot only
  renders when a *live* claude terminal title exists for that repo, so a dead session's
  file cannot show anything by itself.
- **Green means "finished and unseen", not "idle".** The dot is set on the working →
  not-working edge (`noteTransitions`) and cleared when you visit that Desktop
  (`acknowledgeSids`), so it reports *a prompt that completed while you were elsewhere*
  rather than the mere absence of work. Sessions already idle at launch are never
  flagged, or every login would show a wall of green. Re-prompting clears the flag.
  Acknowledging by pressing return in the claude window is **not** possible: an empty
  return does not change the terminal title, so there is nothing to observe.
- **A live session outranks any repo name found in prose, and its task summary never
  feeds the hint.** Observed 2026-07-29: a session in `~` whose summary read "Establish
  consistent config structure for Claude projects" shares the tokens *claude* and *config*
  with the repo `claude-config`, so rule 3 relabeled that Desktop `claude-config` — and the
  real session lost its dot, since the state is keyed by cwd. Two changes: the session cwd
  is now rule 1.5, ahead of both text rules, because where a session is running is a fact
  about the Desktop while a mentioned repo name is not; and a terminal contributes only its
  cwd to `ctx`, never the summary. This is the fourth false positive from matching repo
  names inside free text (Trash filenames, browser page titles, chat conversation names,
  now task summaries) — prefer a fact over a string match every time.
- **A claude session's working directory labels its Desktop, repo or not.** Rule 3.5 in
  `detectLabel`: if a terminal on the Desktop is running claude, its cwd becomes the label
  when no repo matched. Before this, `claude` started in `~` left the Desktop reading `—`
  (Terminal is ignored for the subject, and the cwd matched no repo), so it could never
  carry a dot either — reported 2026-07-29. The dot's repo-membership test went with it:
  the key already has to match a live session's cwd, and a session in `~` is as real as one
  in a repo. Fires only when no repo matched, so nothing that previously worked changes.
- **The dot is looked up by the DETECTED label, never the displayed one.** A ⌘⌃⌥n name
  replaces what the panel shows but not what the Desktop is; session state is keyed by repo
  name, so matching on the displayed string meant every renamed Desktop silently lost its
  dot — and never cleared its green flag either, since `acknowledgeSids` had the same fault.
  Both now key off `labelCache[sid]` and use `overrides[sid]` for display only. Observed
  2026-07-29: a Desktop renamed `three-way_analysis` showed no dot while its session was
  plainly working, because the state lived under `three-way_sst_error_analysis_manuscript`.
- **Sessions mode acknowledges by focus, not by Space.** Visiting a Desktop is meaningless
  when every session shares one, so `acknowledgeFrontSession` clears the flag for whichever
  Terminal window is frontmost. Two guards matter: Terminal reports a `front window` even
  when Terminal is not the active application, so without the frontmost-app check a session
  would be marked seen while you worked in something else; and the id must match, so being
  in a different terminal window does not clear it. Reported symptom that led to this: the
  green dot survived both visiting the window and typing into it, because clicking the
  dashboard line was the only path that cleared it.
- **`acknowledgeSids` takes Space ids instead of looking them up.** `scanActive` has
  already paid for `activeSids()`, and `hs.spaces` calls are slow enough that repeating
  them on the dot's 3 s timer was a measurable cost — an early version called them from
  the task callback and it was the wrong place.
- **The dot has its own timer.** Riding the 10 s `scanActive` made it lag far enough that
  a session looked idle for seconds after it started working — the panel read "all green"
  during real work. `M.claudeDotSeconds` (3 s) drives it directly.
- **Read the dot's state from Terminal's AppleScript, not Accessibility.** Terminal
  reports titles for windows on ALL Spaces, so the dot stays correct for Desktops you are
  not viewing — the one place this tool escapes the "only the active Space is readable"
  constraint. Matching the title's cwd component against the Desktop's repo label avoids
  needing any window-to-Space mapping.
- **That AppleScript call must stay asynchronous.** It runs through `hs.task`. Measured:
  the same query issued synchronously blocked long enough to time out Hammerspoon's own
  IPC — precisely the class of stall that `docApps` and the single-snapshot rule exist to
  prevent. Redraw only when a dot actually changed; `draw()` rebuilds every canvas.
- **The git dot is local-only; the network half is a separate keypress.** The dot
  (`refreshGitStates` → `gitStateFor`, second in each entry's `dots` list) answers one
  offline question: does GitHub have everything on this machine? RED = dirty tree OR
  unpushed commits, GREEN = clean and pushed — `git status --porcelain` plus
  `rev-list @{u}..HEAD`, no network. "Has GitHub itself changed?" is deliberately NOT on
  the dot: it can't be known without contacting GitHub, and the answer goes stale the
  moment anyone pushes — a dot must not assert what it hasn't checked. So GitHub state
  lives in the ⌘⌃⌥g popup (`M.scanGitHub`), which is the only thing here that touches the
  network, and only when pressed, and only for the repos currently shown (`displayedRepos`).
- **⌘⌃⌥g uses `git ls-remote`, not `fetch`.** ls-remote reads the remote head SHA without
  downloading objects or updating any local ref, so it never changes what `git status`
  shows in the user's own terminal — the light touch they asked for. Cost: it gives a
  yes/no "GitHub differs", not an exact behind-count. Classification compares the remote
  SHA to `HEAD`: equal → up to date; remote is an ancestor of HEAD → unpushed only; else →
  "GitHub ahead" (which also covers a true divergence, where the remote SHA isn't even in
  the local object store). `GIT_TERMINAL_PROMPT=0` + an `M.githubTimeout` watchdog mean a
  remote that needs credentials fails fast instead of hanging the query.
- **Clicking "GitHub ahead" pulls, and `--ff-only` is the whole design.** This is the only
  thing in the tool that WRITES to one of your repositories, so it is the one place that
  has to be conservative instead of clever. The trap is that `behind` is not only "you are
  behind": as the ls-remote note above says, it also covers a true DIVERGENCE, where the
  remote SHA isn't even in the local object store. A plain `git pull` answers divergence
  with a merge commit — a rewrite of your history from a single click, in a window with
  nowhere to resolve a conflict. `--ff-only` takes the easy case (someone pushed from your
  other machine, which is what this button is for) and refuses everything else out loud.
  Verified 2026-08-01 on a throwaway repo: behind-only fast-forwards; diverged returns
  `fatal: Not possible to fast-forward, aborting.` with HEAD unmoved. `M.pullFFOnly =
  false` allows the merge for anyone who wants it.
- **The pull refuses while a claude session is WORKING in that repo, not merely open.**
  Changing files under a session that is mid-task destroys nothing, but it leaves that
  session reasoning about files that no longer say what it read. "Working" is the real
  hazard and is what blocks. Blocking on any live session was considered and rejected:
  on the machine this was built for a session is open in most repos most of the time, so
  that rule would have refused nearly every pull and the button would be decoration.
  `M.pullBlockOnClaude = "any"` for anyone who wants it strict. The test is `claudeStates`
  — the live read of terminal titles — and NOT `claudeStateFor`, which returns nil once
  you have acknowledged a session and would therefore call a busy repo clear.
- **The open-file check exists because that is the only way this button can lose work, and
  it isn't git's fault.** Git protects what it knows about: verified 2026-08-01 that an
  uncommitted edit to an unrelated file survives a pull untouched, and an uncommitted edit
  to a file the pull wants results in `Please commit your changes or stash them before you
  merge. Aborting.` What git cannot see is an editor holding an old copy in memory — pull
  new text, then save from that editor, and the incoming change is gone with no git
  operation to blame. This panel already reads the open document of every editor in
  `M.docApps` for repo detection, so it is the one component that CAN see it.
  - **Learn what would change without changing anything:** `git fetch` (which the pull
    would do anyway, and which only moves the `origin/…` tracking ref) then
    `git diff --name-only HEAD..@{u}`. Those paths are matched against the open documents.
  - **Abort, don't warn.** A warning still leaves the stale buffer sitting in front of
    you; the failure mode is a save you make a minute later, long after the warning is
    gone. Closing the file and clicking again costs seconds.
  - **A clean check means "nothing KNOWN to be open", never "nothing is open."** It sees
    only `M.docApps` editors, only on Desktops read since launch. Never let this guard
    imply a guarantee, in the UI or in the docs.
  - **TeXShop is knowingly outside the check, and was left that way (2026-08-01).** It is
    a real editor for this user's repos, so the gap is real — but `docApps` is an
    allowlist precisely because asking some apps for `AXDocument` can stall the panel for
    minutes, and TeXShop has never been measured. Adding it to close this gap would trade
    a documented blind spot for a possible hang in the read path, which is the one thing
    this file has spent the most effort protecting. Documented in the README's "What to be
    careful about" instead. If it is ever added, measure the `AXDocument` read first.
  - The precheck talks to the network too, so it carries the same watchdog as the pull.
    Without one a wedged fetch leaves `pullPrecheckTask` set and every later click reports
    "a pull is already running".
- **The confirmation comes AFTER the checks, so it can name what will change.** "Are you
  sure?" is a speed bump you learn to click through; "3 files will change: notes.md,
  run.lua, extra.txt" is a decision. The file list is already in hand from the precheck, so
  the informative version costs nothing. It also means the prompt only ever appears for a
  pull that is actually going to happen — the blocked cases say why instead of asking.
- **The prompt lives INSIDE the popup, not in a system dialog.** `hs.dialog.blockAlert`
  would be less code, but an alert raised by Hammerspoon while another app is frontmost can
  open BEHIND that app — the most likely explanation for the "⌘⌃⌥N does nothing" report on
  2026-07-30. The popup is already frontmost under the cursor, so the two links go in its
  status area and post back through the same `usercontent` bridge as the pull link. It
  also avoids a modal blocking the Lua state while a task callback is mid-flight.
- **Git's refusals are shown verbatim, not second-guessed.** A dirty file in the way, or a
  history that can't fast-forward, is exactly what you want to be TOLD rather than have
  handled for you — and git's messages are better than any pre-flight check this tool
  would write. So there is no dirty-tree guard; git decides and the popup repeats it.
- **There is no push button, deliberately.** A fast-forward pull cannot lose work. A push
  can. The asymmetry is the whole reason one is offered and the other isn't.
- **A click reaches Lua through an `hs.webview.usercontent` controller.** The page posts to
  `window.webkit.messageHandlers.dashboard`; the controller is built ONCE and reused,
  because `showGitHubPopup` deletes and rebuilds the webview on every ⌘⌃⌥g while the
  controller outlives it. The pull itself runs through `hs.task` with its own watchdog
  (`M.pullTimeout`, longer than the query's — a pull fetches objects), for the same reason
  everything else here is async: nothing that touches the network may block the panel.
- **The success line is timed to be read.** A successful pull re-runs the whole query so
  every row is true again, not just the clicked one — but that rebuilds the popup and takes
  the result with it. Measured at 1.2 s the message was gone before it could be read;
  2.5 s. On failure there is no rescan, so git's message stays until dismissed.
- **A pull does update `origin/main`**, unlike the query. `git pull --ff-only` fetches even
  when it then refuses to move your branch. That is normal and harmless, but it means the
  "your local refs untouched" promise belongs to the ⌘⌃⌥g *query*, not to the button.
- **No "last push" time — git doesn't record one.** The popup shows the last *commit* time
  (`log -1 %cd`), which is real; a push timestamp would have to be invented or fetched, so
  it isn't shown.
- **The active-Desktop marker is a caret AND a color, and the two markers are the same
  width.** The caret prefix was `"▸ "` against `"   "` for every other line — two cells
  against three, so the Desktop you were standing on was the one line that didn't line up
  with the rest. Measured in Menlo 13: `"▸ "` is 15.65 px, `"   "` is 23.48, and `▸` alone
  is exactly one cell (7.83), so `"▸  "` matches. Do not assume a glyph is one cell wide
  because the font is monospaced — measure it, as `M.activeMarker`'s comment says. The
  number also goes magenta (`M.activeColor`), which is the stronger cue in a list of a
  dozen lines. Both are kept rather than either: color alone excludes anyone who can't
  separate magenta from white, and this panel already spends four colors on the dots.
  Magenta is deliberately none of them. Only the marker and `Desktop N` are colored — the
  label stays white so a repo name reads identically wherever you happen to be.
- **A label that names apps is replaced by those apps' icons; a label that names work is
  not.** `detectLabel` returns the KIND of evidence behind the label (`repo` / `cwd` /
  `app` / `apps` / `none`). `apps` (a bucket — `Utility`, `Communication`) and `app` (one
  app's own name — `MacDown`) both draw icons, because in both cases the word is only
  standing in for the apps themselves. `repo` and `cwd` keep their text: they name the
  work, which no icon can. Icons for the single-app case were withheld at first, on the
  grounds that `MacDown` already says something — but that was written before the hover
  tip existed. Once pointing at an icon gives the name back, dropping the word costs
  nothing and the panel stops treating "one app" and "three apps" as different kinds of
  thing (asked for and chosen 2026-07-30). Consequence worth knowing: `M.appLabels`
  (`Claude` → `Claude Chat/Cowork`) now shows only when icons are off or unavailable, so
  that disambiguation is carried by the icon and the tip instead.
  `M.showAppIcons = false` restores the words. Icons need a real read of
  the Desktop (bundle ids come from the window snapshot), so a Desktop whose name was
  restored from disk shows its old text until it is next scanned — the same constraint
  every other live detail has.
- **The icon row is placed by measuring the styled line, not by counting characters.**
  The line mixes two font sizes (the half-space between the dots), so a character count
  puts the icons a few px off, and the error changes with the dot states — the row would
  visibly shift as sessions started and stopped.
  `hs.drawing.getTextDrawingSize(styledtext)` measures the object actually drawn. Width
  is still budgeted in characters (`iconTextPad`) because that is the unit the panel
  sizes itself in. Dragging from an icon moves the panel exactly as from the text; each
  icon carries its OWN element id (`icon:<sid>:<wid>`) rather than the line's, because a
  click on an icon means something more specific than a click on the line — see below.
- **Some apps are invisible to Accessibility, so CoreGraphics is a second window source.**
  Measured 2026-07-30: the Claude desktop app returns **nil for every AX attribute** — no
  role, no `AXWindows`, nothing — and ChatGPT Classic likewise exposes no window. A Desktop
  holding both therefore read as empty (`—`) however many windows were on it, and the
  natural assumption (reported as such) was that some rule of ours was hiding them. It was
  not: `noRepoHintApps` only withholds an app's *title* from repo matching, and the app
  still counts toward the subject — if a window can be seen at all. `snapshot()` now also
  indexes `hs.window.list(true)` (CoreGraphics), and `readSpaceFrom` falls back to it for
  any window id Accessibility couldn't resolve. Same discipline as `allWindows()`: ~14 ms,
  ONCE per read pass, never per window.
  - **Layer 0 only.** CoreGraphics lists everything on screen — menu-bar extras, Spotlight,
    Control Center, the Dock, us — all at layer 24/25. Layer 0 is an ordinary application
    window, and the filter is what makes the fallback usable rather than noise.
  - **It is on-screen only**, so it resolves nothing for a Space you aren't viewing. That
    costs nothing: the active Space is the only one macOS lets us read anyway.
  - **These windows contribute an ICON and nothing else.** CoreGraphics gives an owner and
    a pid — no title, no `AXDocument` — so they can never touch repo detection, and there
    is no window object to raise. Clicking one activates the *application* instead, which
    is why an icon id can be `icon:<space>:p<pid>` as well as `icon:<space>:<windowid>`.
- **The icon row is saved to disk with the name, because it costs a bundle id.** Names have
  always survived a reload; icons did not, so every reload (and every `git pull` of this
  file) left a panel of bare words until ⌘⌃⌥S walked all thirteen Desktops. That was never
  a platform limit — an icon needs only a bundle id, no window read at all — it was simply
  the half of `saveLayout` that was missing. Reported 2026-08-01 as "why do I have to press
  ⌘⌃⌥s after every change"; the honest answer was that I hadn't saved them.
  - **Window ids are deliberately NOT saved.** They are reused after a reboot, so a stale
    one could raise a window that has nothing to do with the icon you clicked — a wrong
    action is worse than a missing one. A restored icon still draws and still names itself
    on hover; it just has no window behind it, so it gets an `icon:<sid>:r<n>` id and a
    click on it only goes to the Desktop. Full behaviour returns the moment that Desktop
    is read.
  - **A restored row can show something that is gone.** Observed immediately: a
    `Problem Reporter` (crash dialog) window that had been on a Desktop was still in its
    saved row afterwards. This is the same staleness the restored NAME has always had, and
    the fix is the same — read the Desktop. What makes it honest rather than misleading is
    the hint line below.
- **A count of unread Desktops sits above the legend, and clicking it reads them.** macOS
  only lets us read the Desktop you are looking at, so after a reload the rest are last
  session's picture until visited. The panel now says so — "10 Desktops not read yet ·
  click here or press ⌘⌃⌥s to read them" — counts itself down as Desktops are read, and
  disappears at zero. It names BOTH ways of acting because both exist: the line is a click
  target and the hotkey does the same thing. An earlier draft trailed the hotkey in a
  parenthesis, which read as a footnote rather than as something to do (reported
  2026-08-01). It is computed from the entries `draw()` has already built, so it costs no extra
  `hs.spaces` calls, and it hides while a scan is running because `M.status` is saying the
  same thing more precisely. Asking rather than scanning automatically is deliberate: a
  ⌘⌃⌥S walk takes over both displays for ~25 s, which is not something to do to someone
  unprompted every time they reload.
- **A line is a NAME and an ICON ROW, and they answer different questions.** The name says
  what the Desktop is *for*; the icons say what is *on* it. Because they are independent,
  ⌘⌃⌥N replaces the name and leaves the icons alone — renaming a Desktop cannot change
  which apps are sitting on it, and the old behaviour (an override suppressed the icons
  entirely) threw away a fact to honour a label. The name is empty only when the icons are
  standing in for a word that itself named apps (`Utility`, `MacDown`); a repo or session
  directory keeps its text and the icons follow it (asked for 2026-07-30).
- **Finder and terminals get icons, always last.** They are in `ignoreApps` because a
  Desktop is never *about* Finder — that is a statement about the SUBJECT, not about
  whether they are worth showing. "There is a Finder and two terminals here" is real
  information, so they are collected separately (`extras`) and appended after the subject
  apps, which keeps the row reading subject-first. Hammerspoon stays out: it is this
  panel. The terminal list is taken from `M.claudeOnlyHintApps` rather than duplicated, so
  adding your terminal in one place is enough.
- **A terminal icon is dropped from a Desktop named after a repo or a session directory.**
  That name came from the terminal's own working directory, so its icon would say the
  same thing twice — and the icons exist to add what the name can't. Finder is never
  redundant that way, so it stays. The test is the detection KIND (`repo`/`cwd`), not the
  displayed text, so a ⌘⌃⌥N rename doesn't quietly bring the terminal back.
- **Trailing icons never count toward the "enough icons to drop the word" threshold.**
  `list.lead` records how many entries are subject apps and only those are counted against
  `list.min`. Otherwise a Finder window could be the second icon that lets a three-app
  Desktop lose the word `Utility` while one of its apps had no resolvable icon — the exact
  misrepresentation the threshold exists to prevent.
- **Resizing scales `M.fontSize`, because everything else is derived from it.** Line
  height, character width, icon edge, legend size and the width bounds all come from it,
  so one number resizes the panel coherently. There is no free aspect ratio to preserve —
  the panel's shape follows its content — so the corner drag is projected onto the
  diagonal (`((startW+dx) + (startH+dy)) / (startW+startH)`) and turned into a size. Both
  axes contribute, so dragging out along either one grows it. Integer sizes mean ~20
  redraws across a full drag rather than one per pixel, and `setFontSize` skips its file
  write mid-drag because `endDrag` writes once on release.
  - **The grip is at the corner OPPOSITE the panel's anchor.** The panel is positioned by
    its top-left, so growing it from the bottom-right keeps the corner you're holding the
    one that moves.
  - **`draw()` replaces every canvas, including the one being dragged**, so the resize
    branch re-points `drag.cv` at the successor by screen UUID after each step. Without
    that the next move acts on a deleted object.
  - This replaced a pair of −/+ buttons (v39). They worked, but one point per click across
    a useful range is tedious — which is the objection to any stepper, and was the reported
    complaint. Their width also had to be reserved out of the panel's top-right corner; the
    grip sits past the end of the legend and costs nothing.
- **⌘⌃⌥N renames the FOCUSED Space, not the one under the pointer.** They were the same
  thing until the panel could be dragged across a display boundary. With it straddling two
  screens, resting the pointer over the panel meant `hs.mouse.getCurrentScreen()` returned
  the *other* display, so ⌘⌃⌥N silently offered to rename a Desktop you weren't looking at.
  `hs.spaces.focusedSpace()` is where you are working; the mouse is the fallback.
- **`minWidth`/`maxWidth` are px at `M.baseFontSize` and scale from there.** A flat px cap
  stops meaning anything once the panel can be zoomed: at 20 pt a long repo name plus its
  icon row needs ~990 px, so the fixed 760 cap silently cut the icons off the right-hand
  end — measured 2026-07-30, and visible only because the icons made the truncation
  obvious where clipped text had been easy to miss.
- **An hs.canvas IMAGE element never reports mouseEnter/mouseExit, so every icon carries
  a transparent rectangle.** Measured 2026-07-30 with identical frames and identical
  tracking flags: an `image` element reports `mouseDown`/`mouseUp` but neither enter nor
  exit, while a `rectangle` reports all four — and a rectangle with `alpha = 0` still
  hit-tests. So all mouse handling for an icon lives on an invisible rectangle laid over
  it, and the image element is left untracked. If hover ever stops working, check this
  first; it is not something the documentation states.
- **Naming an icon beats enlarging it.** The icons replace a label for Desktops that are
  a mix of apps, which is exactly where the less-used apps live — and a bigger version of
  an icon you didn't recognise is still an icon you don't recognise. The tip gives the app
  name and, on a second dimmed line, the title of the window a click would raise, so you
  can tell two windows of the same app apart before committing to the switch.
- **The tip is re-placed by `draw()`, not left to the next mouseEnter.** `draw()` deletes
  and rebuilds every canvas, which orphans a visible tip on a dead element — and no fresh
  mouseEnter arrives while the pointer sits still, so the tip would simply vanish every
  time a dot changed (a 3 s timer). `refreshTip()` runs at the end of `draw()` and re-places
  it if the same icon still exists. A *pending* tip timer needs nothing: when it fires it
  reads the new canvases anyway.
- **A poll guards against the mouseExit that never comes.** Deleting a canvas under the
  pointer can swallow the exit, which would pin a tip on screen permanently. `tipWatch`
  checks every 0.4 s that the pointer is still inside the hovered icon's rect — and runs
  only while a tip is actually showing, so it costs nothing the rest of the time.
- **Clicking an icon raises that window; clicking the line does not.** Arriving on a
  Desktop should normally leave it as you left it, so the line stays "take me there".
  Picking an icon is the only way to say *which* window you want, which is what makes the
  icon row worth pointing at. The window is re-resolved by id at click time
  (`hs.window.get`) rather than reusing the object captured during the read: that object
  may be minutes old and its app long gone, and only once the Space is active is the
  lookup reliable. `hs.window.get` is the ~40 ms call banned from the read path — one
  click can afford it, a per-window loop cannot. The raise waits `M.iconFocusDelay` for
  the Space switch to finish; firing into a half-finished switch does nothing.
- **How many icons a row needs depends on what it replaces (`list.min`).** A single-app
  Desktop draws its one icon — the word it replaces is that app's name, which the tip
  gives straight back. A MIXED Desktop still needs two: one icon there would assert the
  other apps aren't present, and `Utility` is at least honest about being a summary. So
  the threshold is recorded per Desktop when it is read, not hardcoded in the renderer.
  Icons are memoized per bundle id (`false` records "has no icon") since `draw()` rebuilds
  every canvas and app icons do not change while Hammerspoon runs.
- **An empty dot slot goes gray whenever the line shows any live dot.** The two dots are
  told apart only by position — claude first, git second — and position is unreadable
  when one column is blank: a lone green git dot in slot 2 reads as a claude dot saying
  "finished". The gray placeholder holds the column open and names the other by
  elimination. It is deliberately NOT unconditional: a gray pair on every Desktop with
  nothing to report would be two columns of noise, so a line with no live dot keeps blank
  spacers. The rule is symmetric, so a session in `~` (claude dot, no git dot) gets the
  same treatment in reverse.
- **Both dots share one styledtext element.** An entry now carries an ordered `dots` list
  ({ch,color}, claude then git); `draw()` builds `prefix .. dot1 .. dot2 .. suffix` as a
  single `hs.styledtext`, so the click target and sizing (`e.text`) are unchanged and a
  blank (uncolored) dot is just a spacer that keeps the arrows aligned.
- **Single app → app name; shared subject → category.** A category should only appear
  when it's actually grouping more than one app. `Mail` alone is `Mail`; `Mail` + `Slack`
  is `Communication`.
- **Manual names are overrides.** ⌘⌃⌥n sets a name that wins over auto‑detection; blank
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

- **Keep a live reference to any `hs.timer.doAfter` whose callback must run.** A pending
  timer with nothing referencing it can be garbage-collected before it fires — no error,
  no log, it just never happens. The ⌘⌃⌥s walk chains one `doAfter` per Desktop, and
  with no reference held it died at a different Desktop every run (observed: #1, #5, #6,
  #9). It surfaced only once the claude dot began allocating on a 3 s timer, which raised
  GC pressure enough to collect the pending step mid-walk. `scanTimer` holds it now.
  Symptom to recognise: `M.status` frozen part-way, `scanningAll` stuck true, console
  completely clean.
- **`hs.spaces` queries throw rather than return nil.** `windowsForSpace`,
  `spacesForScreen` and `activeSpaceOnScreen` reach through the Dock's accessibility
  element and raise when that lookup transiently fails ("Unable to fetch
  NSRunningApplication for pid: …"). `x or {}` cannot catch it. Use
  `safeWindowsForSpace` / `safeSpacesForScreen` / `safeActiveSpace`. A failed read
  returns nil and callers keep the previous label — blanking a Desktop to `—` because
  one read glitched is worse than a stale name.

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
Config, confirm the `vNN loaded` line, press ⌘⌃⌥s, then open/close a repo file and a
non‑repo app on a Desktop and confirm the label updates within ~1 s. If a Desktop stalls,
the per‑app / per‑window timing probes in the project history are the way to pinpoint the
slow call — the culprit is almost always a slow Accessibility read of one app.
