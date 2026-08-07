# DECISIONS.md — Desktop Dashboard

Numbered, appended, never renumbered. Cite them by number from `TASKS.md`,
`STATUS.md`, `LOG.md` and from comments in `desktop_dashboard.lua`.

**Every entry here was lifted verbatim-in-substance out of `CLAUDE.md`'s "Key decisions
and why" section on 2026-08-03**, when this repo was migrated onto the project spine
(`claude-config` Task #11 / #19). They had accumulated there for want of a
`DECISIONS.md`. **The measurements are the point** — the millisecond costs, the sample
counts, the observation dates — and they are carried across unchanged. Where a date
appears it is the date the thing was measured or observed, not the date it was written
down here.

Nothing in this file is new. No decision was added, dropped, softened or re-litigated
during the migration.

---

## Platform and runtime

### D1. Draw an overlay; do not try to rename the Space
- **Decision:** draw an always-on `hs.canvas` panel listing the Desktops, rather than
  changing a Space's Mission Control label.
- **Why:** macOS exposes no supported API for renaming a Space. `spaces-renamer` did it
  by injecting into the Dock, which needs SIP disabled — a Recovery-Mode reboot and a
  standing security downgrade — and is reported broken on Apple Silicon and macOS 14.4+.
  **Re-checked 2026-08-02 and the original form of this entry is now wrong:** SpaceJump
  claims to put custom names *inside* Mission Control on Apple Silicon **without** SIP
  changes, by drawing overlay windows rather than injecting. That is vendor copy, not
  measured here, but it is enough that "the only way is SIP-off" can no longer be
  stated. What has not changed is the part that actually decided this project: neither
  tool offers a scripting hook, and **naming was never the point** — the panel exists to
  report live session, git and window state, which no renamer does.
- **Where:** the whole of `draw()`; `README.md` "Why an overlay".
- **Consequence:** the name shows in our panel, not in the Mission Control thumbnail.
- **Live tension:** if a future rewrite does want names in the thumbnail, SpaceJump's
  approach — overlay windows positioned over Mission Control — is the lead worth
  following.

### D2. Hammerspoon as the runtime
- **Decision:** build on Hammerspoon.
- **Why:** free, notarized, needs no SIP change, and exposes `hs.spaces`, `hs.window`,
  `hs.canvas` and both space and window watchers — everything required.
- **Where:** everything.

### D3. Read a Desktop only while it is active; never reintroduce passive reads
- **Decision:** detection reads only the visible Space(s); ⌘⌃⌥s walks all Spaces to fill
  in the rest.
- **Why:** macOS Accessibility cannot read the windows of a Space you are not viewing.
  **Passive "read every Space without visiting" was tried and does not work without
  SIP-off.**
- **Where:** `scanActive()`, `M.scanAll()`.
- **Do not re-attempt.** This is a negative result, not an unexplored option.

### D4. One `allWindows()` snapshot per read; never `hs.window.get()` per id
- **Decision:** `snapshot()` calls `hs.window.allWindows()` **once** and indexes by
  window id; per-Desktop reads are hash lookups.
- **Why:** **THE performance fix.** `hs.window.get(id)` rebuilds the entire window list
  on every call — **~40 ms each, measured** — so per-window calls multiplied into
  multi-minute freezes.
- **Where:** `snapshot()`, `readSpaceFrom()`.
- **Constraint on future work:** if you touch the read path, keep it to one enumeration
  per read. The one sanctioned exception is D56 (a single click can afford it).

### D5. Only ask `docApps` for a file path
- **Decision:** an allowlist (`M.docApps`) restricts the `AXDocument` read to real
  editors — MacDown, VS Code, CLion, Preview and the like. Everything else is labeled by
  name only.
- **Why:** reading `AXDocument` from Electron/Office/Java apps (Slack, OneNote, Teams,
  MATLAB, …) **can stall for minutes**.
- **Where:** `M.docApps`, rule 1 of `detectLabel`.
- **Do not add slow apps to `docApps`.** See D30 for the cost this allowlist imposes on
  the pull precheck. TeXShop was left off it for exactly this reason until **D79** measured
  the read (0.10–0.23 ms) and let it in — which is the procedure, not an exception to it.

---

## Label detection

### D6. Finder and Terminal never decide a Desktop's subject
- **Decision:** neither appears in `funcs`.
- **Why:** a Desktop's *subject* is never "Finder" or "Terminal".
- **Where:** `M.ignoreApps`, `detectLabel`.

### D7. Finder contributes no repo hint; a terminal does only while running claude
- **Decision:** reverse the original rule, which fed both their titles to the repo hint.
- **Why:** the original theory was that a window "sitting in a repo" names which repo the
  Desktop is for. In practice it named the **wrong** one: a Finder window is the folder
  you happen to be *browsing*, and a shell is wherever you last `cd`'d. **Observed
  2026-07-28** — a Desktop holding MATLAB, some `-zsh` windows and one Finder window
  parked in `Desktop_Dashboard` was labeled `Desktop_Dashboard`, while the actual work on
  it was MATLAB. A terminal running `claude` is different in kind: that is a session
  someone is working in, and it remains the strongest signal available.
- **Where:** `M.claudeOnlyHintApps`, `M.claudeTitleMarker`, checked against the window
  title.

### D8. A title names a location or a subject, and only the first is a repo hint
- **Decision:** `M.noRepoHintApps` withholds an app's title from `ctx` by app, not by
  text.
- **Why:** a Terminal running `claude` puts the *working directory* in its title — that
  really does say which repo the Desktop is for. A browser puts a *page title*
  (`pcornillon/Desktop_Dashboard · GitHub`) and a chat app puts a *conversation name*;
  both can contain a repo name purely as subject matter. Rule 2 cannot tell those apart
  on text alone, so the line is drawn by app.
- **Where:** `M.noRepoHintApps`.
- **Note:** members still count toward the subject, unlike `M.ignoreApps`. Only their
  titles are withheld.

### D9. Rule 2 matches a repo name anywhere in a title — accepted, not fixed
- **Decision:** accept that rule 2 will match a repo name inside a filename that is not
  in the repo. Do not tighten it by pattern-matching the title harder.
- **Why:** **measured case** — two windows open in TeXShop titled
  `desktop_dashboard_17.lua` / `_18.lua`, **both files sitting in `~/.Trash`**, kept
  relabeling their Desktop `Desktop_Dashboard`. Nothing in the title text distinguishes
  "a file belonging to this repo" from "a file whose name resembles this repo", and the
  editor was not in `docApps`, so no real path was available to check.
- **Where:** rule 2 of `detectLabel`.
- **If you tighten this, do it with a path (rule 1), not with a better pattern.** Until
  then, a mixed Desktop like that is what ⌘⌃⌥n manual naming is for.

### D10. `M.appLabels` renames the single-app case only
- **Decision:** an override table that renames the bare process name when one app owns
  the Desktop — `Claude` → `Claude Chat/Cowork`.
- **Why:** rule 4 returns the bare process name, which makes `Claude` ambiguous with
  `claude` in a terminal. Categories cannot do this: a category is only shown when it
  groups two or more apps.
- **Where:** `M.appLabels`.
- **Scope, easily misread:** it applies *only* when a single app is present. A Desktop
  that also holds an editor and Stickies resolves to `Utility` by rule 4 long before
  `appLabels` is consulted. See also D40 — with icons on, `appLabels` shows only when
  icons are off or unavailable.

### D11. Re-list the repo roots on a timer
- **Decision:** `refreshRepos()` re-lists on an `M.repoRescanSeconds` TTL from
  `scanActive()`; ⌘⌃⌥s always reloads.
- **Why:** `loadRepos()` originally ran once in `start()`, so a repo created after
  Hammerspoon loaded its config was invisible to rules 2 and 3 until the next Reload
  Config — the Desktop showed `—` or a bare app name however clearly its titles named the
  repo.
- **Cost, and why it is acceptable:** a directory listing plus a stat per entry is
  negligible next to the `allWindows()` call each read already pays (D4).

### D12. Compare repo paths case-insensitively
- **Decision:** compare case-insensitively, and slice the repo segment off the
  **original** path so its true casing survives.
- **Why:** macOS volumes are normally case-insensitive, so a `repoRoots` entry of
  `~/Git_repos` lists `~/Git_Repos` happily via `hs.fs.dir` but **never prefix-matches
  the real `AXDocument` path** — rule 1 fails silently while the repo list looks fine.
- **Where:** rule 1 of `detectLabel`.

### D13. A live session outranks any repo name found in prose, and its task summary never feeds the hint
- **Decision:** the session cwd becomes **rule 1.5**, ahead of both text rules; a
  terminal contributes only its cwd to `ctx`, never its task summary.
- **Why:** **observed 2026-07-29** — a session in `~` whose summary read "Establish
  consistent config structure for Claude projects" shares the tokens *claude* and
  *config* with the repo `claude-config`, so rule 3 relabeled that Desktop
  `claude-config`, **and the real session lost its dot**, since the state is keyed by
  cwd. Where a session is running is a *fact* about the Desktop; a mentioned repo name is
  not.
- **This was the fourth false positive from matching repo names inside free text** —
  Trash filenames (D9), browser page titles, chat conversation names, now task summaries.
  **Prefer a fact over a string match every time.**

### D14. A claude session's working directory labels its Desktop, repo or not
- **Decision:** rule 3.5 — if a terminal on the Desktop is running claude, its cwd
  becomes the label when no repo matched.
- **Why:** before this, `claude` started in `~` left the Desktop reading `—` (Terminal is
  ignored for the subject per D6, and the cwd matched no repo), so it could never carry a
  dot either. **Reported 2026-07-29.** The dot's repo-membership test went with it: the
  key already has to match a live session's cwd, and a session in `~` is as real as one
  in a repo.
- **Safe by construction:** it fires only when no repo matched, so nothing that
  previously worked changes.

### D15. Single app → the app's name; a shared subject → the category
- **Decision:** one app owning a Desktop yields that app's own name; two or more apps
  sharing a subject yield the subject; two or more subjects yield `Utility`.
- **Why:** a category should only appear when it is actually grouping more than one app.
  `Mail` alone is `Mail`; `Mail` + `Slack` is `Communication`.
- **Where:** rule 4 of `detectLabel`, `M.categories` / `M.categoryPatterns`.

### D16. Manual names are overrides, kept two ways
- **Decision:** ⌘⌃⌥n sets a name that wins over auto-detection; blank clears it. Kept by
  **Space ID** in-session and by **screen + position** on disk.
- **Why:** the two keys answer two different failure modes — reordering Desktops should
  move names with their Space, and Space IDs do not survive a reboot.
- **Where:** `overrides`, `M.saveLayout()`, `restoreNames()`.

---

## The claude session dot

### D17. The claude dot has two colours because the title carries only two states
- **Decision:** yellow (working) and green (finished-and-unseen). **There is no red dot
  derived from the title.**
- **Why:** Claude Code puts an animated Braille spinner (U+2800–U+28FF) in the terminal
  title while computing and `✳` (U+2733) when not. **Measured 2026-07-28 over ~750
  one-second samples across three live sessions, including a deliberately blocked one: a
  session waiting on a user question shows the same `✳` as a finished one.** The title
  encodes whether work is happening, never why it stopped, so "needs you" is not
  derivable from it.
- **Do not add a red dot by guessing.** If a marker appears in a future Claude Code
  release, verify it the same way before wiring it to `M.claudeDotColors`.

### D18. Red comes from hooks, because the title provably cannot carry it
- **Decision:** `claude-dashboard-state.sh` — registered on `UserPromptSubmit`,
  `Notification`, `Stop` and `SessionEnd` — writes one JSON file per session into
  `M.claudeStateDir`, and `readHookStates()` reads them. `Notification` is the
  authoritative "wants you" signal.
- **Why:** the measurement in D17. **Re-measured 2026-07-28: a session held at a question
  for 26 s showed the same `✳` as a finished one.**
- **Precedence in `claudeStateFor` is working → waiting → done.** Computing wins, so
  answering a question turns the dot yellow again without waiting on any hook.
- **Hooks are optional** — without them the dot degrades to yellow/green, never red.
- **Do not try to recover red from the title.** That was measured and it is not there.

### D19. Tell the two kinds of `Notification` apart by ordering, never by message text
- **Decision:** a `waiting` write arriving on top of `done` is **dropped**.
- **Why:** Claude Code sends `Notification` for two different things — a real question or
  permission prompt, and an idle "waiting for your input" nudge roughly a minute **after**
  a turn ends. Taking the nudge at face value turned every finished session red as soon as
  you looked away long enough: **observed 2026-07-28**, a Desktop went green on completion
  and then red when the user came back to it. A real question can only occur mid-turn, so
  the last recorded state is `working`; a nudge can only occur after `Stop`, when the last
  state is `done`. Ordering separates them; **message wording is not a stable contract, so
  do not branch on it.**
- **Where:** `claude-dashboard-state.sh`. The payload's `message` is recorded in the state
  file **for diagnosis only**.

### D20. Stale hook files age out, and a second guard is structural
- **Decision:** `M.claudeHookMaxAgeHours` (12 h) bounds a state file's life; separately,
  the dot renders only when a *live* claude terminal title exists for that repo.
- **Why:** a session killed without `SessionEnd` leaves its file behind, and a stale
  `waiting` would pin a Desktop red forever. The structural guard means a dead session's
  file cannot show anything by itself.

### D21. Green means "finished and unseen", not "idle"
- **Decision:** the dot is set on the working → not-working **edge**
  (`noteTransitions`) and cleared when you visit that Desktop (`acknowledgeSids`).
  Sessions already idle at launch are never flagged.
- **Why:** it should report *a prompt that completed while you were elsewhere*, not the
  mere absence of work — otherwise every login would show a wall of green.
- **Acknowledging by pressing return in the claude window is not possible:** an empty
  return does not change the terminal title, so there is nothing to observe.

### D22. The dot is looked up by the DETECTED label, never the displayed one
- **Decision:** `labelCache[sid]` keys the state; `overrides[sid]` is display only.
- **Why:** a ⌘⌃⌥n name replaces what the panel shows but not what the Desktop *is*, and
  session state is keyed by repo name — so matching on the displayed string meant every
  renamed Desktop **silently lost its dot**, and never cleared its green flag either,
  since `acknowledgeSids` had the same fault. **Observed 2026-07-29:** a Desktop renamed
  `three-way_analysis` showed no dot while its session was plainly working, because the
  state lived under `three-way_sst_error_analysis_manuscript`.

### D23. Sessions mode acknowledges by focus, not by Space
- **Decision:** `acknowledgeFrontSession` clears the flag for whichever Terminal window
  is frontmost.
- **Why:** visiting a Desktop is meaningless when every session shares one. **Reported
  symptom:** the green dot survived both visiting the window and typing into it, because
  clicking the dashboard line was the only path that cleared it.
- **Two guards matter:** Terminal reports a `front window` even when Terminal is **not**
  the active application, so without the frontmost-app check a session would be marked
  seen while you worked in something else; and the **id must match**, so being in a
  different terminal window does not clear it.

### D24. `acknowledgeSids` takes Space ids instead of looking them up
- **Decision:** pass the ids in from `scanActive`, which has already paid for
  `activeSids()`.
- **Why:** `hs.spaces` calls are slow enough that repeating them on the dot's 3 s timer
  was a **measurable** cost. An early version called them from the task callback and it
  was the wrong place.

### D25. The dot has its own timer
- **Decision:** `M.claudeDotSeconds` (3 s) drives it directly.
- **Why:** riding the 10 s `scanActive` made it lag far enough that a session looked idle
  for seconds after it started working — the panel read "all green" during real work.

### D26. Read the dot's state from Terminal's AppleScript, not from Accessibility
- **Decision:** ask Terminal for its window titles.
- **Why:** Terminal reports titles for windows on **all** Spaces, so the dot stays
  correct for Desktops you are not viewing — **the one place this tool escapes the
  "only the active Space is readable" constraint of D3.** Matching the title's cwd
  component against the Desktop's repo label avoids needing any window-to-Space mapping.

### D27. That AppleScript call must stay asynchronous
- **Decision:** it runs through `hs.task`, and a redraw happens only when a dot actually
  changed.
- **Why:** **measured** — the same query issued synchronously blocked long enough to time
  out Hammerspoon's own IPC, precisely the class of stall that D4 and D5 exist to prevent.
  `draw()` rebuilds every canvas, so redrawing unconditionally is not free either.

---

## Git state and the ⌘⌃⌥g popup

### D28. The git dot is local-only; the network half is a separate keypress
- **Decision:** the dot answers one offline question — does GitHub have everything on
  this machine? RED = dirty tree **or** unpushed commits; GREEN = clean and pushed. It is
  `git status --porcelain` plus `rev-list @{u}..HEAD`, **no network**.
- **Why:** "has GitHub itself changed?" cannot be known without contacting GitHub, and the
  answer goes stale the moment anyone pushes. **A dot must not assert what it hasn't
  checked.**
- **Where:** `refreshGitStates()` → `gitStateFor`, second in each entry's `dots` list.
  GitHub state lives in the ⌘⌃⌥g popup (`M.scanGitHub`) instead — the only thing here
  that touches the network, only when pressed, and only for the repos currently shown
  (`displayedRepos`).

### D29. ⌘⌃⌥g uses `git ls-remote`, not `fetch`
- **Decision:** read the remote head SHA with `ls-remote`.
- **Why:** it downloads no objects and updates no local ref, so it **never changes what
  `git status` shows in the user's own terminal** — the light touch that was asked for.
- **Cost, accepted:** a yes/no "GitHub differs", not an exact behind-count.
- **Classification:** remote SHA equals `HEAD` → up to date; remote is an ancestor of
  `HEAD` → unpushed only; otherwise → "GitHub ahead", **which also covers a true
  divergence**, where the remote SHA is not even in the local object store.
- `GIT_TERMINAL_PROMPT=0` plus an `M.githubTimeout` watchdog mean a remote that needs
  credentials fails fast instead of hanging the query.

### D30. Clicking "GitHub ahead" pulls, and `--ff-only` is the whole design
- **Decision:** `git pull --ff-only`.
- **Why:** this is the **only** thing in the tool that WRITES to one of your
  repositories, so it is the one place that has to be conservative instead of clever. The
  trap is that "GitHub ahead" also covers a true **divergence** (D29). A plain `git pull`
  answers divergence with a merge commit — a rewrite of your history from a single click,
  in a window with nowhere to resolve a conflict. `--ff-only` takes the easy case
  (someone pushed from your other machine, which is what this button is for) and refuses
  everything else out loud.
- **Verified 2026-08-01 on a throwaway repo:** behind-only fast-forwards; diverged returns
  `fatal: Not possible to fast-forward, aborting.` with **HEAD unmoved**.
- `M.pullFFOnly = false` allows the merge for anyone who wants it.

### D31. The pull refuses while a claude session is WORKING in that repo, not merely open
- **Decision:** block on `working`; `M.pullBlockOnClaude = "any"` for anyone who wants it
  strict.
- **Why:** changing files under a session that is mid-task destroys nothing, but it leaves
  that session reasoning about files that no longer say what it read. **Blocking on any
  live session was considered and rejected:** on the machine this was built for, a session
  is open in most repos most of the time, so that rule would have refused nearly every
  pull and the button would be decoration.
- **The test is `claudeStates`** — the live read of terminal titles — **and NOT
  `claudeStateFor`**, which returns nil once you have acknowledged a session and would
  therefore call a busy repo clear.

### D32. The open-file check exists because that is the only way this button can lose work
- **Decision:** before pulling, find what would change and abort if any of it is open in
  a `docApps` editor.
- **Why:** git protects what it knows about — **verified 2026-08-01** that an uncommitted
  edit to an unrelated file survives a pull untouched, and an uncommitted edit to a file
  the pull wants results in `Please commit your changes or stash them before you merge.
  Aborting.` What git **cannot** see is an editor holding an old copy in memory: pull new
  text, then save from that editor, and the incoming change is gone with no git operation
  to blame. This panel already reads the open document of every editor in `M.docApps` for
  repo detection (D5), so it is the one component that CAN see it.
  - **Learn what would change without changing anything:** `git fetch` (which the pull
    would do anyway, and which only moves the `origin/…` tracking ref) then
    `git diff --name-only HEAD..@{u}`. Those paths are matched against the open documents.
  - **Abort, don't warn.** A warning still leaves the stale buffer sitting in front of
    you; the failure mode is a save you make a minute later, long after the warning is
    gone. Closing the file and clicking again costs seconds.
  - **A clean check means "nothing KNOWN to be open", never "nothing is open."** It sees
    only `M.docApps` editors, only on Desktops read since launch. **Never let this guard
    imply a guarantee, in the UI or in the docs.**
  - **The precheck talks to the network too**, so it carries the same watchdog as the
    pull. Without one, a wedged fetch leaves `pullPrecheckTask` set and every later click
    reports "a pull is already running".
- **Live tension RESOLVED 2026-08-06 by D79** — TeXShop's `AXDocument` read was measured at
  0.10–0.23 ms, indistinguishable from MacDown and Preview, so it is in `M.docApps` and
  inside the check. The reasoning that kept it out for five days is preserved below because
  it is the procedure for the next candidate, not a mistake:
- **TeXShop is knowingly outside the check, and was left that way
  (2026-08-01).** It is a real editor for this user's repos, so the gap is real. But
  `docApps` is an allowlist precisely because asking some apps for `AXDocument` can stall
  the panel for minutes (D5), and **TeXShop has never been measured**. Adding it would
  trade a documented blind spot for a possible hang in the read path, which is the one
  thing this codebase has spent the most effort protecting. Documented in the README's
  "What to be careful about" instead. **If it is ever added, measure the `AXDocument` read
  first.**

### D33. The confirmation comes AFTER the checks, so it can name what will change
- **Decision:** prompt with the file list, not with "Are you sure?".
- **Why:** "Are you sure?" is a speed bump you learn to click through; "3 files will
  change: notes.md, run.lua, extra.txt" is a decision. The file list is already in hand
  from the precheck, so the informative version costs nothing. It also means the prompt
  only ever appears for a pull that is actually going to happen — the blocked cases say
  why instead of asking.

### D34. The prompt lives INSIDE the popup, not in a system dialog
- **Decision:** the two links go in the popup's status area and post back through the same
  `usercontent` bridge as the pull link.
- **Why:** `hs.dialog.blockAlert` would be less code, but an alert raised by Hammerspoon
  while another app is frontmost **can open BEHIND that app** — the most likely
  explanation for the "⌘⌃⌥N does nothing" report of 2026-07-30. The popup is already
  frontmost under the cursor. It also avoids a modal blocking the Lua state while a task
  callback is mid-flight.

### D35. Git's refusals are shown verbatim, not second-guessed
- **Decision:** **there is no dirty-tree guard.** Git decides and the popup repeats it.
- **Why:** a dirty file in the way, or a history that cannot fast-forward, is exactly what
  you want to be TOLD rather than have handled for you — and git's messages are better
  than any pre-flight check this tool would write.

### D36. There is no push button, deliberately
- **Decision:** offer pull, never push.
- **Why:** a fast-forward pull cannot lose work. A push can. **The asymmetry is the whole
  reason one is offered and the other isn't.**

### D37. A click reaches Lua through an `hs.webview.usercontent` controller built once
- **Decision:** the controller is built **once** and reused; the pull runs through
  `hs.task` with its own watchdog (`M.pullTimeout`, longer than the query's — a pull
  fetches objects).
- **Why:** `showGitHubPopup` deletes and rebuilds the webview on every ⌘⌃⌥g, so the
  controller has to outlive it. And nothing that touches the network may block the panel
  (D27).

### D38. The success line is timed to be read
- **Decision:** 2.5 s before the rescan.
- **Why:** a successful pull re-runs the whole query so every row is true again, not just
  the clicked one — but that rebuilds the popup and takes the result with it. **Measured
  at 1.2 s the message was gone before it could be read.** On failure there is no rescan,
  so git's message stays until dismissed.

### D39. A pull does update `origin/main`; the query does not
- **Decision:** state the "your local refs untouched" promise for the ⌘⌃⌥g **query**
  only, never for the pull button.
- **Why:** `git pull --ff-only` fetches even when it then refuses to move your branch.
  That is normal and harmless, but it makes the promise false for the button.
- **Related:** no "last push" time is shown, because **git does not record one.** The
  popup shows the last *commit* time (`log -1 %cd`), which is real; a push timestamp would
  have to be invented or fetched.

---

## Rendering the panel

### D40. A label that names apps is replaced by those apps' icons; a label that names work is not
- **Decision:** `detectLabel` returns the KIND of evidence behind the label — `repo` /
  `cwd` / `app` / `apps` / `none`. `apps` (a bucket: `Utility`, `Communication`) and `app`
  (one app's own name: `MacDown`) both draw icons; `repo` and `cwd` keep their text.
- **Why:** in the `app`/`apps` cases the word is only standing in for the apps themselves.
  `repo` and `cwd` **name the work, which no icon can.** Icons for the single-app case
  were withheld at first, on the grounds that `MacDown` already says something — but that
  was written before the hover tip existed. Once pointing at an icon gives the name back,
  dropping the word costs nothing and the panel stops treating "one app" and "three apps"
  as different kinds of thing. **Asked for and chosen 2026-07-30.**
- **Consequence worth knowing:** `M.appLabels` (D10) now shows only when icons are off or
  unavailable, so that disambiguation is carried by the icon and the tip instead.
  `M.showAppIcons = false` restores the words.
- **Constraint:** icons need a real read of the Desktop (bundle ids come from the window
  snapshot), so a Desktop whose name was restored from disk shows its old text until it is
  next scanned — the same constraint every other live detail has (D3).

### D41. A line is a NAME and an ICON ROW, and they answer different questions
- **Decision:** the two are independent. ⌘⌃⌥n replaces the name and **leaves the icons
  alone.**
- **Why:** the name says what the Desktop is *for*; the icons say what is *on* it.
  Renaming a Desktop cannot change which apps are sitting on it, and the old behaviour —
  an override suppressed the icons entirely — **threw away a fact to honour a label.** The
  name is empty only when the icons are standing in for a word that itself named apps
  (`Utility`, `MacDown`); a repo or session directory keeps its text and the icons follow
  it. **Asked for 2026-07-30.**

### D42. The icon row is placed by measuring the styled line, not by counting characters
- **Decision:** `hs.drawing.getTextDrawingSize(styledtext)` measures the object actually
  drawn.
- **Why:** the line mixes two font sizes (the half-space between the dots), so a character
  count puts the icons a few px off — **and the error changes with the dot states, so the
  row would visibly shift as sessions started and stopped.**
- **Width is still budgeted in characters** (`iconTextPad`), because that is the unit the
  panel sizes itself in.
- Dragging from an icon moves the panel exactly as from the text; each icon carries its
  OWN element id (`icon:<sid>:<wid>`) rather than the line's, because a click on an icon
  means something more specific than a click on the line (D56).

### D43. Some apps are invisible to Accessibility, so CoreGraphics is a second window source
- **Decision:** `snapshot()` also indexes `hs.window.list(true)` (CoreGraphics), and
  `readSpaceFrom` falls back to it for any window id Accessibility could not resolve.
- **Why:** **measured 2026-07-30** — the Claude desktop app returns **nil for every AX
  attribute** (no role, no `AXWindows`, nothing) and ChatGPT Classic likewise exposes no
  window. A Desktop holding both therefore read as empty (`—`) however many windows were
  on it. The natural assumption, reported as such, was that one of our own rules was
  hiding them. **It was not:** `noRepoHintApps` only withholds an app's *title* from repo
  matching (D8), and the app still counts toward the subject — if a window can be seen at
  all.
- **Same discipline as D4:** ~14 ms, ONCE per read pass, never per window.
  - **Layer 0 only.** CoreGraphics lists everything on screen — menu-bar extras,
    Spotlight, Control Center, the Dock, us — all at layer 24/25. Layer 0 is an ordinary
    application window, and the filter is what makes the fallback usable rather than
    noise.
  - **It is on-screen only**, so it resolves nothing for a Space you are not viewing.
    That costs nothing: the active Space is the only one macOS lets us read anyway (D3).
  - **These windows contribute an ICON and nothing else.** CoreGraphics gives an owner and
    a pid — no title, no `AXDocument` — so they can never touch repo detection, and there
    is no window object to raise. Clicking one activates the *application* instead, which
    is why an icon id can be `icon:<space>:p<pid>` as well as `icon:<space>:<windowid>`.

### D44. The icon row is saved to disk with the name, because it costs only a bundle id
- **Decision:** `saveLayout` persists the icon row alongside the name.
- **Why:** names have always survived a reload; icons did not, so every reload — and every
  `git pull` of this file — left a panel of bare words until ⌘⌃⌥S walked all thirteen
  Desktops. **That was never a platform limit**: an icon needs only a bundle id, no window
  read at all. It was simply the half of `saveLayout` that was missing. **Reported
  2026-08-01** as "why do I have to press ⌘⌃⌥s after every change"; the honest answer was
  that it had not been saved.
  - **Window ids are deliberately NOT saved.** They are reused after a reboot, so a stale
    one could raise a window that has nothing to do with the icon you clicked — **a wrong
    action is worse than a missing one.** A restored icon still draws and still names
    itself on hover; it just has no window behind it, so it gets an `icon:<sid>:r<n>` id
    and a click on it only goes to the Desktop. Full behaviour returns the moment that
    Desktop is read.
  - **A restored row can show something that is gone.** **Observed immediately:** a
    `Problem Reporter` (crash dialog) window that had been on a Desktop was still in its
    saved row afterwards. This is the same staleness the restored NAME has always had, and
    the fix is the same — read the Desktop. What makes it honest rather than misleading is
    D45.

### D45. A count of unread Desktops sits above the legend, and clicking it reads them
- **Decision:** show "10 Desktops not read yet · click here or press ⌘⌃⌥s to read them",
  count down as Desktops are read, and disappear at zero.
- **Why:** macOS only lets us read the Desktop you are looking at (D3), so after a reload
  the rest are last session's picture until visited (D44). The panel now says so.
- **It names BOTH ways of acting because both exist:** the line is a click target and the
  hotkey does the same thing. An earlier draft trailed the hotkey in a parenthesis, which
  **read as a footnote rather than as something to do — reported 2026-08-01.**
- **Free:** computed from the entries `draw()` has already built, so it costs no extra
  `hs.spaces` calls. It hides while a scan is running because `M.status` is saying the
  same thing more precisely.
- **Asking rather than scanning automatically is deliberate:** a ⌘⌃⌥S walk takes over both
  displays for ~25 s, which is not something to do to someone unprompted every time they
  reload.

### D46. Finder and terminals get icons, always last
- **Decision:** collect them separately (`extras`) and append after the subject apps.
- **Why:** they are in `ignoreApps` because a Desktop is never *about* Finder (D6) —
  **that is a statement about the SUBJECT, not about whether they are worth showing.**
  "There is a Finder and two terminals here" is real information.
- Hammerspoon stays out: it is this panel. The terminal list is taken from
  `M.claudeOnlyHintApps` rather than duplicated, so adding your terminal in one place is
  enough.

### D47. A terminal icon is dropped from a Desktop named after a repo or a session directory
- **Decision:** drop it when the detection KIND is `repo` or `cwd`. Finder always stays.
- **Why:** that name came from the terminal's own working directory (D14), so its icon
  would say the same thing twice — and the icons exist to add what the name cannot. Finder
  is never redundant that way.
- **The test is the KIND, not the displayed text**, so a ⌘⌃⌥N rename does not quietly
  bring the terminal back (same discipline as D22).

### D48. Trailing icons never count toward the "enough icons to drop the word" threshold
- **Decision:** `list.lead` records how many entries are subject apps, and only those are
  counted against `list.min`.
- **Why:** otherwise a Finder window could be the second icon that lets a three-app
  Desktop lose the word `Utility` while one of its apps had no resolvable icon — **the
  exact misrepresentation the threshold (D57) exists to prevent.**

### D49. Resizing scales `M.fontSize`, because everything else is derived from it
- **Decision:** one number resizes the panel coherently — line height, character width,
  icon edge, legend size and the width bounds all come from it.
- **Why:** there is no free aspect ratio to preserve; the panel's shape follows its
  content. So the corner drag is projected onto the diagonal
  (`((startW+dx) + (startH+dy)) / (startW+startH)`) and turned into a size. **Both axes
  contribute**, so dragging out along either one grows it.
- **Integer sizes** mean ~20 redraws across a full drag rather than one per pixel, and
  `setFontSize` skips its file write mid-drag because `endDrag` writes once on release.
  - **The grip is at the corner OPPOSITE the panel's anchor.** The panel is positioned by
    its top-left, so growing it from the bottom-right keeps the corner you're holding the
    one that moves.
  - **`draw()` replaces every canvas, including the one being dragged**, so the resize
    branch re-points `drag.cv` at the successor by screen UUID after each step. Without
    that, the next move acts on a deleted object.
  - **This replaced a pair of −/+ buttons (v39).** They worked, but one point per click
    across a useful range is tedious — the objection to any stepper, and the reported
    complaint. Their width also had to be reserved out of the panel's top-right corner;
    the grip sits past the end of the legend and costs nothing.

### D50. `minWidth`/`maxWidth` are px at `M.baseFontSize` and scale from there
- **Decision:** treat the width bounds as relative to `M.baseFontSize`, not absolute.
- **Why:** a flat px cap stops meaning anything once the panel can be zoomed. **Measured
  2026-07-30:** at 20 pt a long repo name plus its icon row needs ~990 px, so the fixed
  760 cap silently cut the icons off the right-hand end — visible only because the icons
  made the truncation obvious where clipped text had been easy to miss.

### D51. The active-Desktop marker is a caret AND a colour, and the two markers are the same width
- **Decision:** `"▸  "` against `"   "`, plus a magenta Desktop number (`M.activeColor`).
  **Both, rather than either.**
- **Why (width):** the prefix was `"▸ "` against `"   "` — two cells against three, so the
  Desktop you were standing on was the one line that did not line up with the rest.
  **Measured in Menlo 13: `"▸ "` is 15.65 px, `"   "` is 23.48, and `▸` alone is exactly
  one cell (7.83), so `"▸  "` matches.** Do not assume a glyph is one cell wide because
  the font is monospaced — measure it, as `M.activeMarker`'s comment says.
- **Why (both):** colour alone excludes anyone who cannot separate magenta from white, and
  this panel already spends four colours on the dots. **Magenta is deliberately none of
  them.**
- Only the marker and `Desktop N` are coloured — the label stays white so a repo name
  reads identically wherever you happen to be.

### D52. ⌘⌃⌥N renames the FOCUSED Space, not the one under the pointer
- **Decision:** `hs.spaces.focusedSpace()` first; the mouse is the fallback.
- **Why:** they were the same thing until the panel could be dragged across a display
  boundary. With it straddling two screens, resting the pointer over the panel meant
  `hs.mouse.getCurrentScreen()` returned the *other* display, so ⌘⌃⌥N **silently offered
  to rename a Desktop you weren't looking at.** Focus is where you are working.

### D53. An `hs.canvas` IMAGE element never reports mouseEnter/mouseExit, so every icon carries a transparent rectangle
- **Decision:** all mouse handling for an icon lives on an invisible rectangle laid over
  it; the image element is left untracked.
- **Why:** **measured 2026-07-30 with identical frames and identical tracking flags** — an
  `image` element reports `mouseDown`/`mouseUp` but **neither enter nor exit**, while a
  `rectangle` reports all four, and a rectangle with `alpha = 0` still hit-tests.
- **If hover ever stops working, check this first.** It is not something the documentation
  states.

### D54. Naming an icon beats enlarging it
- **Decision:** a hover tip giving the app name and, on a second dimmed line, the title of
  the window a click would raise.
- **Why:** the icons replace a label for Desktops that are a mix of apps, which is exactly
  where the less-used apps live — and **a bigger version of an icon you didn't recognise
  is still an icon you don't recognise.** The second line is what lets you tell two windows
  of the same app apart before committing to the switch.

### D55. The tip is re-placed by `draw()`, and a poll guards against the mouseExit that never comes
- **Decision:** `refreshTip()` runs at the end of `draw()` and re-places the tip if the
  same icon still exists; `tipWatch` checks every 0.4 s that the pointer is still inside
  the hovered icon's rect.
- **Why (re-place):** `draw()` deletes and rebuilds every canvas, which orphans a visible
  tip on a dead element — and **no fresh mouseEnter arrives while the pointer sits still**,
  so the tip would simply vanish every time a dot changed (a 3 s timer, D25). A *pending*
  tip timer needs nothing: when it fires it reads the new canvases anyway.
- **Why (poll):** deleting a canvas under the pointer can swallow the exit, which would
  **pin a tip on screen permanently.** The poll runs only while a tip is actually showing,
  so it costs nothing the rest of the time.

### D56. Clicking an icon raises that window; clicking the line does not
- **Decision:** the line stays "take me there"; the icon is the only way to say *which*
  window you want.
- **Why:** arriving on a Desktop should normally leave it as you left it. Picking an icon
  is what makes the icon row worth pointing at.
- **The window is re-resolved by id at click time (`hs.window.get`)** rather than reusing
  the object captured during the read: that object may be minutes old and its app long
  gone, and only once the Space is active is the lookup reliable. **`hs.window.get` is the
  ~40 ms call banned from the read path by D4 — one click can afford it, a per-window loop
  cannot.** This is the sanctioned exception.
- The raise waits `M.iconFocusDelay` for the Space switch to finish; firing into a
  half-finished switch does nothing.

### D57. How many icons a row needs depends on what it replaces (`list.min`)
- **Decision:** a single-app Desktop draws its one icon; a **mixed** Desktop needs two.
  The threshold is recorded per Desktop when it is read, not hardcoded in the renderer.
- **Why:** the word a single-app row replaces is that app's name, which the tip gives
  straight back (D54). One icon on a mixed Desktop would **assert the other apps aren't
  present**, and `Utility` is at least honest about being a summary.
- Icons are memoized per bundle id (`false` records "has no icon") since `draw()` rebuilds
  every canvas and app icons do not change while Hammerspoon runs.

### D58. An empty dot slot goes gray whenever the line shows any live dot — but only then
- **Decision:** a gray placeholder holds the column open when the other dot is lit; a line
  with **no** live dot keeps blank spacers.
- **Why:** the two dots are told apart only by position — claude first, git second — and
  position is unreadable when one column is blank: **a lone green git dot in slot 2 reads
  as a claude dot saying "finished".** It is deliberately not unconditional, because a
  gray pair on every Desktop with nothing to report would be two columns of noise.
- **The rule is symmetric**, so a session in `~` (claude dot, no git dot) gets the same
  treatment in reverse.

### D59. Both dots share one `hs.styledtext` element
- **Decision:** an entry carries an ordered `dots` list (`{ch, color}`, claude then git);
  `draw()` builds `prefix .. dot1 .. dot2 .. suffix` as a single styledtext.
- **Why:** the click target and sizing (`e.text`) are unchanged, and a blank (uncoloured)
  dot is just a spacer that keeps the arrows aligned.

---

## Refresh and lifecycle

### D60. Event-driven refresh, debounced
- **Decision:** an `hs.window.filter` on create/destroy triggers a refresh ~0.8 s after
  changes settle.
- **Why:** cheap now that reads are single-snapshot (D4); it just schedules the fast read.

### D61. Deferred first scan on launch
- **Decision:** `start()` draws immediately and schedules the first read 1.5 s later.
- **Why:** so a slow read can never freeze Hammerspoon during config load.

### D62. Version stamp on every change
- **Decision:** every build sets `M.version` and prints it on load. **Bump it on every
  change.**
- **Why:** added after a stale-file mix-up — a copy saved as `desktop_dashboard_11.lua`
  meant `require` kept loading old code. A printed version makes a stale file obvious.

---

## Repo and process

### D63. Keep `pre_conversion` material as `PRE_CONVERSION/`, and leave the originals unedited
- **Decision:** the former `archive/` — `MOVING.md` and the one-time migration
  `STATUS.md` — moved to `PRE_CONVERSION/` on 2026-08-03 under the standard's D13. The two
  originals are **not edited**; only the folder's own index `README.md` was updated to say
  the new name.
- **Why:** D13 of `claude-config` — never modify an original in place. `archive/` was
  already doing exactly the job `PRE_CONVERSION/` is for, under a different name, so this
  is a rename rather than a new practice.
- **Note:** that `STATUS.md` is a **one-time migration record from 2026-07-27**, not a
  living snapshot. It is not the same kind of file as the repo-root `STATUS.md` written by
  this migration, which is why it stays under `PRE_CONVERSION/` rather than being merged.

### D64. `desktop_dashboard.lua`, `claude-dashboard-state.sh` and `init.lua.example` stay at the repo root
- **Decision:** the code does not move into a spine folder.
- **Why:** the standard is explicit that code, build tooling and entry points never move
  into the spine folders, because imports and registered paths point at them.
  `~/.hammerspoon/init.lua` points `require` at `desktop_dashboard.lua` by path, and
  `~/.claude/settings.json` names `claude-dashboard-state.sh` by path on four hook
  registrations. **Moving either would silently break a live installation on every machine
  that has one** — and the second one would break it for anyone who followed `INSTALL.md`.
- **Where:** `INSTALL.md`, `init.lua.example`, `~/.claude/settings.json`.

### D65. Every `hs.task` streams its output and carries a timeout
- **Decision:** all subprocess reads go through one `runTask(bin, args, timeout, done)`
  helper. It installs a **streaming callback** that accumulates stdout/stderr as they
  arrive, and a **watchdog** that terminates a read that has not come back. `done` receives
  the accumulated buffers plus a `timedOut` flag; a stall is announced with
  `hs.alert` and printed to the console, once per stall. No new `hs.task.new` call is
  written by hand.
- **Why:** **without a streaming callback, `hs.task` deadlocks on more than ~512 bytes of
  output.** Hammerspoon does not drain the child's stdout until the child exits, and a
  macOS pipe starts with a 512-byte buffer, so a child that writes more blocks for ever
  inside `exit()` — work finished, output stuck in the pipe, termination callback never
  fired. Measured 2026-08-04 on **Hammerspoon 1.1.1 (build 6936), macOS 14.1.1**, with
  `osascript` children returning strings of known length:

  | stdout | callback fires? |
  |---|---|
  | 100, 300, 500 bytes | yes |
  | 700, 900, 1100, 1500 bytes | **never** |

  The fix was verified on the same child at **253,893 bytes in 502 chunks**, complete at
  the moment the termination callback fired. The streaming callback **must return true**;
  returning false stops the drain and restores the deadlock.
- **What it cost, which is the real argument:** the claude title read emits ~900 bytes with
  13 Terminal windows open and the git pass about one line per repo, so **four of the six
  reads were over the limit and the panel's whole async layer was down at once** — no
  claude dot, no git dot, no ⌘⌃⌥g. Worse, each read sits behind an
  `if <task> then return end` in-flight guard, so one deadlocked child pinned its guard for
  the life of the session: on 2026-08-04 an `osascript` child ran **5 h 21 min** and every
  poll behind it returned instantly without doing anything. **⌘⌃⌥S could not help**, because
  `scanActive` calls the same function. Restarting Hammerspoon did not help either — the
  relaunched instance's first poll deadlocked 3 s after launch.
- **Why the timeout is not optional:** a panel with no dots is indistinguishable from
  "nothing is running". The failure is silent, it looks like a correct answer, and it
  survives every reflex a user has (rescan, reload, restart). The timeout bounds it and the
  alert names it.
- **Ordering:** `runTask` returns the task **unstarted** so the caller can store its
  in-flight reference before any callback can fire. Its `fired` guard also removed a
  pre-existing double-report in the ⌘⌃⌥g pull, where killing a task fired the termination
  callback *and* the hand-rolled watchdog.
- **Where:** `runTask`, `noteTaskStall`, `liveWatchdogs`, `M.taskTimeout` (20 s) in
  `desktop_dashboard.lua`; the five reads that capture output — `refreshClaudeStates`,
  `refreshGitStates`, `M.scanGitHub`, and the pull and its pre-check. The sixth,
  `focusTerminalWindow`, passes a `nil` callback and captures nothing.
- **Live tension:** whether this is a Hammerspoon bug or documented behaviour was not
  established, so a future Hammerspoon may make the streaming callback unnecessary. It
  stays regardless: it is correct either way, and the timeout is worth having on its own.

### D66. A subprocess writes to a file, never to a pipe
- **Decision:** `runTask` wraps every command in `/bin/sh -c 'exec >out 2>err; exec <cmd>'`
  and reads those two files once the child has exited. The streaming callback stays as a
  drain of last resort, and whatever it delivers is **appended** to the file's contents —
  never chosen between.
- **Why:** D65's streaming fix stopped the deadlock but read the output **wrongly**, and
  the panel's session list flickered between a complete and a truncated view every few
  seconds. Two further properties of `hs.task`, measured 2026-08-04 on Hammerspoon 1.1.1
  (build 6936) with a child writing 914 bytes in a single `write()`:

  | child output | streaming callback got | termination callback got |
  |---|---|---|
  | 914 bytes, no multi-byte characters | 511 | **403** |
  | 914 bytes, an em dash straddling the 512-byte boundary | **0** | 403 |

  **The output is split between the two callbacks**, so either one alone is a truncated
  read — that was the flicker, and it was a bug in D65's helper, which preferred the
  streamed bytes and discarded the rest. And **a chunk that ends inside a multi-byte
  character is dropped entirely**: the whole 511-byte chunk vanished, unrecoverably, at the
  NSData→NSString conversion. Nothing in Lua can get it back.
- **Why a file rather than more careful pipe handling:** the titles this panel reads are
  full of `—`, `✳`, `⠂`, `×` and `◂`, so a chunk boundary lands inside a character often —
  it is a routine event here, not an edge case. A file has no buffer to fill, no chunking,
  no text conversion, and is complete the moment the child exits. It removes the cause of
  D65's deadlock as well as the truncation, rather than working around either.
- **Cost:** one small write and one read per poll — every 3 s for the session read, 15 s for
  git. The files are removed as they are read, and on the failure path too.
- **Where:** `runTask`, `readAndRemove`, `captureDir`, `shQuote` (moved above `runTask`, as
  the command line is now built there) in `desktop_dashboard.lua`.
- **Note:** `exec` replaces the wrapping shell, so the exit status reaching `hs.task` is the
  command's own. The ⌘⌃⌥g pull depends on that.

### D67. A Desktop is named by its live claude sessions; failing that, by the projects its windows belong to
- **Decision:** a Desktop with live claude sessions gets **one line per project** — not per
  session — named for that project, and nothing else is shown on it. A Desktop with no live
  session shows the projects its windows belong to, drawn in **orange**, at most **two**,
  ranked by how many windows on that Desktop belong to each, joined with ` / `. A Desktop
  with neither is unchanged: app, subject or `Utility`, with its icon row.
- **Why the orange state exists — the part that must not be lost:** it does **not** mean "a
  session is running here". It means **the Desktop is still set up for that project**. You
  exited claude but left the windows, and tomorrow you want to find your way back and
  restart it. That purpose is why its evidence is deliberately looser than the session
  rule's: a document open under a repo root, a repo name in a window title, **or a Finder
  window parked in the repo**.
- **Why per project and not per session:** three sessions in one repo are one piece of
  information about the Desktop. A line each would grow the panel every time a session is
  opened, for no gain. Three sessions — two in `Desktop_Dashboard`, one in `claude-config` —
  give **two** lines.
- **Why it is now correct:** a session is tied to its Desktop **by its window**, not by
  matching its directory name against the Desktop's label. Measured 2026-08-04: Terminal's
  AppleScript window `id` **is** the id `hs.spaces` uses, and `hs.spaces.windowSpaces(id)`
  placed 13 windows in **2.9 ms**, answering for **inactive** Spaces too. Sweeping
  `windowsForSpace` over all 15 Spaces instead costs **330 ms**. The old string match is
  what let an open `CLAUDE.md` from another project steal a Desktop's name *and its dot*,
  and what showed a session's dot on a Desktop the session was not on.
- **Interaction:** clicking a session line raises that project's terminal window on that
  Desktop, **cycling** through them where a project has several there. ⌘⌃⌥N on a session
  line renames the **project**, and that name is **global to the panel** — the project reads
  the same wherever it appears, and the rename survives moving the session to another
  Desktop. ⌘⌃⌥N anywhere else keeps the per-Desktop override of **D16**.
- **Supersedes:** the ordering in `detectLabel` where an open document outranks a live
  session's cwd (**D13**/**D14** stand; what changes is that a document no longer outranks
  a session), and **part of D7** — Finder contributes evidence again, but **only** to the
  orange state. D7's measured counterexample was put to Peter and accepted: a Desktop
  holding MATLAB, some `-zsh` windows and one Finder window parked in `Desktop_Dashboard`
  will now read `Desktop_Dashboard` in orange rather than `MATLAB`. What defuses it is that
  orange claims "set up for" rather than "the subject of", and the icon row still shows
  MATLAB.
- **Also decided, in the write-up:** the `Desktop N` prefix appears on the first line of a
  multi-line Desktop and the rest are indented under it; the icon row goes on that first
  line only; **`both` mode keeps its `T#` list**, which is no longer redundant now that the
  Desktop lines collapse sessions by project while `T#` still enumerates each session with
  its task summary; "project" means any repo under `repoRoots`, not only one carrying a
  `CLAUDE.md`; ties in the two-project ranking break on name, ascending, so the label cannot
  flicker between two equally ranked projects; and a minimized session window, which reports
  no Space, gets no Desktop line but still appears in the `T#` list.
- **Live tension:** the session poll reads **Terminal only**, so a session in iTerm, Ghostty
  or kitty produces no line however this rule is written. And the orange evidence for a
  Desktop you are not standing on is only as fresh as your last visit or ⌘⌃⌥S (**D3**).
- **Where:** `detectLabel`, `readSpaceFrom`, `screenEntries`, `claudeStateFor`, the click
  handler and ⌘⌃⌥N — Task **#5**.
- **Amended within the day: the colour is TEAL, not orange — see D74.** Everything else
  here stands; orange shipped in `v49` and was rejected on sight for colliding with the
  amber status and stale-hint lines.

### D74. A Desktop named after its projects is drawn in teal
- **Decision:** `M.projectColor` is teal, `{ 0.30, 0.80, 0.75 }`. It supersedes the orange
  of **D67**, which shipped in `v49` and lasted about twenty minutes.
- **Why not orange:** the scan status line and the stale-Desktop hint under the list are
  amber — `{1, 0.82, 0.35}` and `{1, 0.72, 0.35}` — so a third warm tone in one small panel
  read as one family rather than as three unrelated things. Reported on sight.
- **Why not blue, which is the obvious choice and the wrong one:** the legend's clickable
  words are blue (`M.legendClickColor`, `{0.45, 0.75, 1.00}`) and the legend **says so in
  words** — "click a line, or a blue word". The section headings are `{0.55, 0.8, 1.0}`,
  within a hair of the same blue. A third blue would have to be dark to be distinguishable,
  and dark is exactly what the panel's near-black background cannot carry. Peter asked for
  dark blue; this is the one place his instruction was not followed, and the reason is that
  the feature that claims blue was written on his other machine and had not merged yet, so
  the collision was not visible from where he was looking.
- **Why teal works:** it is the one cool slot nothing else claims, it is legible at Menlo 13
  on the panel's background, and it reads as *dormant* beside the warm yellow/amber cues
  that all mean *live* — which is the distinction the colour is carrying.
- **Where:** `M.projectColor`, `screenEntries` (`nameColor`), `README.md`, `CLAUDE.md`.

<!--
D68–D73 were written on the laptop as prose in `CLAUDE.md` on 2026-08-03, hours before
this repo was migrated onto the project spine on the iMac. They are lifted here on
2026-08-04 by the same rule the migration used for D1–D64: measurements intact, nothing
added, dropped or softened. The wording is the laptop's own except where a sentence had to
change tense to stand alone.
-->

### D68. A legend word is a button
- **Decision:** `M.legendClicks` maps a literal substring of a legend line to an element id
  that `activateElement` already routes on. `GitHub` is the first. The word is overdrawn in
  colour on top of the gray line rather than the line being split into styled runs, so the
  line's own layout is untouched and an empty `legendClicks` changes nothing.
- **Why:** reported 2026-08-03 — working from home over VNC on the office Mac, **the panel
  is perfectly readable but ⌘⌃⌥ is swallowed by the local machine**, so every command named
  on it is unreachable. The verdict was "of marginal use". A hotkey is the one thing a
  remote session cannot send.
- **Why not a visible affordance:** it costs **zero panel width** this way. The legend is
  the widest thing in the panel in Desktops mode, so an appended "or click here" would have
  widened the whole panel by ~13 characters to say what the colour already says. The third
  legend line names the affordance instead — "click a line, or a blue word" — one character
  shorter than the line it replaced.
- **Where:** `M.legendClicks`, `M.legendClickColor`, `activateElement`, `draw`.

### D69. That word is blue, not magenta
- **Decision:** `M.legendClickColor = { 0.45, 0.75, 1.00 }`.
- **Why:** magenta already means "the Desktop you are standing on". A second meaning would
  dilute the one cue that survives in a list of a dozen lines.
- **Consequence, recorded 2026-08-04:** blue is now spoken for, and the legend says so in
  words. That is what pushed D67's project colour to teal — see **D74**.

### D70. `hide` and `restore` are deliberately not clickable
- **Decision:** two legend words stay hotkey-only.
- **Why, and the two reasons are opposite:** `hide` is a **one-way door** — unhiding is the
  same hotkey, so on the one machine that cannot press it there would be no way back.
  `restore` is the reverse problem: not unreachable but **too** reachable. `M.restoreLayout`
  moves and opens windows across every Desktop and has no inverse, which is not something
  that should sit one stray click from `mode` and `name`.
- **Note:** asked for and removed 2026-08-03, having been wired the day it was written.

### D71. The overdrawn word is positioned by measuring, never by counting characters
- **Decision:** `legendWidth()` measures the prefix; the blue word is placed at that offset.
- **Why:** measured 2026-08-03 in Menlo 11 (`fontSize - 2`) — the prefix before `GitHub`
  measures **185.43 px where a character count gives 190.96**, a 5.5 px error against a
  6.62 px cell. The blue word would have landed most of a character right of the gray one it
  covers. `legendWidth()` composes exactly (185.43 + 39.74 = 225.17, the full line), so the
  overdraw registers.
- **Note:** the same rule as the active marker and the icon row. **This is the third time
  counting characters in a "monospaced" line has been wrong.**

### D72. The alert that has to leave the machine is raised by the hook, not the panel
- **Decision:** on the `waiting` that survives the nudge filter,
  `claude-dashboard-state.sh` optionally drops a marker into a synced folder
  (`NOTIFY_DROPBOX`) and optionally pushes to a phone (`NOTIFY_NTFY_URL` / Pushover). Any
  other state clears the marker.
- **Why:** asked 2026-08-03 — sessions on the office iMac sat blocked on a permission prompt
  for hours because the red dot was on a screen in Rhode Island. The panel cannot fix this;
  it renders state for the machine it runs on. The hook already fires at precisely the
  instant the answer becomes known, so the alert belongs there. Clearing on any other state
  means answering the question retracts the alert, without the receiving machine having to
  decide when one is stale.
- **Deliberately NOT the ssh replica:** a marker is a fact that was true when written.
  Carrying it needs no VPN, no reachability and no live connection, and it works when the
  laptop was asleep at the moment it happened. The replica is for browsing live state; this
  is for being told. Different jobs, no shared code.
- **The first read after launch only primes the seen-set.** Markers already in the folder
  are history, and announcing them at every login is how a signal becomes noise — the same
  reasoning that stops sessions already idle at launch from getting a green dot.
- **Marker parses are cached by name+mtime, including the FAILURES.** A file read mid-sync
  fails to parse, and every failure writes a LuaSkin error to the console — on a timer, for
  ever, for one bad file. Observed while testing: a malformed marker logged on every pass.
  **Verified the cache holds: 5 reads on the first pass, 0 on the second and third.**

### D73. Absent config means absent behaviour
- **Decision:** with no `~/.claude/dashboard-notify.conf` there is no marker and no network
  call. The network calls are backgrounded with `curl -m 8`.
- **Why:** this script runs on every prompt of every session, so the default has to be that
  it does nothing new. A hook that blocks holds up the session it exists to observe.
- **An idle-time gate was considered and rejected.** Suppressing the push while someone is
  actively using the machine sounds right and is exactly backwards here: **VNC input
  registers as local HID input**, so `HIDIdleTime` would be low precisely when the user is
  driving the iMac from home — suppressing the alert in the case it was built for. A
  per-machine config file is predictable; an inferred one is not.

### D75. Only a live session is coloured, and only an open document names a project
- **Decision:** two changes, made together on 2026-08-04 after seeing D67/D74 in use.
  1. **The colour moves to the session lines.** A Desktop named after a live claude session
     is drawn in teal (`M.sessionColor`); **everything else on the panel is white** — a
     Desktop named after a project whose document is open on it, an app, a bucket like
     `Utility`. `M.projectColor` is gone.
  2. **A project names a Desktop only when one of its documents is open there.** A Finder
     window parked in the repo no longer counts, a repo name appearing in a window title no
     longer counts, and the loose token-overlap match below it is deleted.
- **Why the colour swapped:** with the project lines coloured and the session lines white,
  the panel emphasised the Desktops where **nothing was running**. Reversing it makes the
  live sessions the thing the eye lands on, which is what the panel is for. Peter's words:
  "this makes the running sessions more special".
- **Why documents only:** *"Changing from one project to another in Finder is trivial and
  there is no need to highlight these windows."* A Finder window says where you were
  **browsing**; a mail subject or a Slack channel says what you were **talking about**. A
  document open from the project is the one artefact that says work is set up here.
- **How wide the removed surface was**, measured against the config on 2026-08-04 — this is
  why it mattered rather than being a tidy-up:

  | Path | What could name a Desktop |
  |---|---|
  | open document under a repo root | the 18 apps in `M.docApps` — **kept** |
  | Finder folder name | Finder — **removed** |
  | repo name inside a window title | **every app except** Claude, ChatGPT, six browsers, Finder and terminals — so Mail, Slack, OneNote, MATLAB, Messages, Stickies… — **removed** |
  | loose token overlap | the same set, looser still — **removed** |

- **What went with it:** `M.noRepoHintApps` and the `ctx` machinery in `readSpaceFrom` that
  built the Desktop's hint text in three tiers. Both existed only to feed the two deleted
  rules. **Leaving them would have been worse than deleting them**: a future session would
  tune a list that no longer connects to anything.
- **Supersedes:** **D8** and **D9**, which decided *which* titles may hint a repo, and the
  Finder half of **D67**, which Peter had accepted on 2026-08-04 and reversed the same day
  once he saw it work. **D7 is effectively restored** — it removed Finder from the repo hint
  in the first place, on a measurement from 2026-07-28. D5's `docApps` allowlist is now
  load-bearing in a second way: it is exactly the set of apps that can name a Desktop.
- **Any document, not only a `.md` — confirmed 2026-08-04.** Peter asked for "md file"; the
  looser reading was implemented and put back to him, and he confirmed it. A repo PDF open
  in Preview, a `.tex`, a `.m` or a spreadsheet all name the Desktop exactly as `CLAUDE.md`
  does, because they are the same evidence: a document from that project, open here. **Do
  not narrow this to an extension** without asking — it was considered and rejected.
- **Where:** `M.sessionColor`, `projectOfWindow`, `detectLabel`, `readSpaceFrom`,
  `screenEntries` — `v52`.

### D76. A name belongs to a project, never to a Desktop
- **Decision:** ⌘⌃⌥N always renames a **project**, on every line rather than only on a
  session line. The project is the session group's when a session runs there (**D67**,
  unchanged), otherwise the top-ranked project whose documents are open there (**D75**).
  On a Desktop with neither, ⌘⌃⌥N **refuses** and says why. The per-Desktop override of
  **D16** is deleted: the `overrides` table, its Space-ID key, its `manual` flag on disk,
  and its restore path.
- **Why:** the override outlived everything it described. Observed on the laptop
  2026-08-05 and decided 2026-08-06, and it is three failures rather than one:
  1. It **survived the windows closing.** A Desktop with nothing open on it read
     `3-way analysis` after a reboot — the saved entry is `name "3-way analysis",
     manual true, windows []`.
  2. It **hid every later reading.** `screenEntries` consulted `overrides[sid]` before the
     detected label, so opening a document from another project there changed nothing on
     the panel. There was no way to tell a stale name from a correct one.
  3. It **followed the Desktop through a reorder** in-session (keyed by Space ID) but
     comes back by **screen + position** across a reboot — so the two keys D16 chose
     deliberately disagree with each other the moment you reorder Desktops and quit.
- **Why a project is the right owner:** a name is an alias for the *work*, and the work is
  what moves. `projectNames` already made a session's rename global and durable (D67); this
  applies the same rule to the other kind of line, so a name appears wherever its project
  appears and **disappears from a Desktop when the project has nothing there any more** —
  which is what Peter asked for: *"check to see if a Desktop with no claude running and the
  other condition, which writes the project name, to which the current name applies is
  present. If neither of these, remove the name."*
- **⌘⌃⌥N now reads the Desktop before deciding.** It calls `scanActive` first: the focused
  Space is by definition active, and without it a Desktop whose documents were opened since
  the last read would look empty and refuse a name it can serve.
- **Migration is automatic and one-way.** `restoreNames` skips any saved name carrying
  `manual`, so a pre-`v53` override disappears on the first launch after the upgrade rather
  than lingering with no way to clear it. Existing overrides are **not** promoted to project
  names — the same reasoning as Task #5's: an override was a word for a *Desktop*, and
  promoting it to a global project name changes what it claims.
- **Supersedes D16 entirely**, and closes the "⌘⌃⌥N anywhere else keeps the per-Desktop
  override of D16" clause in **D67**.
- **Live tension:** a Desktop holding neither a session nor a document — a Utility Desktop,
  or an empty one being kept for later — can no longer be given a name at all. That is the
  deliberate cost: every name the panel shows is now something it can verify, and the
  alternative is the stale name above. Revisit only with a rule for **when such a name
  expires**, since "never" is what was just removed.
- **Where:** `renameProject`, `M.nameCurrent`, `screenEntries`, `M.saveLayout`,
  `restoreNames` — `v53`.

### D77. No synced folder, no polling
- **Decision:** `M.showRemoteAlerts = true` means "watch for remote alerts **if that is
  possible on this machine**". `M.start` arms the 20 s timer and the path watcher only when
  `M.remoteAlertDir` **or its parent** exists; otherwise neither is created and the feature
  is silently absent. The check runs **once, at start**, so installing the sync client later
  needs a Reload Config.
- **Why:** the receiving half of the cross-machine alert (**D72**) was on by default with a
  hard-coded `~/Dropbox/…` path, so a machine with no Dropbox ran a timer re-reading a
  directory that could not exist, plus a path watcher that had failed to attach, for the
  life of the session. Both are `pcall`-wrapped, so it was invisible rather than broken —
  which is the argument for fixing it rather than leaving it: **an unnoticed cost is the one
  that never gets removed.** Asked for by Peter on 2026-08-06 — *"auto-disable so to work
  with Dropbox-less machines"* — after asking what the project depends on.
- **Why the PARENT counts, not just the directory:** the marker folder is created by the
  first alert that arrives, so its absence proves nothing on a machine that does sync. Its
  parent's absence does. Accepting the parent is what lets a Dropbox machine that has never
  received an alert still watch for one.
- **Rejected: making the path configurable and defaulting it off.** That trades a silent
  no-op for a setting nobody would find, and D73 already established that the *sending*
  half is opt-in through a config file. The receiving half should cost nothing and need no
  decision.
- **Where:** `remoteAlertsPossible`, `M.showRemoteAlerts`'s comment, `M.start` — `v54`.

### D78. The install steps in the code must not contradict INSTALL.md
- **Decision:** the `INSTALL` block in `desktop_dashboard.lua`'s header says **clone the repo
  and point `package.path` at it**, and says in as many words not to copy the file into
  `~/.hammerspoon`. It previously said *"Copy this file to
  ~/.hammerspoon/desktop_dashboard.lua"*.
- **Why:** that instruction was the stale-copy bug of 2026-07-27 written down as a
  recommendation. `INSTALL.md`, `CLAUDE.md` and **D64** all say the opposite — the code stays
  where the repo is, because `~/.hammerspoon/init.lua` and `~/.claude/settings.json` name
  these files by path. **Anyone installing from the file rather than the docs walked into the
  bug**, and the file is the more likely thing to be read first: it is what you have open
  when you are changing the tool.
- **Where:** the header comment block of `desktop_dashboard.lua` — `v54`.

### D79. TeXShop is in `docApps` — the read was measured at last
- **Decision:** `TeXShop`, `BibDesk`, `Microsoft PowerPoint` and `OmniGraffle` join
  `M.docApps`. TeXShop's `AXDocument` read was **measured first**, as D32 demanded.
- **The measurement, 2026-08-06 on `cornillon-laptop`**, via the `hs` CLI against the live
  Hammerspoon, two reads per window (cold then warm):

  | app | window | cold | warm |
  |---|---|---|---|
  | TeXShop | `main.pdf` (20 pages) | 0.23 ms | 0.09 ms |
  | TeXShop | `main.tex` | 0.10 ms | 0.09 ms |
  | MacDown | three windows | 0.10–0.20 ms | 0.09–0.10 ms |
  | Preview | four windows | 0.12–0.19 ms | 0.09–0.10 ms |

  **TeXShop is indistinguishable from the editors already on the list.** D5's fear was
  Electron/Office/Java apps stalling for minutes; TeXShop is a native Cocoa document app and
  behaves like one. The `.tex` measured is small (5.4 KB) — the 20-page PDF alongside it is
  the closest thing to a large document in the sample, and it was the same 0.09 ms warm.
- **This closes D32's live tension and the README gap it created.** The pull precheck can
  now see a LaTeX file open in TeXShop, which was the whole point: *"treat a clean check as
  nothing known to be open, never as nothing is open"* was a documented blind spot in the
  one repo type Peter writes manuscripts in.
- **TeXShop contributes TWO window-votes for one open document** — the source and its PDF
  preview are separate windows and both report a path under the repo. That is harmless and
  arguably right: `rankProjects` counts windows, and a Desktop with TeXShop open on a
  manuscript really is more about that manuscript than a Desktop with one file open.
- **The other three were not measured**, and are on a weaker footing: `BibDesk` is native
  Cocoa like TeXShop and completes the LaTeX toolchain (`.bib` under `LATEX/bib/`);
  `Microsoft PowerPoint` joins Word and Excel, which have been on the list without incident;
  `OmniGraffle` is a native document app. **If the panel ever stalls, these are the first
  four things to pull back out**, and D5's warning stands unchanged for everything else.
- **Where:** `M.docApps`, D5's closing note, D32's live tension, README's "What to be careful
  about" — `v55`.

### D80. The hook carries no external dependency
- **Decision:** `claude-dashboard-state.sh` parses and emits JSON with `awk` and bash's own
  string operators. **`jq` is gone**, not made optional.
- **Why:** every `jq` call was already guarded with `command -v jq`, so a machine without it
  wrote **no state file and exited 0** — the red dot never lit, and there was nothing
  anywhere to explain why. macOS ships no `jq`, so **that machine is every fresh install**,
  which is exactly where this was found: a colleague could not get the panel working.
  Guarding a dependency is not the same as not having one; it converts a missing tool into a
  silent absence of behaviour, which is the worst of the three outcomes (work / fail loudly /
  fail silently).
- **It is also four times faster.** Measured 2026-08-06, 20 invocations each, same payload,
  same sandboxed `HOME`: **jq 121–128 ms per call, awk 33 ms.** The hook runs on
  `UserPromptSubmit`, so that cost was on every prompt of every session.
- **`\uXXXX` is decoded properly**, surrogate pairs included, because awk emits raw bytes
  from a decimal `%c` (verified: `226,156,179` → `✳`). The first draft returned `?` for every
  escaped character, which is silent corruption of a path. Claude Code's own payloads do not
  escape non-ASCII — JavaScript's `JSON.stringify` emits it raw — so this is belt and braces,
  and it cost six lines.
- **Verified in a sandboxed `HOME` with `PATH=/usr/bin:/bin:/usr/sbin:/sbin`** (no `jq`
  reachable, asserted by the test): ordinary payload; a `cwd` containing a quote, an
  apostrophe and a backslash; a message with newlines, tabs, emoji and C0 control bytes; a
  **nested object carrying a decoy `cwd` and `session_id`**, which must not win; the full
  `working → waiting → working → done → nudge → gone` sequence including **D19's nudge
  filter**; a missing `session_id`; an empty payload; a garbage payload; and no argument at
  all. **Every state file written parses as JSON.** The suite is
  `ISSUE_ANALYSES/Python/test_claude_dashboard_hook.py`.
- **Where:** `json_get`, `json_esc` and all five former `jq` call sites in
  `claude-dashboard-state.sh` — `v56`.

### D81. A session with no window still gets a line
- **Decision:** sessions the Terminal title poll cannot see are drawn from their hook state
  files, in the `T#` list, with dots and the terminal's name — and **no Desktop line**. On a
  machine where every session runs in Terminal.app, nothing changes at all. Controlled by
  `M.showHookSessions`; `Apple_Terminal` is excluded, because the title poll already covers
  those with a real window behind them.
- **Why:** a session in iTerm, Ghostty, kitty or Cursor's built-in terminal appeared
  **nowhere on the panel** — not as a Desktop line and not in the `T#` list, since
  `sessionEntries` iterates the same Terminal-derived table. For the colleague who reported
  this the panel was not degraded, it was empty. Meanwhile the hook file for every one of
  those sessions was already on disk and `readHookStates` was **throwing the per-session
  detail away** to build a `repo → state` map.
- **Why no Desktop line, when that is what the panel is for:** a hook file knows the repo and
  the working directory. It does not know a window, and `hs.spaces.windowSpaces` is what
  places a session on a Desktop (**D67**). A Desktop claim with nothing behind it would be a
  guess presented as a reading, and this panel's whole value is that its lines are true. So
  the line says what is known — which project, what state, which terminal — and stays out of
  the Desktop list.
- **They are shown even in Desktops mode**, in their own `Sessions elsewhere:` block. Leaving
  them out of a view is exactly the complaint this answers; a session you cannot see is not
  made less urgent by the view you happen to be in.
- **The state is arguably better than a Terminal session's**, not worse: the hook records
  `waiting` at the instant Claude Code asks, where the title poll has to infer state from a
  spinner glyph (**D17**). What is missing is only the window.
- **A file with no `term` field is skipped** rather than assumed. That is one written by a
  hook older than `v56` — including, at the moment this shipped, every session on Peter's own
  machine — and guessing would have put duplicate lines under the Terminal ones. They age out
  within `M.claudeHookMaxAgeHours`.
- **Requires the deployed hook to be updated**, not just this repo's copy: `settings.json`
  runs `claude-config/hooks/claude-dashboard-state.sh`. Synced and verified byte-identical
  the same day — the trap Task #1 was opened for.
- **Verified live** by writing a fake `Cursor` state file and photographing the panel: it
  drew `T4 ● ● MODIS_L2_Manuscript · Cursor` with a red claude dot, a green git dot, and
  `May I edit orbit_rea…` on the dimmed line beneath.
- **Where:** `readHookSessions`, `hookSessionEntries`, `sessionEntries`, `draw`,
  `M.showHookSessions` — `v56`.

### D82. iTerm is a first-class terminal — both blocking questions were measured
- **Decision:** the session poll reads **Terminal.app and iTerm2**, in one AppleScript. iTerm
  sessions get real Desktop lines, dots, and `T#` entries, exactly like Terminal ones, and are
  excluded from D81's hook-only list so they cannot be drawn twice.
- **The two measurements this waited on**, both taken 2026-08-06 against a live iTerm window
  Peter opened on a Desktop he was not standing on:
  1. **Does iTerm2's AppleScript report windows on INACTIVE Spaces?** **Yes.** The window was
     returned while the active Spaces were 12 and 532 and it sat on 205. This was the
     question that decided whether any of it was possible: it is the reason the poll is
     AppleScript rather than Accessibility (**D3**).
  2. **Is iTerm2's AppleScript window `id` the id `hs.spaces` takes?** **Yes.**
     `hs.spaces.windowSpaces(26169)` → `{205}` for the window AppleScript called 26169. D67
     had to establish the same thing for Terminal.
- **iTerm answers a BETTER question than Terminal does.** Terminal gives one composed string —
  `"<cwd> — <glyph> <task> — … claude — 173×63"` — and the working directory has to be parsed
  off the front of it. iTerm has `variable named "session.path"`, which **is** the working
  directory, from its own API. Only the spinner glyph is read from prose, and that is written
  by Claude Code rather than composed by the terminal.
- **Two syntax traps, both of which cost time:** `variable named "session.path" of sn` raises
  **-1723 "Access not allowed"**, which reads as a permissions failure and is nothing but a
  syntax error — `variable named` is a *command* on the session, so it needs
  `tell sn to set p to (variable named "session.path")`. And iTerm's enumeration is per
  window → tab → **session**, because a split pane is a session; all of them share the one
  window id, which is what places them on a Desktop.
- **One script, not two tasks.** A second `runTask` would mean a second in-flight guard, a
  second timeout and a second way to wedge (**D65**). Terminal lines stay `<wid>|<title>`;
  iTerm lines are `I|<wid>|<path>|<name>`, and `IFRONT` marks its frontmost window.
  Which of the two front ids counts is settled by asking the OS which application is
  frontmost, not by guessing.
- **A session is recognised as claude by "claude" appearing in the session name**, which is
  where iTerm puts the running job — `✳ Claude Code (claude)`. That is the same looseness the
  Terminal branch has always had, deliberately: matching the exact job name would break the
  moment anything wraps it, and `caffeinate ◂ claude` is already routine.
- **Verified live**: with Peter's session running `claude` in `~/Git_Repos/opendap-registry`
  in iTerm on Desktop 8, the panel drew `Desktop 8 ● ● → opendap-registry` with the iTerm
  icon, plus `T5 ● ● opendap-registry`. Photographed, not inferred.
- **Cursor remains out of reach** and D81's `T#` line is its ceiling: Electron, no usable
  AppleScript dictionary, and a title naming a file and a workspace rather than the session.
- **Where:** `CLAUDE_TITLE_SCRIPT`, `parseITermSession`, `parseClaudeTitles`,
  `M.hookSessionTerminals` — `v57`.

### D83. The hook fires on session start too, with a fifth state: `idle`
- **Decision:** `claude-dashboard-state.sh` is registered on **five** events, not four —
  `SessionStart` writes `idle`. It draws a line with **no claude dot**: a session is here, and
  it is not doing anything.
- **Why:** the other four all report a *transition*, so a session that has been opened and not
  yet prompted had written nothing at all. In Terminal or iTerm that is invisible but
  harmless, because the poll sees the window anyway. In a terminal the poll cannot read
  (**D81** — Ghostty, kitty, Cursor) it means the session does not exist as far as the panel
  is concerned **until you type something**. Peter hit exactly this: he started `claude` in a
  new iTerm window, nothing appeared, and neither mechanism was at fault — there was simply no
  event yet.
- **Why a new state rather than reusing `done`:** `done` means *finished and you have not
  looked*, which earns a green dot (**D21**). A session that has never run anything has not
  finished anything, and a green dot there would be a lie in the one place the panel is meant
  to be trusted. `idle` earns no dot at all.
- **Cost:** one more registration per machine, and it is the one an installer is most likely
  to leave off — so `INSTALL.md` now says which symptom that produces. No code change was
  needed in the hook: it already writes whatever state it is given, and `hookSessionEntries`
  already maps `idle` to no dot.
- **Unverified at the time of writing:** whether Claude Code's `SessionStart` payload carries
  `session_id`. If it does not, the fallback writes `nosession-<pid>.json`, which `SessionEnd`
  (with the real id) will not remove — a stray file that ages out in
  `M.claudeHookMaxAgeHours`. The next session started on this machine settles it; look for a
  file named after the session id rather than a pid.
- **Where:** the header of `claude-dashboard-state.sh`, `global/settings.json` in
  `claude-config`, `INSTALL.md` step 2.

### D84. A window title may say WHICH WINDOW hosts a session — never what to call a Desktop
- **Decision:** a hook-only session (**D81**) is placed on a Desktop when three things hold:
  its `term` maps to an app through `M.termApps` (`vscode` → `Code`), that app has a window
  whose **title names the session's own repo**, and **exactly one Desktop** matches. It then
  draws as a session line like any other, with the terminal named after it
  (`opendap-registry · vscode`). Ambiguous or no match → it stays in the `Sessions elsewhere`
  list, unplaced.
- **The boundary, and it is the whole point of this entry: a title is read to identify a
  WINDOW, never to name anything.** The session has already stated its directory, from inside
  itself. All the title does is answer "which of your windows is that?". **D75 stands
  unchanged** — no title contributes a Desktop's name, and a title that matches nothing
  produces silence rather than a guess.
- **Why the match is exact, not a substring:** the title is split on the em dash editors use
  and a component must **equal** the repo name. Substring matching is what D75 threw out —
  `opendap` would match a mail subject about OPeNDAP — and nothing here needs it, because a
  workspace component *is* the repo name.
- **Why "exactly one Desktop":** two windows of the same workspace on one Desktop is still one
  answer; two Desktops is an ambiguity, and an ambiguous answer is worse than none. It would
  put a live session on a Desktop it is not on, which is the failure **D67** was written to
  end.
- **What made this necessary, measured 2026-08-07 on Peter's live VS Code window** while a
  claude session ran in its built-in terminal, three consecutive reads:

  | attribute | value |
  |---|---|
  | `AXTitle` | `opendap-registry` |
  | `AXDocument` | *(empty)* |
  | focused element | `AXTextField` — `Terminal 1, ✳ Claude Code …` |

  **VS Code reports no document at all while its terminal has focus.** So the obvious design —
  match the session against the editor's open FILE — fails precisely when claude is being
  used, which is the only case it exists for. It was designed, put to Peter, and killed by
  that measurement before a line of it was written. The title, by contrast, was stable across
  all three reads and is exactly the workspace name.
- **Clicking such a line switches Desktop and does not raise the window.** The click path for
  session lines drives Terminal's AppleScript (`focusTerminalWindow`), and the window holding
  this session is not a Terminal window.
- **Superseded in intent, if Task #16 works.** Peter's counter-proposal — record the window
  that was frontmost when the session started, then place it by window ever after — reads no
  titles, works for terminals whose titles say nothing (Ghostty, kitty), and is D67-faithful
  rather than D67-adjacent. This stays as the fallback for sessions already running before
  the panel started.
- **Verified live and photographed:** `Desktop 8 ● ● → opendap-registry · vscode` with the VS
  Code icon, in the session colour, while `T3` listed the same session.
- **Where:** `M.termApps`, `titleNamesRepo`, `placeHookSession`, `hookSessionsSplit`,
  `screenEntries`, `draw` — `v58`.

### D85. A session is placed by the window it started in
- **Decision:** when a new hook state file appears, the panel records **the window that is
  frontmost at that instant** against that session id, and places the session by that window
  from then on — `hs.spaces.windowSpaces`, exactly as Terminal and iTerm sessions are placed.
  The mapping is persisted, and dropped when the session ends. **D84's title matching becomes
  the fallback**, for sessions that were already running before the panel loaded.
- **Why this is the right shape, and D84 was not:** a shell cannot report its own window, so
  the panel had been reduced to matching a repo name against a window title. But there is one
  moment when the window is knowable without matching anything — **the instant the session
  starts, its window is by definition the frontmost one.** **Peter's idea**, offered as an
  aside on 2026-08-07: *"would another option be to have claude write in a file which project
  it is working, which terminal it is running from and the Desktop it is in?"* Two thirds of
  that already existed; this is the third, obtained where it is actually available.
- **What it buys over D84:** it works for **every** terminal, including Ghostty and kitty
  whose titles say nothing about the repo; it reads **no titles at all**, so D75 is untouched
  rather than carefully bounded; and it is **D67-faithful** — a session belongs to the Desktop
  its window is on, dynamically, so moving the window moves the session.
- **The `SessionStart` hook (D83) is what makes it possible.** Without a file at session
  start, the only observable moment would be the first prompt, by which time the focus has
  usually moved. A `hs.pathwatcher` on the state directory catches the file within a second;
  the 3 s dot poll is the backstop.
- **Two guards, both load-bearing:**
  1. **The frontmost window is accepted only if its application is the one the session's own
     `term` names** (`vscode` → `Code`). Without it, starting a session and immediately
     switching away pins it to whatever you switched to — a confident, wrong Desktop.
  2. **Sessions that predate the load are never captured.** Their start moment is gone, so the
     frontmost window says nothing about them, and with two editor windows open it would say
     something confidently wrong. They fall back to D84.
- **Clicking such a line now raises its window** (`raiseWindowOnSpace`), which
  `focusTerminalWindow` could not do — it drives Terminal's AppleScript, and the window here
  belongs to VS Code or Cursor. The Space is switched first and the focus **retried three
  times over a second**, because a window on the Space you are arriving at cannot be looked up
  until the switch finishes, and how long that takes is an animation rather than a number.
  Verified that an ordinary window resolves from its CoreGraphics id (`hs.window.get` → OK for
  Terminal, Preview, MacDown, Finder); windows that expose no Accessibility element at all —
  the ChatGPT/Claude class — return nil, which is why the focus is best-effort and the Desktop
  switch is not.
- **A bug worth recording, because it cost the panel entirely for ten minutes:**
  `hookSessionEntries` was calling `placeHookSession` **before that local was declared**, so it
  resolved to a nil global. `draw()` threw on every pass, the panel vanished, and the ⌘⌃⌥S walk
  wedged part-way with a clean console — *precisely* the signature `CLAUDE.md` attributes to a
  garbage-collected timer. **A blank panel and a stalled walk mean "draw() is throwing" at
  least as often as they mean a GC'd timer**, and `pcall(draw)` is what hides it. Fixed by
  moving the three helpers above their first use.
- **Where:** `sessionWindows`, `noteSessionWindows`, `sessionsAtStart`, `placeHookSession`,
  `raiseWindowOnSpace`, the `win:` click id, `M.start`/`M.stop`, `saveLayout`/`restoreNames` —
  `v59`.

### D86. Never open Mission Control to reach a window
- **Decision:** raising the window a session runs in tries, in order: **focus the window**
  itself; failing that **activate the owning application**; and only if that application has
  gone, `hs.spaces.gotoSpace`. The Desktop lines still use `gotoSpace`, because for them there
  is no window to go through.
- **Why:** `hs.spaces.gotoSpace` **opens Mission Control** to do its work — the screen zooms
  out to show every Desktop and every window, then lands. Peter, 2026-08-07, on clicking a VS
  Code session line: *"it would show the same response I get when I do four fingers up — shows
  the desktops as well as all of the windows on the current desktop — but it then moves to the
  Desktop properly."* Clicking a **Terminal** session line does none of that, because it goes
  through `activate`, and the difference between the two was immediately visible.
- **Why activating the app works:** macOS follows an application to the Desktop of its
  frontmost window, with the ordinary switch animation. That is what Terminal's AppleScript
  `activate` has always done here; `hs.application:activate()` is the same thing without the
  AppleScript, and it reaches a window that **D3** will not let us look up from another Space.
  The exact window is then focused once we have arrived, retried three times over a second
  because the wait is an animation rather than a number.
- **The click ids now carry the app**, through a `raiseTargets` table rebuilt on every draw —
  the same pattern `cycleTargets` already used, and for the same reason: a project name or an
  app name may contain any character at all, so neither can be encoded in an element id.
- **Also fixed by D85's persistence, and the same report:** a session line that could not be
  placed had **no click target at all** — Peter's `T4` did nothing. That was D84's title
  fallback with nothing to match against, because a reload empties the read cache and no
  ⌘⌃⌥S had been pressed. Sessions captured by D85 no longer depend on a scan: the mapping is
  restored from disk, which is exactly what was observed after this build —
  `Desktop 6 ● ● → opendap-registry · vscode` drawn with **7 of 9 Desktops still unread**.
- **CORRECTED 2026-08-07, same day: `gotoSpace` was NOT the cause.** Asked to test it
  directly, Peter reported that clicking a plain **Desktop** line — which calls
  `hs.spaces.gotoSpace` and nothing else — *"simply moves to that line"*, with no Mission
  Control at all. So the zoom-out came from the other half of the old path: looking up and
  focusing a window that is on a Space we are not on. **The decision above stands and the
  ordering is still right** — go through the window, then the app, and treat `gotoSpace` as
  the fallback — but the reason given for it was wrong, and the corrected one is narrower:
  *reaching across Spaces for a window is what disturbs the screen; switching Spaces is not.*
- **Where:** `raiseWindowOnSpace`, `raiseTargets`, the `win:` click id, `hookSessionEntries`,
  `screenEntries` — `v60`.

### D87. Find an application by EXACT name, never with `hs.application.get`
- **Decision:** the click path resolves an application by scanning
  `hs.application.runningApplications()` for an exact name match (`appByExactName`).
  `hs.application.get(name)` is not used for this and should not be.
- **Why — measured 2026-08-07, with both applications running:**
  **`hs.application.get("Code")` returns Xcode.** Its lookup is fuzzy, and `Code` matches
  `Xcode`. So `v60`, which had just been rewritten to activate the owning application,
  activated **Xcode** on every click of a VS Code session line — and since Xcode had no
  visible window in front, the symptom Peter reported was the worst kind: *"clicking on either
  does nothing"*. `hs.application.get("com.microsoft.VSCode")` resolves correctly, but a
  bundle id is another thing to keep right per app, and the exact-name scan needs no
  configuration at all.
- **The cost is a few dozen string compares**, once per click. Nothing about this is hot.
- **A last resort was added at the same time:** if activating the app does not bring us to its
  Desktop within three tries, `gotoSpace` is called anyway. Landing on the right Desktop is
  the part that must not fail; raising the exact window is a nicety.
- **Where:** `appByExactName`, `raiseWindowOnSpace` — `v61`.

### D88. Every Desktop switch is verified, because `gotoSpace` fails silently
- **Decision:** clicking anything that changes Desktop goes through `gotoSpaceVerified`, which
  calls `hs.spaces.gotoSpace`, checks `activeSpaceOnScreen` 0.45 s later, and **repeats the
  call up to twice** if it did not land. The screen that owns the target Space is looked up
  first, so the right display is interrogated on a two-display Mac.
- **The measurement, 2026-08-07.** Eight switches in a deliberately jumpy order, each verified
  by reading back the active Space:

  ```
  asked 6    got 12   *** WRONG ***
  asked 295  got 12   *** WRONG ***
  asked 9    got 9    ok
  asked 205  got 205  ok
  asked 7    got 7    ok
  asked 145  got 145  ok
  asked 6    got 6    ok
  asked 12   got 12   ok
  ```

  **Two of eight landed on the wrong Desktop**, both at the start of the burst, and the same
  call worked when repeated. Peter had been living with this for weeks without being able to
  reproduce it: *"some of the time, when I click on a Desktop, it actually goes to another
  one. If I click again, it goes to the proper one but the behavior is sporadic."* The retry
  is precisely what he was doing by hand.
- **Why a retry rather than a longer wait:** the failures are not slow switches. The read
  after 0.9 s in the measurement above showed the machine sitting on a *different* Desktop
  entirely, not in transit to the right one. Waiting longer would have changed nothing.
- **Why the click path and not the ⌘⌃⌥S walk:** the walk restores Desktops through its own
  staggered chain, tuned for an animation that must not be interrupted, and it is not what
  Peter reported. Routing it through this too is Task **#17**, deliberately separate.
- **Verified after the change:** the same jumpy sequence, five switches, all landing first
  time — which shows the verification costs nothing when the switch works. It does **not**
  demonstrate the retry firing, because no failure occurred in that run; the retry is the same
  repeat call that was measured to work above.
- **Where:** `gotoSpaceVerified`, the `go:` click handler, `raiseWindowOnSpace`'s fallbacks —
  `v62`.

### D89. The ⌘⌃⌥S walk waits until it is actually on the Desktop it is reading
- **Decision:** each step of the walk checks `activeSpaceOnScreen` before reading, retries the
  switch up to three times, and **skips the read entirely** rather than reading the wrong
  Desktop. The restore chain at the end goes through `gotoSpaceVerified` (**D88**). A walk that
  needed a retry, or left a Desktop unread, prints one line to the console.
- **Why it matters more here than on a click:** a click that lands wrong is an annoyance you
  correct with a second click. A *read* that happens while parked on the wrong Desktop is
  silent and lasting: `hs.window.allWindows()` only contains the **current** Space's windows
  (**D3**), so the panel would label the Desktop it asked for using the windows of the one it
  is standing on — usually as empty. **A stale name beats a name copied off another Desktop**,
  which is why the failure path skips the read instead of guessing.
- **Measured, and the honest result is that the fault did not appear here.** Two full walks
  after the change, instrumented: **9 steps, 0 retries, 0 unread**, and **7+ steps, 0 retries,
  0 unread**. D88's 2-in-8 failure rate was measured on rapid back-to-back switches with no
  work between them; the walk does a full window snapshot at every step, which may be exactly
  the settling time the rapid case lacked. **So this is protection against a fault that is
  known to exist in the call, not a fix for one observed in this path** — and the console line
  is there so the next occurrence is not invisible.
- **The circumstantial case that it HAS bitten here**: the restore chain already carried a
  workaround written before any of this was understood — *"Firing every gotoSpace in a tight
  loop leaves macOS mid-animation on the first switch, and the second one swallows it — which
  restored the built-in display but left the iMac parked on the last Desktop the walk
  visited."* That is D88's fault described from the outside. The dwell that "fixed" it is still
  there; the verification now sits behind it.
- **Cost:** one `activeSpaceOnScreen` per Desktop, against a full AX window snapshot in the
  same step. Unmeasurable.
- **Where:** `M.scanAll`'s `readWhenThere`, its restore chain, `M.walkStats` — `v63`.
