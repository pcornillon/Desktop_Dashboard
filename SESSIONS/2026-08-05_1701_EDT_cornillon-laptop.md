# Session — 2026-08-05 17:01 EDT, cornillon-laptop
<!-- session: 10550087-d271-4745-acfd-5e21e6afd17b -->

Lane: `desktop_dashboard.lua` diagnosis (no code changes yet).

## P1 · 2026-08-05 17:12 EDT · why "3-way analysis" sticks, and why MacDown names nothing

Peter, after a laptop restart and a ⌘⌃⌥S: Desktop 6 shows **3-way analysis** with no
windows open on it; opening `CLAUDE.md` (claude-config) there in MacDown did not change it;
moving Desktops around carried the name with the Desktop; moving that MacDown window to a
newly created Desktop drew the MacDown icon but never the name `claude-config`, rescan or
not.

**Two separate causes, both verified.**

1. **The sticky name is a manual override, and that is by design.** `M.nameCurrent()`
   (⌘⌃⌥N) on a Desktop with no live session writes `overrides[sid] = txt`, and the draw
   path reads `overrides[sid] or labelCache[sid]` — an override wins over detection for
   ever, windows or no windows. Read from
   `~/.hammerspoon/desktop_dashboard_state.json`: the LG Ultra HD screen's position-5 entry
   is `name "3-way analysis", manual true, windows []`. (The same file's `projects` map
   holds the unrelated project rename
   `three-way_sst_error_analysis_manuscript → "3-way SST analysis"`.) It follows the
   Desktop on a reorder because `overrides` is keyed by Space id, which travels with the
   Desktop for the login session; across a reboot it is restored by screen + position
   instead (**D16**), so a reorder made before quitting would land it elsewhere. Cleared by
   ⌘⌃⌥N + empty string.

2. **`M.docApps` names an app that does not exist: `"MacDown 3000"`.** Measured live
   through the `hs` CLI on this machine: `hs.application.runningApplications()` reports the
   app as **`MacDown`** (bundle `com.uranusjr.macdown`, `CFBundleName` `MacDown`, 0.7.3).
   `readSpaceFrom` asks for a document only when `M.docApps[app]` is set, so every MacDown
   window returns `doc = nil`, `projectOfWindow` returns nil, `projHits` stays empty, and
   **D75**'s rule 1 can never fire for MacDown. The Desktop falls through to the app rule
   and draws the icon — exactly what Peter saw.

   MacDown itself is not at fault: opened a scratch `macdown_probe.md` in it and read
   `AXDocument` = `file:///…/macdown_probe.md`, so the path arrives intact once the
   allowlist key matches. Probe window closed afterwards.

   `"MacDown 3000"` has been in the file since the initial import (`8ec045a`, v15). It was
   harmless until yesterday: before **D75** a Desktop could still be named from a window
   title or a Finder path, so the dead allowlist key never showed. Making a document the
   only evidence exposed it.

   Fix proposed, not applied: add `["MacDown"] = true` to `M.docApps`. Asked whether to
   keep the `"MacDown 3000"` key as well (in case the iMac's copy really is named that) or
   replace it.

Also raised, not acted on: the SessionStart hook reports **session `8006f23a`
(ended 2026-08-04 22:01 EDT, 8 prompts) has no session log at all**. Nothing backfilled.

## P2 · 2026-08-06 11:19 EDT · fix MacDown, audit `M.docApps`, and give the name to the project

Peter: fix the MacDown failure; do the audit; and fix the naming — *"when a window is named,
the alias is associated with the project… When rescanning, check to see if a Desktop with no
claude running and the other condition, which writes the project name, to which the current
name applies is present. If neither of these, remove the name."* He also asked what ASK 3
meant, and said he thought an open `.md` on a session-free Desktop should already give it
the project name.

**His memory of the rule was right — there is no other condition.** D75's rule 1 is exactly
that, and the MacDown key is the only reason he had never seen it fire. Told him so rather
than inventing a second mechanism.

**Task #8 — `M.docApps`.** Added `["MacDown"] = true`, kept `"MacDown 3000"` in case the
iMac's copy is named that. Audited every key against the `.app` bundles in `/Applications`,
`/System/Applications` and `~/Applications`: the reported name is the bundle's **display**
name, not `CFBundleName` (which says `Word`, `Chrome`, `Code`). Twelve keys correct, four
uncheckable here (`PyCharm`, `Emacs`, `BBEdit`, `Nova` — not installed), `Code` dead but
harmless. Installed-and-document-bearing but absent, deliberately not added because each
costs an AX read per window (D5): eight `MATLAB_R20xx`, `Microsoft PowerPoint`,
`OmniGraffle`, `draw.io`, `yEd`, `Papers`, `Inkscape`, `Dia`, `Eclipse`, `R`. Put to him as
an ask.

**Task #9 / D76 — a name belongs to a project.** ⌘⌃⌥N now renames a project on every line:
the session group's (D67) or the top-ranked project whose documents are open there (D75).
On a Desktop with neither it refuses with an alert. The `overrides` table, its `manual` flag
on disk and its restore path are deleted, which is also the migration — a pre-`v53` override
is skipped on load, so `3-way analysis` should disappear by itself. ⌘⌃⌥N calls `scanActive`
first, so a document opened since the last read still counts. Existing overrides are **not**
promoted to project names, on the same reasoning Peter accepted for Task #5.

**Verified:** `loadfile` clean; a sandboxed `dofile` returns `v53` with `nameCurrent` a
function and `docApps.MacDown` true; no `overrides` reference survives outside the migration
comment. **Not verified: any of it running.** It needs a Reload Config, and STATUS.md's
active thread now carries the five-step test.

Also written: **D76**, Tasks **#8** and **#9**, the `M.docApps` gotcha in `CLAUDE.md`, five
passages in `README.md`, and `CLAUDE.md`'s ⌘⌃⌥N paragraph. `v52` → **`v53`**.

On ASK 3, re-explained: session `8006f23a` ran 8 prompts on 2026-08-04 and never opened a
session log, so `SESSIONS/` has no record of it. Nothing backfilled, and nothing done about
it — it is his call whether to reconstruct it from the transcript.

## P3 · 2026-08-06 12:47 EDT · what does the Dashboard depend on, and then run it

Peter: does this project depend on Dropbox, and what does a machine need beyond this folder
and Hammerspoon? Plus, in the same prompt: **D76 confirmed as drafted**; what exactly the
Dashboard does with `M.docApps`; reload and run the test now; reconstruct the missing
session log; explain "the header step"; and auto-disable the Dropbox watch.

**The dependency answer, all read from the code today.** Dropbox: **no**. Required is
Hammerspoon with Accessibility, this folder anywhere plus a three-line `init.lua`, and macOS
built-ins (`/bin/sh`, `osascript`, `scutil`, `open`). Then one requirement per dot: `git` for
the git dot; Terminal plus Automation permission for the session dots; the hook registered
in `~/.claude/settings.json` **and `jq`** for the red dot. Network only on ⌘⌃⌥g.

**Two faults fell out of writing that down**, both fixed as Task #10:

- The *receiving* half of the cross-machine alert was on by default against a hard-coded
  `~/Dropbox/…` path, so a Dropbox-less machine polls a directory that cannot exist every
  20 s, plus a path watcher that never attached — invisible because both are `pcall`-wrapped.
  Now gated on the directory **or its parent** existing (**D77**).
- The `INSTALL` block in the code's own header said *"Copy this file to
  ~/.hammerspoon/desktop_dashboard.lua"* — the stale-copy bug of 2026-07-27 written down as
  advice, contradicting `INSTALL.md`, `CLAUDE.md` and D64 (**D78**). This was "the header
  step" Peter could not place: the big comment block at the very top of the `.lua`.

**Reported, not fixed:** without `jq` on the hook's `PATH` the hook writes no state file and
exits 0 — the red dot silently never lights. On this laptop `jq` is Anaconda's copy.

**The live test — the first time any of v53/v54 has run.** Reloaded to `v54`, then:

- **MacDown, A/B on the same two windows.** Saved by `v52` at reload: `TASKS.md` and
  `RESULTS_region_season_sigma.md`, both `doc=''`. Saved by `v54` minutes later: both with
  full paths under `three-way_SST_error_analysis_manuscript`. The allowlist key was the only
  thing between MacDown and D75's rule 1.
- **⌘⌃⌥S over all nine Desktops.** Desktop 7 `MacDown` → **`MODIS_L2_Manuscript`** (from
  `DOCS/outline.md`), Desktop 8 `MacDown` → **`three-way_SST_error_analysis_manuscript`**
  (from its `CLAUDE.md`). Both were Desktops whose only window is MacDown, so before today
  they could only ever have shown the icon.
- **The migration.** No `manual` key survives anywhere in the state file and `3-way analysis`
  is gone. Desktops 5, 6, 8 and the laptop screen now carry the real project name, which
  `displayName` draws under his existing project alias **3-way SST analysis** — so the name
  he typed on one Desktop now appears on every Desktop that project is actually on. That is
  D76 doing exactly what it claims.
- **Not tested:** ⌘⌃⌥N itself, either branch. It opens a modal dialog that would block
  Hammerspoon waiting on input, so it is left for Peter — two keypresses.

A false alarm worth recording: the ⌘⌃⌥S walk *looked* wedged at "Desktop 4 (4/9)" across
twelve polls, which is the exact signature of the GC'd-`doAfter` bug in `CLAUDE.md`'s
gotchas. It was not — the polls were faster than one Desktop's dwell. `dd.status` was `nil`
and the walk had restored every Space. Checked before reporting, rather than reporting the
symptom.

**Task #11:** reconstructed `SESSIONS/2026-08-03_2058_EDT_cornillon-laptop.md` for session
`8006f23a` — 8 prompts, 20:58–22:47 EDT, `v47`–`v50`, the clickable legend and the
cross-machine alert. Timestamps and prompts from the JSONL, outcomes quoted from the Stop
hook's prose log, commits from `git log`; silences left as silences. Its `claude-config` half
(`4d4e6fb`) still has no log in that repo — flagged, not acted on.

## P4 · 2026-08-06 14:32 EDT · too many asks; ⌘⌃⌥N works; TeXShop

Peter confirmed D77 and D78, and then made the point behind them: *"I'm getting too many
asks from you, especially ones like D77, which I don't completely understand but confirm
anyway. I know that I should probably understand them but there are only so many hours in
the day."* He asked for a **`DECISIONS`** section immediately above the asks, holding what I
would previously have asked him to confirm but where he would be very unlikely to disagree —
and asks reserved for where he might.

**Recorded as D35 in `claude-config`**, since it is a global working rule, with the ask
bullet in `global/CLAUDE.md` rewritten under it. That is a second repo, so per **D34** this
session also wrote a `LOG.md` line there pointing back at this log. The line I drew: a
capability removed, his time spent, a write to a repo he did not name, or anything with no
way back is still an `ASK`; a helper's name, a measurement closing a documented tension, or
following a rule he already wrote goes in `DECISIONS`.

**⌘⌃⌥N works properly** — his words. Both branches, the last untested piece of D76.

**Task #2 closed after five days, with the measurement it was waiting for.** TeXShop's
`AXDocument`, via the `hs` CLI against the live Hammerspoon, two reads per window:
`main.pdf` (20 pages) **0.23 ms cold / 0.09 warm**, `main.tex` **0.10 / 0.09**, against
MacDown's 0.10–0.20 and Preview's 0.12–0.19. **Indistinguishable.** D5's fear is
Electron/Office/Java apps; TeXShop is native Cocoa and behaves like it. So TeXShop went into
`M.docApps` with BibDesk, PowerPoint and OmniGraffle (**D79**, `v55`), closing **D32's live
tension** — the pull's open-file check could not see a LaTeX file open in the one repo type
he writes manuscripts in — and the README gap that documented it.

**Verified live after a reload:** TeXShop's two windows on Desktop 5 report
`LATEX/main.tex` and `LATEX/main.pdf`; before the reload they reported nothing. Worth
knowing: TeXShop contributes **two** window-votes for one open document, since the source
and its PDF preview are separate windows. Harmless, and arguably right.

**I had to correct my own audit.** Task #8's sweep walked only the top level of
`/Applications`, `/System/Applications` and `~/Applications` — so it missed every app in a
subfolder, which on this machine is the entire `/Applications/TeX/` toolchain (TeXShop,
BibDesk, LaTeXiT, TeX Live Utility) plus Adobe Acrobat. Redone with `find -maxdepth 3` and
written up as Task **#12**. Peter's question — *"Already open to TeXShop?"* — is what exposed
it; the audit that said "no" had never looked in the folder TeXShop lives in.

TeXShop was launched only to measure it, and quit afterwards.

## P5 · 2026-08-06 16:20 EDT · what is `jq`; push; and a colleague who doesn't use Terminal

**Pushed both repos**, as asked. `Desktop_Dashboard` `487c8fa` (`v53`–`v55`, D76–D79, Tasks
#8–#12, both session logs) and `claude-config` `7f36146` (D35 and the working-rule change).
Only the paths this session touched were staged, per the concurrent-session rule.

**`jq` explained**, since Peter asked what it is rather than answering: a small command-line
JSON reader, not shipped with macOS. `claude-dashboard-state.sh` uses it to pull `.cwd` and
`.session_id` out of the JSON Claude Code pipes to the hook, and to write the state file the
red dot reads. Every call is guarded by `command -v jq`, so a machine without it degrades to
**no state file at all, silently**. That is a footnote here and a real problem for a new
install — which is what the second half of this prompt turned out to be about.

**The colleague's problem: he runs claude in iTerm and Cursor, and the panel shows nothing.**
His session's analysis was pasted in. **Checked it against the code rather than accepting
it** — it is correct, and on the one point it understates the problem:

- A session line comes only from the Terminal.app AppleScript poll (`CLAUDE_TITLE_SCRIPT`,
  `if application "Terminal" is running`). Confirmed.
- `sessionGroupsFor` reads `sessionsBySpace`, which is built from that poll; `claudeHooks`
  only *colours* a line that already exists. Confirmed.
- **It also applies to the `T#` list**, which his session did not say: `sessionEntries`
  iterates the same `sessions` table, so a non-Terminal session is missing from the sessions
  view too, not just from the Desktop lines. There is no view of the panel where it appears.
- `readHookStates` collapses every hook file to `repo → state`, discarding per-session
  identity — so even the data that *is* there is thrown away before anything could draw it.

**What the hook files actually hold**, read from
`~/.hammerspoon/claude_state/<session-id>.json`: `state`, `cwd`, `repo`, `at`, `message`.
Terminal-agnostic — Claude Code writes them itself, from inside the session, whatever it is
running in. Cursor sessions are already writing them on the colleague's machine.

**Proposal drafted for Peter: a hook-only sessions list.** Keep the per-file records instead
of collapsing them, and draw the ones the Terminal poll did not account for as `T#` lines
with dots but **no Desktop line** — which respects D67 rather than bending it, since a hook
file genuinely does not know which window it belongs to. Dedupe wants one small hook change:
write `$TERM_PROGRAM` into the state file. **Verified in this session's own environment:
`TERM_PROGRAM=Apple_Terminal`**, so the hook inherits it and the key is free.

That helps iTerm, Ghostty, kitty, Cursor, VS Code and ssh sessions in one change. A separate,
narrower option is extending the title poll to iTerm2 for real Desktop placement — **two
things would have to be measured first and neither can be measured here** (no iTerm on this
machine): whether iTerm2's AppleScript enumerates windows on inactive Spaces the way
Terminal's does, and whether its window `id` is the same id `hs.spaces` uses, which D67 had
to establish for Terminal.

Nothing built — put to Peter as a choice between implementing it here and writing it up as
an issue for the colleague to work from.

## P6 · 2026-08-06 17:05 EDT · build it here: no `jq`, and sessions in any terminal

Peter: *"I would prefer to do whatever is needed here. If he needs it others will likely need
it as well."* And on `jq`: *"the better option is to do the rewrite — better if we can make
it work in the same way without requiring the user to load another tool."* Plus two
questions, answered below.

**The hook now has no external dependency (D80).** `jq` is gone rather than made optional:
`json_get` (awk) parses the payload, `json_esc` (bash string operators plus one awk pass for
C0 controls) writes it. Every former call site replaced — the payload parse, the trace line,
the D19 nudge filter's previous-state read, the message, the state file and the Dropbox
marker.

- **It is 4× faster, measured**: 20 invocations each, same payload and sandboxed `HOME` —
  `jq` **121–128 ms**, awk **33 ms**. That was being paid on every prompt of every session.
- **`\uXXXX` decoding was a bug I introduced and caught in test.** The first draft turned
  every escaped character into `?`, which silently corrupts a path. Fixed by decoding to real
  UTF-8, surrogate pairs included — awk emits raw bytes from a decimal `%c`, verified
  (`226,156,179` → `✳`). Claude Code's own payloads do not escape non-ASCII, so this is belt
  and braces; it cost six lines.
- **The test suite is real and committed**:
  `ISSUE_ANALYSES/Python/test_claude_dashboard_hook.py`, run with `PATH` stripped of `jq` and
  asserting that. Hostile paths, emoji, C0 bytes, a nested decoy `cwd`, the full
  working→waiting→working→done→nudge→gone sequence, and four kinds of degraded input.

**Non-Terminal sessions now get a line (D81).** `readHookSessions` keeps the per-file records
`readHookStates` was throwing away; `hookSessionEntries` draws them in the `T#` list with the
dots, the project, the question and the terminal's name — and **no Desktop line**, because a
hook file knows the repo and not the window. They show even in Desktops mode, in a
`Sessions elsewhere:` block. The hook writes `$TERM_PROGRAM`, so `Apple_Terminal` is excluded
and the two paths cannot draw one session twice.

**Verified live, and this is the useful part for future work.** A fake `Cursor` state file
was written into `~/.hammerspoon/claude_state/`, and the panel **photographed**:

- `hs.screen:snapshot()` returns the desktop **without** Hammerspoon's canvases — it looked
  exactly like "the panel isn't drawing" when it was. Cost twenty minutes.
- `hs.window.snapshotForID(<panel's kCGWindowNumber>, true)` **works**. The panel is a
  layer-3 CoreGraphics window owned by Hammerspoon; find it in `hs.window.list(true)`.
- It drew `T4 ● ● MODIS_L2_Manuscript · Cursor` with a red claude dot, a green git dot, and
  `May I edit orbit_rea…` beneath. Recorded in `CLAUDE.md`'s Testing section, because it
  turns "does it draw" from a question for whoever is at the machine into something a session
  can check.

**The deployed hook was synced.** `settings.json` runs `claude-config/hooks/…`, so editing
this repo's copy alone would have changed nothing — the trap Task #1 exists for, hit again.
Copied, `chmod +x`, `diff` clean. Peter's own sessions now write `term` too.

**His two questions.** Yes: a Cursor session shows in the sessions (`T#`) list, not the
Desktop list, and that is the ceiling for Cursor. And yes — installing iTerm here is exactly
what would let the two open measurements be made.
