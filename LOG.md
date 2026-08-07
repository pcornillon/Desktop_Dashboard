# LOG.md — Desktop Dashboard

One line per prompt, appended live, read top to bottom to see what has been done.
`★` marks a substantive entry. Each entry carries a session key — `` `<HHMM>_<host>` `` —
naming the session log in `SESSIONS/` it came from.

**This file starts on 2026-08-03**, when the repo was migrated onto the project spine.
Everything before that is in the git history and in `PRE_CONVERSION/`; it is deliberately
**not** backfilled, because there are no session logs to reconcile it against and an
invented index is worse than a short one.

---

## Spine migration

- ★ **P1** `2255_satdat1` · 2026-08-03 22:55 EDT · migrate this repo onto the project spine
  (`claude-config` #11/#19)
  → `DECISIONS.md` created with **D1–D64**, lifted out of `CLAUDE.md` with every
    measurement intact; `CLAUDE.md` cut from 556 lines to architecture + layout and given
    its **What / Produces / State** block; `docs/`→`DOCS/`, `archive/`→`PRE_CONVERSION/`
    (D63); `SESSIONS/ LATEX/ ISSUE_ANALYSES/` added empty; `STATUS.md`, `TASKS.md`,
    `LOG.md` written fresh. **Found by `diff`, not assumed:** this repo's
    `claude-dashboard-state.sh` is ~90 lines behind the copy `~/.claude/settings.json`
    actually runs → Task #1, blocked on Peter

## Desktop labels vs. claude sessions

- ★ **P1** `1231_satdat1` · 2026-08-04 12:31 EDT · an open `CLAUDE.md` from another project
  steals a Desktop's name from its live claude session; proposed rule — one line per session
  → diagnosed: `detectLabel` rule 1 outranks rule 1.5, and the claude dot is joined **by
    name** rather than by window; the gray dot is `withPlaceholders`, not a state. Measured:
    Terminal's AppleScript window id **is** the `hs.spaces` id, and `hs.spaces.windowSpaces`
    places 13 windows in **2.9 ms**, inactive Spaces included — so the join is cheap and
    live. Five asks back to Peter; no code changed
- ★ **P2** `1231_satdat1` · 2026-08-04 12:36 EDT · no yellow dot although a session is
  working, and ⌘⌃⌥s doesn't help
  → **a second, unrelated fault, found by `ps` not by reasoning**: the claude-title poll
    was deadlocked — an `osascript` child of Hammerspoon hung **5 h 21 min**, blocked in
    `exit()`/`fflush` writing to an undrained pipe. `refreshClaudeStates` guards with
    `if claudeTask then return end` and has **no timeout**, so every poll since ~07:10 EDT
    did nothing, `M.scanAll` included. Killed the child; the next poll hung identically.
    Narrowed by four control tests to the **Hammerspoon→app AppleEvent path**; TCC and
    descriptor exhaustion excluded. Loaded module is **v41**, repo is v46 → proposed a
    watchdog task; nothing written yet
- ★ **P3** `1231_satdat1` · 2026-08-04 12:57 EDT · restarted Hammerspoon, panel still says
  "(no claude sessions found)" — screenshot shows **no dots at all**
  → **root cause, and P2's AppleEvent conclusion is superseded**: `hs.task` deadlocks when a
    child writes more than **~512 bytes** to stdout — Hammerspoon does not drain the pipe
    until exit and a macOS pipe starts at 512 B. Measured: 100/300/500 B return,
    700/900/1100/1500 B hang for ever. The title script emits ~900 B at 13 Terminal windows;
    four of the six `hs.task` sites normally exceed it, so the **whole async layer** is down,
    dots included. A restart cannot help. **Fix verified:** a streaming callback carried all
    2001 B of a child that otherwise hangs. Hammerspoon 1.1.1 (6936), macOS 14.1.1.
    Restarting also answered the version question — the panel now loads **v46** by itself
- ★ **P4** `1231_satdat1` · 2026-08-04 13:10 EDT · "Ask 1. yes. Ask 2. yes." — implement the
  fix and log it
  → **v47**: one `runTask` helper (streaming accumulator + watchdog + `M.taskTimeout` 20 s)
    replacing all five output-capturing `hs.task.new` calls; `ghWatchdog`/`pullWatchdog`
    deleted, `M.stop` cancels live watchdogs, the pull's pre-check gains a timeout it never
    had, and a double-report in the pull goes away. **Verified after reload:** v47 loaded,
    no hung child, `claudeStates` = 5 (`desktop_dashboard: working`), `gitStates` = 15 —
    both empty before. → **D65**, Task **#4** `done`
- ★ **P5** `1231_satdat1` · 2026-08-04 13:34 EDT · answers to the three design asks: no doc
  line beside a session, broader evidence capped at two projects, one line per **project**
  rather than per session
  → Task **#5** written with the full spec, `blocked` on two points: whether a project
    rename is global or per-Desktop, and whether a lone Finder window may name a Desktop —
    the latter reverses **D7**, whose false positive was measured 2026-07-28. `D66` drafted
    and quoted but **not** written until those two are answered
- ★ **P6** `1231_satdat1` · 2026-08-04 13:43 EDT · both asks accepted; three fault reports
  with screenshots — the session list toggles between two views every ~10 s
  → two of the three were the **unfixed** naming rule (Task #5), not new. The third was
    **mine, from v47**: `hs.task` **splits its output between its two callbacks** (measured:
    511 streamed + 403 at termination) and **drops any chunk ending inside a multi-byte
    character** (511 bytes lost outright) — and v47's helper preferred the streamed half.
    Three earlier hypotheses were each killed by measurement before this one. Fixed by
    capturing to a **file** instead of a pipe → **v48**, **D66**, Task **#6** (revises #4).
    Verified: 62 consecutive samples, no truncation, against 8 of 56 before. **D67** written
    for the naming rule now that both its open points are settled
- ★ **P7** `1231_satdat1` · 2026-08-04 14:15 EDT · "Ask 1. Yes." — build D67
  → **v49**, Task **#5** `done`. A session is now tied to its Desktop by its **window**
    (`hs.spaces.windowSpaces`), collapsed **one line per project**; a Desktop with no session
    is named after the projects its windows belong to — Finder counted, top two by window
    count — drawn **orange** and carrying **no dots**. `claudeStateFor`, the string match at
    the root of the whole fault report, is **deleted**. Click-to-cycle and a global,
    project-scoped ⌘⌃⌥N added. **Verified by calling `screenEntries` directly:** Desktop 13's
    two AGU sessions plus one MODIS_L2 draw as **two lines** under one Desktop, exactly the
    case Peter reported. Click and ⌘⌃⌥N need a mouse and are untested. **Reported:** a
    ⌘⌃⌥N Desktop name is ignored on a Desktop that has a session — `3-way_analysis` reverts
    to the long repo name until re-applied as a *project* name
- ★ **P8** `1231_satdat1` · 2026-08-04 14:40 EDT · project name colour, then merge the two
  machines
  → **teal**, not the requested dark blue: the laptop's own incoming feature claims blue for
    clickable legend words and the legend *says* so, and orange collided with the amber
    status/stale lines → **D74**, `v50`. Then the merge: trial-merged in memory first (no
    files touched), **three conflict hunks** — version line, `M.stop`, one `CLAUDE.md`
    block. The laptop's **59 lines of decision prose** were lifted into `DECISIONS.md` as
    **D68–D73** rather than discarded with the conflict, measurements intact. Its lone
    direct `hs.task.new` routed through `runTask` (D65). → **v51**; both feature sets verified
    live in one build. **Task #1 closed by the merge**: the hook is now byte-identical to
    the copy `settings.json` runs
- ★ **P9** `1231_satdat1` · 2026-08-04 15:15 EDT · reverse the colours, and stop letting
  Finder or a window title name a project
  → **v52**, **D75**, Task **#7**. Teal moves to the **session** lines and everything else
    goes white, so the panel emphasises what is running. **Only an open document under a
    repo root names a project** — Finder, the repo-name-in-a-title rule and the
    token-overlap fallback are all deleted, and `M.noRepoHintApps` plus the `ctx` hint
    machinery went with them, since they existed only to feed the deleted rules. Answered
    his question first with the measured surface: the title rule admitted **every app except
    Claude, ChatGPT, six browsers, Finder and terminals** — Mail, Slack, OneNote, MATLAB,
    Messages. Verified by rendering: five Desktops teal with dots, five white from documents,
    the title-guessed ones now showing icons
- **P10** `1231_satdat1` · 2026-08-04 15:32 EDT · "leave it as any document"
  → confirms D75's one open point; **no code change** — that is what `v52` already does.
    D75's live tension replaced with the settled ruling and a "do not narrow this without
    asking" note; Task #7's open line closed
- ★ **P1** `1701_cornillon-laptop` · 2026-08-05 17:12 EDT · a Desktop keeps a name it should
  have lost, and MacDown never names one
  → two causes, both measured, **no code change yet**. The sticky name is `overrides[sid]`
    from ⌘⌃⌥N — it beats detection for ever and is in the state JSON as
    `manual true, windows []`. The missing one is a dead allowlist key: `M.docApps` has
    `"MacDown 3000"` and the app is called **`MacDown`** (verified via the `hs` CLI), so no
    MacDown window is ever asked for its document and **D75**'s rule 1 cannot fire.
    `AXDocument` itself works — probed live. Dead since `8ec045a`; invisible until D75 made
    a document the only evidence
- ★ **P2** `1701_cornillon-laptop` · 2026-08-06 11:19 EDT · fix MacDown, audit the allowlist,
  and give the name to the project
  → **v53**, **D76**, Tasks **#8** and **#9**. `["MacDown"]` added to `M.docApps` — the key
    was `"MacDown 3000"`, so that editor could never name a Desktop; the rest of the list
    audited against the installed bundles. ⌘⌃⌥N now renames a **project** on every line and
    refuses where there is none: the `overrides` table, its `manual` flag and its restore
    path are deleted (D76 supersedes **D16**), and skipping `manual` on load is the
    migration. Verified only by a sandboxed load — **nothing exercised live yet**
- ★ **P3** `1701_cornillon-laptop` · 2026-08-06 12:47 EDT · what does it depend on? → two
  faults, then reload and test
  → **v54**, **D77**, **D78**, Tasks **#10** and **#11**. Answering "does this need Dropbox?"
    (no) turned up a Dropbox-less machine polling a phantom directory every 20 s for ever,
    and an `INSTALL` block in the code telling you to do the thing that caused the
    stale-copy bug. Both fixed. **Then the first live run of v53/v54**: MacDown's documents
    are read — the same two windows saved `doc=''` under v52 and full repo paths under v54 —
    and Desktops 7 and 8 went from `MacDown` to `MODIS_L2_Manuscript` and
    `three-way_SST_error_analysis_manuscript`. The manual override is gone from the state
    file and `3-way analysis` with it
- **NOTE** · 2026-08-06 · session `8006f23a` (2026-08-03, 8 prompts, `v47`–`v50`) never
  opened a log; it was reconstructed on this date as
  `SESSIONS/2026-08-03_2058_EDT_cornillon-laptop.md`. Its eight entries are **not** inserted
  above: this file is append-only and chronological, and back-dating them would break both.
  Task **#11**
- ★ **P4** `1701_cornillon-laptop` · 2026-08-06 14:32 EDT · fewer asks; and TeXShop, at last
  → **v55**, **D79**, Tasks **#2** (closed after five days) and **#12**; **D35** in
    `claude-config`, which rewrites the ask rule — responses now carry a `DECISIONS` section
    above the asks and what is in it is treated as agreed. TeXShop's `AXDocument` **measured
    at 0.10–0.23 ms**, the same as MacDown and Preview, so it joined `M.docApps` with
    BibDesk, PowerPoint and OmniGraffle, closing D32's live tension and the README gap.
    Verified live: its `main.tex` and `main.pdf` windows now name Desktop 5. **Task #8's
    audit was wrong** — it walked only the top level of `/Applications`, missing the whole
    `/Applications/TeX/` toolchain; redone and corrected in #12
- ★ **P5** `1701_cornillon-laptop` · 2026-08-06 16:20 EDT · what is `jq`; push; and a
  colleague whose sessions never appear
  → pushed `487c8fa` here and `7f36146` in `claude-config`. `INSTALL.md` gained the two
    prerequisites that were never written down — **`jq` for the red dot** (macOS ships none,
    and the hook fails silently without it) and **Terminal.app for session lines**. Checked
    the colleague's session's analysis against the code: correct, and it **understates** the
    problem — the `T#` list is Terminal-only too, so there is no view where a Cursor or iTerm
    session appears. Proposed a **hook-only sessions list** built from
    `~/.hammerspoon/claude_state/*.json`, dots but no Desktop line, deduped on
    `$TERM_PROGRAM` (verified present in the hook's environment). Nothing built — Peter's
    call
- ★ **P6** `1701_cornillon-laptop` · 2026-08-06 17:05 EDT · make it work for the colleague:
  no `jq`, and sessions in any terminal
  → **v56**, **D80**, **D81**, Task **#13**, `ISSUE_ANALYSES/hook_without_jq/`. The hook is
    **dependency-free** — `awk` and bash replace `jq`, which macOS does not ship and whose
    absence silently killed the red dot — and **4× faster with it: 33 ms against 121–128**.
    Non-Terminal sessions (iTerm, Ghostty, kitty, Cursor, ssh) now get a `T#` line from their
    hook file with dots and the terminal's name, and no Desktop line. Verified live from a
    fake `Cursor` state file by photographing the panel with `hs.window.snapshotForID` —
    `hs.screen:snapshot()` cannot see our canvases. Deployed hook synced to `claude-config`
    and diffed
- **P7** `1701_cornillon-laptop` · 2026-08-06 18:05 EDT · how do I install iTerm
  → `brew install --cask iterm2`; brew already present and the cask resolving, both checked.
    No code change
- ★ **P8** `1701_cornillon-laptop` · 2026-08-06 18:20 EDT · iTerm installed — measure it, then
  make it first-class
  → **v57**, **D82**, Task **#14**. Peter's *"no claude session shows"* had two causes and
    the deeper one was that **iTerm was not read at all**; the hook-only path could not cover
    it either, because the hook fires on prompts and he had only started the session. **Both
    blocking measurements passed**: iTerm2's AppleScript returned a window on Space 205 while
    12 and 532 were active, and `hs.spaces.windowSpaces(26169)` accepted its window id. So
    the poll now reads both terminals in one script, and **iTerm is the better source** —
    `variable named "session.path"` IS the cwd, where Terminal's has to be parsed off a
    composed title. Photographed: `Desktop 8 ● ● → opendap-registry` with the iTerm icon, and
    `T5` in the sessions list
- ★ **P9** `1701_cornillon-laptop` · 2026-08-06 19:05 EDT · fire the hook on session start too
  → **D83**: a fifth registration, `SessionStart` → `idle`, so a session that has been opened
    but not yet prompted exists on the panel — the gap Peter hit in iTerm. No claude dot: a
    session that has never run anything has not finished anything (D21). No hook code change
    was needed; `settings.json` in `claude-config` and `INSTALL.md` step 2 carry it. Also
    answered how to start claude inside VS Code, which lands as a `· vscode` line under
    D81 — no Desktop, because VS Code is Electron
- **P10** `1701_cornillon-laptop` · 2026-08-06 22:55 EDT · am I running claude in
  opendap-registry?
  → no, and shown rather than asserted: two `claude` processes, `cwd=Desktop_Dashboard` and
    `cwd=MODIS_L2_Manuscript`. The screenshot was VS Code's chat sidebar, which had failed
    with "Language model unavailable"; no terminal was open in the window
- ★ **P11** `1701_cornillon-laptop` · 2026-08-06 23:02 EDT · it shows as a file on the
  Desktop, as a session in the Terminal list
  → both lines were true and the panel was still failing him: D75's document rule named
    Desktop 8 white while D81's hook line carried the dots. Confirmed **`SessionStart` works
    and its payload carries a real `session_id`** — the file is `dc4407f2-…json`, not
    `nosession-<pid>` — which closed P9's open question. Put three options to him
- **P12** `1701_cornillon-laptop` · 2026-08-06 23:20 EDT · what would A do, and how does VS
  Code know which project claude is in?
  → it does not, and is never asked: the project comes from the session's own hook file, the
    window from one accessibility question about its open file. Named A's weakness rather
    than selling it
- ★ **P13** `1701_cornillon-laptop` · 2026-08-06 23:35 EDT · "I clicked go" — measure the
  window title
  → **the measurement killed option A**: VS Code reports `AXDocument = ""` while its terminal
    has focus, three reads running, so a file-based match would fail exactly when claude is in
    use. `AXTitle` is `opendap-registry`, stable — the workspace name
- **P14** `1701_cornillon-laptop` · 2026-08-06 23:50 EDT · does claude change project
  mid-session?
  → no: a session's directory is fixed at launch. Corrected my own sloppy "the link breaks",
    which read as though claude moved. Evidence: this session's own file has said
    `Desktop_Dashboard` all day while it edited `claude-config`
- ★ **P15** `1701_cornillon-laptop` · 2026-08-07 00:02 EDT · "go for it" — and an aside worth
  more than the thing it was an aside to
  → **Task #15**: record the window frontmost when a session starts, then place it by window
    ever after. Reads no titles, works for every terminal, D67-faithful. Logged, not built
- ★ **P16** `1701_cornillon-laptop` · 2026-08-07 00:10 EDT · "I don't see anything running" —
  he was right, I had described the work instead of doing it
  → **v58**, **D84**, Task **#16**. A′ built and photographed:
    `Desktop 8 ● ● → opendap-registry · vscode` in the session colour with the VS Code icon.
    Title matching is exact on an em-dash component, one Desktop or nothing
- ★ **P17** `1701_cornillon-laptop` · 2026-08-07 11:05 EDT · build Task #15 — and make
  clicking a VS Code session work
  → **v59**, **D85**, Task **#15** closed. The panel now records the window that was frontmost
    when a session started and places it by that window ever after — any terminal, no titles,
    D67-faithful — with two guards: the frontmost window must belong to the app the session's
    `term` names, and sessions predating the load are never captured. Clicking such a line
    raises its window (`raiseWindowOnSpace`, retried three times over a second), which
    `focusTerminalWindow` could not do. **A self-inflicted outage worth remembering:**
    `hookSessionEntries` called `placeHookSession` above its declaration, so `draw()` threw on
    every pass — blank panel, wedged ⌘⌃⌥S, clean console, the exact signature `CLAUDE.md`
    ascribes to a collected timer. Now a gotcha of its own
