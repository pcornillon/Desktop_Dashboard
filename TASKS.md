# TASKS.md — Desktop Dashboard

Numbered work list. Tasks are appended and **never reopened**: a follow-on change is a
new task that references the old one. Each carries a `Status:` line —
`todo` | `doing` | `blocked (on what)` | `done (YYYY-MM-DD)`.

This file starts at #1 on **2026-08-03**, when the repo was migrated onto the project
spine. The work that predates it is in the git history and in `PRE_CONVERSION/STATUS.md`;
it is **not** backfilled here, because inventing task numbers for finished work would
put fictitious entries in an append-only file.

---

## Task #1 — Decide which copy of `claude-dashboard-state.sh` is authoritative

**Status:** done (2026-08-04) — **the drift ended without the decision having to be made.**
The laptop's `73803a4` rewrote this repo's copy for the cross-machine alert (**D72**,
**D73**), and merging it here brought the file to **206 lines, byte-identical** to
`claude-config/hooks/claude-dashboard-state.sh` — the copy `~/.claude/settings.json`
actually runs, verified with `diff` after the merge. Anyone installing from this repo now
gets the same script this machine runs.

**The policy question below is still open and still Peter's**, because nothing stops the two
copies drifting again; only this instance of the drift is resolved. Reopen as a new task if
it recurs.

**Original entry, as written 2026-08-03:**

**The two copies have drifted, and the one this repo ships is the stale one.** Measured
2026-08-03 with `diff`:

| Copy | Length | Registered in `~/.claude/settings.json`? |
|------|--------|------------------------------------------|
| `Desktop_Dashboard/claude-dashboard-state.sh` | 104 lines | **no** |
| `claude-config/hooks/claude-dashboard-state.sh` | ~194 lines | **yes**, four times (`working`, `waiting`, `done`, `gone`) |

The `claude-config` copy carries an opt-in remote-alerting block — a Dropbox marker for
another Mac, plus ntfy and Pushover push, all **off** unless
`~/.claude/dashboard-notify.conf` exists — and hoists the `message` extraction out of the
state write so the alert can use it. This repo's copy has none of that.

**Two consequences, both real:**

- Anyone who installs by following this repo's `INSTALL.md` gets the older script.
- An edit made to the copy in this repo changes nothing on this machine, because nothing
  reads it.

**Three options; none has been applied.**

1. **This repo is authoritative** — `claude-config` syncs from it. Keeps the public repo
   self-contained; means the alerting feature has to live here, in a repo whose subject is
   a Hammerspoon panel.
2. **`claude-config` is authoritative** — this repo ships a copy refreshed from it. Keeps
   the repo installable, but the copy can drift again the moment anyone forgets.
3. **Delete this repo's copy** and point `INSTALL.md` at `claude-config`. The only option
   that cannot drift — but it makes the repo un-installable by anyone who does not also
   have `claude-config`, which is most people, since **this is the public repo**.

**That trade-off is the decision.** Do not pick one by tidying.

## Task #2 — Consider measuring TeXShop's `AXDocument` read

**Status:** done (2026-08-06) — **measured, and TeXShop is in.** 0.23 ms cold / 0.09 ms warm
against a 20-page `main.pdf`, 0.10 / 0.09 against `main.tex`, versus 0.10–0.20 for MacDown
and 0.12–0.19 for Preview. Indistinguishable from the editors already on the list, so it was
added rather than documented around: **D79**, `v55`. D32's live tension and the README gap
it created are both closed. The original reasoning follows, unchanged, because it is the
procedure for the next candidate.

`D32`'s live tension. TeXShop is a real editor for these repos and is invisible to the
pull's open-file check, so the check can report "nothing known to be open" while a
LaTeX file from that repo is open in front of you. It is deliberately not in `M.docApps`,
because that allowlist exists to keep slow `AXDocument` reads out of the read path
(**D5**), and **TeXShop has never been measured**.

Doing this means: time an `AXDocument` read against a TeXShop window with a large
document open, several times, and compare against the editors already in `docApps`. If it
is fast, add it and close the gap. If it is slow, record the number in D32 so the gap is
documented with evidence rather than with caution.

Not urgent — the gap is documented in `README.md`'s "What to be careful about".

## Task #3 — Retire the `sessions/` fallback in the guards (tracked in `claude-config`)

**Status:** blocked (on every repo being migrated)

Not this repo's work; recorded here only because this repo is one of the ones the
fallback exists for. `claude-log-guard.sh` and `claude-handoff-guard.sh` accept both
`SESSIONS/` and `sessions/` during the migration window. This repo now has `SESSIONS/`.
The fallback is removed in `claude-config`, as its own task, once every repo is done —
**the failure mode is silence**, so it must not be a quiet edit.

## Task #4 — Drain and time out every subprocess read (`runTask`)

**Status:** done (2026-08-04)

The panel's dots all went dead. Root cause, measured: **`hs.task` deadlocks on more than
~512 bytes of output** unless a streaming callback drains the pipe — see **D65** for the
measurements, the environment, and why one stuck child pinned its guard for 5 h 21 min.

**Done:** one `runTask(bin, args, timeout, done)` helper that streams output and times the
read out, plus `noteTaskStall` (console line, one alert per stall) and `M.taskTimeout`
(20 s). All five output-capturing `hs.task.new` calls now go through it — the claude title
read, the git status pass, the ⌘⌃⌥g query, the pull, and the pull's pre-check. The
hand-rolled `ghWatchdog` and `pullWatchdog` are gone; `M.stop` cancels any watchdog still
counting. `v46` → **`v47`**.

**Verified after reloading**, not assumed: `hs -c` reports `v47`, no `osascript` child is
left hanging, and the module's live state holds **5 claude sessions** (including
`desktop_dashboard: working`) and **15 git states**. Before the fix both tables were empty.

**Not done, and deliberately:** the "stale" marker on the panel itself. A timed-out read
now says so with an alert and a console line, but the dots simply keep their previous
values rather than being drawn as known-stale. That needs a rendering decision and belongs
with the Desktop-line redesign, not with this fix.

## Task #5 — Name a Desktop by its live claude sessions, and by its projects when idle

**Status:** done (2026-08-04) — built as `v49`; see the verification below

Replaces the rule that let an open document steal a Desktop's name from the live session
running on it. Specified by Peter on 2026-08-04; the measurements behind it are in the
session log for that day.

**The rule, in precedence order.**

1. **Desktops with live claude sessions are named by their sessions' projects, one line per
   PROJECT — not per session.** Three sessions on a Desktop, two in `Desktop_Dashboard` and
   one in `claude-config`, give **two** lines. A Desktop with three sessions all in one
   project stays **one** line.
2. **Nothing else is shown on such a Desktop.** Documents belonging to some other project
   do not earn a line of their own — explicitly rejected as too complicated.
3. **A Desktop with no live session is named by the projects its windows belong to, drawn
   in orange.** Evidence is broad: a document open under a repo root, a repo name in a
   window title, **and a Finder window parked in a repo**. Several projects are joined with
   ` / `.
4. **At most two projects are shown**, ranked by how many windows on that Desktop belong to
   each. Ties break on name, ascending, so the label cannot flicker between two equally
   ranked projects. No overflow marker is drawn — Peter asked for "just the two".
5. **A Desktop with neither is unchanged** — app, subject or `Utility`, with its icon row.

**Why orange exists at all — the point to keep in the code comment.** It does not mean "a
session is running here". It means **the Desktop is still set up for that project**: you
exited claude but left the windows, and tomorrow you want to find your way back and restart
it. That is the whole purpose of the state, and it is why the evidence is deliberately
looser than the session rule's.

**Interaction.**

- **Clicking a session line raises that project's terminal window** on that Desktop, which
  switches Desktops as a side effect. Where a project has several sessions there, clicks
  **cycle**: first click raises the first window, the next click the second, and so on.
- **⌘⌃⌥N on a session line renames the PROJECT**, not the Desktop and not the window,
  and that name is **global to the panel** — it reads the same wherever the project
  appears, and survives moving the session to another Desktop.
- **⌘⌃⌥N elsewhere** — an orange line or an app/icon line — keeps today's per-Desktop
  override (**D16**).

**The join that makes it possible, measured 2026-08-04.** Terminal's AppleScript window
`id` **is** the id `hs.spaces` uses, and `hs.spaces.windowSpaces(id)` placed 13 windows in
**2.9 ms**, answering for **inactive** Spaces too. So a session is tied to its Desktop by
its window, not by matching its directory name against the Desktop's label — which is the
defect being fixed. Sweeping `windowsForSpace` over every Space instead costs **330 ms**;
do not.

**Decided in the write-up, and open to correction:**

- The `Desktop N` prefix appears on the **first** line of a multi-line Desktop; the rest are
  indented to align under it.
- The **icon row goes on that first line** only, not repeated per line.
- **`both` mode keeps its `T#` session list.** It is no longer redundant: the Desktop lines
  now collapse sessions by project, while the `T#` list still enumerates each session
  individually with its task summary.
- **"Project" means any repo under `repoRoots`**, not only one carrying a `CLAUDE.md`. It is
  what the panel can see.
- A session whose window reports **no Space** (minimized) gets no Desktop line. It still
  appears in the `T#` list.

**Two limits to state plainly wherever this is documented.** The session poll reads
**Terminal only**, so a session in iTerm, Ghostty or kitty produces no line however the
rule is written. And the orange evidence for a Desktop you are not standing on comes from
the last read of that Desktop (**D3**), so it is as fresh as your last visit or ⌘⌃⌥S.

**Both former open points are settled** (2026-08-04): the project rename is **global**, and
a lone Finder window **may** name a Desktop in orange — D7's measured counterexample was put
to Peter and accepted, on the grounds that orange claims "set up for" rather than "the
subject of" and the icon row still shows the apps. Peter wrote "yellow" for that colour;
**orange** is used, because yellow is the working dot's colour.

## Task #6 — Read subprocess output from a file (revises #4)

**Status:** done (2026-08-04)

**#4 fixed the deadlock and introduced a truncation.** Peter reported the session list
toggling between two different views every ~10 s. Reproduced by sampling the live
`sessions` table once a second: **8 of 56 samples** held 4 sessions instead of 7, the first
of them named `aude-config` — a line cut in the middle, which sorts first because a partial
line has no window id.

Cause, measured — see **D66** for the table: `hs.task` **splits its output between the
streaming and termination callbacks**, and #4's helper preferred the streamed bytes and
discarded the rest. Separately, **a chunk ending inside a multi-byte character is dropped
outright**, which no amount of careful reassembly can survive.

**Done:** `runTask` now redirects the child's stdout and stderr to temporary files and reads
them after exit; the streaming callback is kept only as a drain and its bytes are appended
rather than preferred. `shQuote` moved above `runTask` and its later duplicate removed.
`v47` → **`v48`**.

**Verified:** 62 consecutive one-second samples of the live session list, **all seven
sessions, no truncation** — against 8 truncated in 56 before the fix. `claudeStates` = 5,
`gitStates` = 15, and no capture files left behind in `$TMPDIR`.

**Not verified, and worth knowing:** the ⌘⌃⌥g query and the pull run through the same
helper but were **not exercised** — the popup would have appeared on Peter's screen
unasked, and the pull writes to a repository. Their call sites are structurally identical
to the two that were tested.

**Built (`v49`).** `safeWindowSpace` / `mapSessionsToSpaces` tie every session to the
Desktop its window is on; `sessionGroupsFor(sid)` collapses them one group per project;
`screenEntries` emits a BLOCK per Desktop, with `Desktop N` and the icon row on its first
line and the rest indented under it. `projectOfWindow` attributes each window to a project
(Finder included) and `rankProjects` keeps the top two, ties broken on name.
`projectLabel` colours a restored Desktop's name orange before it has been re-read.
`claudeStateFor` is **deleted** — it was the string match that caused the fault. Clicking a
session line cycles through that project's windows (`cyc:` ids, `cycleNext`); ⌘⌃⌥N there
renames the project, saved globally under `projects` in the state file.

**Verified by rendering the entry list directly**, not by eye:

| Desktop | drawn as | dots | colour |
|---|---|---|---|
| 13 — two AGU sessions + one MODIS_L2_Manuscript | **two lines** under one `Desktop 13` | claude + git on both | white |
| 11 — one session | one line, `wids=1` | claude + git | white |
| 3, 9 — repo windows, no session | one line each | **none** | **orange** |
| 7 — ⌘⌃⌥N name | one line | none | white (your word, not a claim) |

Console clean after reload apart from the known `Unable to fetch NSRunningApplication`
noise the `safe*` wrappers exist to swallow.

**Not verified — it needs a mouse:** click-to-cycle, and ⌘⌃⌥N on a session line.

**Migration consequence, reported not fixed:** a ⌘⌃⌥N name set on a Desktop that now has a
session is **ignored**, because such a line is named by its project. `Desktop 4` reverts
from `3-way_analysis` to `three-way_SST_error_analysis_manuscript`, which is also much
wider. Re-applying it as a PROJECT name (⌘⌃⌥N on that line) restores it everywhere at once.
Adopting existing Desktop overrides as project names automatically was **not** done: an
override was your word for a Desktop, and promoting it to a global project name changes what
it claims.

**Colour changed before this was used in anger:** the no-session name is **teal**, not the
orange this task was specified with — see **D74**. Orange collided with the amber status and
stale-hint lines beneath the list.


## Task #7 — Colour the sessions, not the projects; document evidence only (revises #5)

**Status:** done (2026-08-04)

Two changes asked for after living with `v51`, recorded as **D75**.

1. **Teal moves to the session lines**; a Desktop named after a project whose document is
   open there is white, like everything else that is not running. The panel now emphasises
   what is live rather than what is dormant.
2. **Only an open document under a repo root names a project.** Finder parked in the repo,
   a repo name spotted in a window title, and the token-overlap fallback are all gone —
   with `M.noRepoHintApps` and the `ctx` hint machinery that existed only to feed them.

**Verified by rendering the entry list:** the five Desktops with sessions draw teal with
their dots; the five named by an open document draw white with none; the Desktops that used
to be named by a title guess now show their icon rows instead. `v51` → **`v52`**, console
clean.

**Settled 2026-08-04:** the evidence is any document under a repo root, not only `.md` —
put back to Peter and confirmed. A repo PDF in Preview, a `.tex` or a spreadsheet is the
same evidence as a `CLAUDE.md`: a document from that project, open here.


## Task #8 — Fix the dead `M.docApps` key, and audit the rest of the list

**Status:** done (2026-08-06)

**The bug.** `M.docApps` listed `["MacDown 3000"]`. The app is called **`MacDown`** —
verified live through the `hs` CLI: `hs.application.runningApplications()` reports
`MacDown`, bundle `com.uranusjr.macdown`, `CFBundleName` `MacDown`, 0.7.3. `readSpaceFrom`
asks a window for its document only when `M.docApps[app]` is set, so **no MacDown window
was ever asked**, `projHits` stayed empty, and **D75**'s rule 1 could not fire. The Desktop
fell through to the app rule and drew the MacDown icon instead of the project name.

MacDown itself was never at fault: a scratch file opened in it returns
`AXDocument = file:///…/macdown_probe.md`, so the path arrives intact once the key matches.

**It has been wrong since the first commit** (`8ec045a`, `v15`) and was invisible until
`v52`. Before **D75** a Desktop could still be named from a window title or a Finder path,
so the dead key never cost anything visible. Making a document the *only* evidence exposed
it. Fixed by adding `["MacDown"] = true`; `"MacDown 3000"` is kept alongside it, in case
the iMac's copy really is named that.

**The audit**, on `cornillon-laptop` 2026-08-06: every key compared against the `.app`
bundles in `/Applications`, `/System/Applications` and `~/Applications`. The name macOS
reports is the bundle's **display** name — the `.app` filename — not `CFBundleName`, which
is why `Microsoft Word` is right where `CFBundleName` says `Word`.

| `M.docApps` key | Installed here | Verdict |
|---|---|---|
| `MacDown 3000` | `MacDown.app` | **wrong — the bug above**, now joined by `MacDown` |
| `Code` | — | dead; it is VS Code's `CFBundleName`, never its reported name. Harmless, kept |
| `Visual Studio Code`, `CLion`, `Aquamacs`, `Preview`, `Microsoft Word`, `Microsoft Excel`, `Pages`, `Numbers`, `Keynote`, `TextEdit`, `Xcode`, `Sublime Text` | yes | correct |
| `PyCharm`, `Emacs`, `BBEdit`, `Nova` | not on this machine | can't be checked here; left alone |

**Installed and document-bearing but absent from the list** — not added, since every entry
costs an AX read per window (**D5**): the eight `MATLAB_R20xx` bundles (each reports its
own versioned name, so they need eight keys or a pattern), `Microsoft PowerPoint` — odd
company for Word, Excel and Keynote, which are all in — `OmniGraffle`, `draw.io`, `yEd`,
`Papers`, `Inkscape`, `Dia`, `Eclipse`, `R`.


## Task #9 — A ⌘⌃⌥N name belongs to a project, not to a Desktop (revises #5)

**Status:** done (2026-08-06)

Recorded as **D76**, which supersedes **D16**. Asked for 2026-08-06, after Task #8's diagnosis showed
the two problems were connected: a Desktop was showing `3-way analysis` with nothing open
on it, and the override was also what would have hidden the MacDown fix even after it
landed.

- ⌘⌃⌥N renames the **project** on every line — the session group's (**D67**) or the
  top-ranked project whose documents are open there (**D75**).
- On a Desktop with neither, it refuses with an alert instead of naming the Desktop.
- The `overrides` table, its `manual` flag on disk and its restore path are **deleted**.
  A pre-`v53` override is skipped on load, so it disappears at the first launch.
- ⌘⌃⌥N calls `scanActive` before deciding, so a document opened since the last read counts.

**Verified:** the file loads clean in a sandboxed `dofile` and reports `v53`; no reference
to `overrides` survives outside the migration comment. **Not yet exercised live** — that
needs a Reload Config on Peter's machine.


## Task #10 — Work on a machine with no Dropbox, and stop the header contradicting INSTALL.md

**Status:** done (2026-08-06)

Both came out of Peter's question *"what is required on a computer running the Dashboard
other than this folder and Hammerspoon?"*, which the answer could not be given cleanly
without admitting two faults.

1. **`M.showRemoteAlerts` now auto-disables** where no synced folder exists (**D77**). The
   receiving half of the cross-machine alert was on by default against a hard-coded
   `~/Dropbox/…` path, so a Dropbox-less machine polled a directory that could not exist
   every 20 s for the life of the session, plus a path watcher that never attached. Both
   were `pcall`-wrapped, so it cost nothing visible — which is why it would never have been
   noticed. `remoteAlertsPossible()` accepts the directory **or its parent**, so a syncing
   machine that has never received an alert still watches for one.
2. **The `INSTALL` block in the code no longer contradicts `INSTALL.md`** (**D78**). Step 3
   said "Copy this file to `~/.hammerspoon/desktop_dashboard.lua`" — the stale-copy bug of
   2026-07-27 written down as advice, and the opposite of `INSTALL.md`, `CLAUDE.md` and
   **D64**. It now says clone-and-`package.path`, and says not to copy.

**Not changed:** the `jq` dependency. Without `jq` on the hook's `PATH`,
`claude-dashboard-state.sh` writes no state file and exits 0, so the red dot silently never
lights; on this laptop `jq` resolves to `~/opt/anaconda3/bin/jq`, which is not a property of
this project. Reported to Peter, not fixed — hardening it is a decision about the hook, not
a cleanup.

`v53` → **`v54`**.


## Task #11 — Reconstruct the session log for `8006f23a`

**Status:** done (2026-08-06)

Session `8006f23a` ran 2026-08-03 20:58–22:47 EDT on `cornillon-laptop`, produced **v47–v50**
and the `claude-config` commit `4d4e6fb`, and **opened no session log at all**. Found by the
SessionStart hook's log-debt report; rebuilt on Peter's instruction as
`SESSIONS/2026-08-03_2058_EDT_cornillon-laptop.md`.

**Sources are named in the file's header and separated by what each can support:** prompt
text and every timestamp from the session's own JSONL (authoritative about what was asked
and when); outcomes quoted from the Stop hook's prose log at
`~/Dropbox/claude/transcripts/8006f23a-….md`, which is the assistant's account at the time
rather than a later recollection; commits from `git log`. Where the record is silent — for
instance whether the fake-marker test was ever run — the file says so instead of guessing.

**Two things it surfaced that are still open:**

- The `claude-config` half of that session (`4d4e6fb`) has **no log in that repo** either.
  **D34** says it should have one, or a `LOG.md` line there pointing at this file. Not done:
  that is a second repo and Peter has not been asked.
- `LOG.md` here is append-only and chronological, so the eight 2026-08-03 prompts cannot be
  slotted into place without either breaking that rule or rewriting history. A single
  pointer line was appended at the end instead, and the reconstruction itself carries the
  detail.


## Task #12 — Add the four editors, and redo the allowlist audit properly

**Status:** done (2026-08-06)

`TeXShop`, `BibDesk`, `Microsoft PowerPoint` and `OmniGraffle` added to `M.docApps`
(**D79**, `v55`). Verified live: after a reload, TeXShop's two windows on Desktop 5 report
`LATEX/main.tex` and `LATEX/main.pdf` and count toward that Desktop's name, where before the
reload they reported nothing.

**Task #8's audit was incomplete, and this is the correction.** It walked only the top level
of `/Applications`, `/System/Applications` and `~/Applications`, so it missed every app in a
subfolder — which on this machine is where the entire TeX toolchain lives. Redone with
`find -maxdepth 3`, the apps it had not seen are:

| Folder | Apps |
|---|---|
| `/Applications/TeX/` | **TeXShop**, **BibDesk**, LaTeXiT, TeX Live Utility |
| `/Applications/Adobe Acrobat DC/`, `/Applications/Adobe Acrobat 2015/` | Adobe Acrobat, Acrobat Distiller |
| `/Applications/Cisco/`, `/Applications/Python 3.11/`, `/Applications/Utilities/` | Cisco Secure Client, IDLE, Python Launcher, XQuartz |

**Adobe Acrobat was deliberately left out**: Preview is already on the list and is what opens
repo PDFs here. Say so if Acrobat should join it.

**The lesson is the audit method, not the list** — an allowlist keyed on an app's reported
name can only be checked against apps you actually enumerate, and enumerating one directory
level is not enumerating the machine.


## Task #13 — A colleague's Mac shows nothing: the hook's `jq`, and terminals other than Terminal.app

**Status:** done (2026-08-06)

Reported by Peter on behalf of a colleague who runs `claude` in **iTerm** and **Cursor** and
could not get the panel to show anything. Two independent causes, both of which fail
**silently**, written up in `ISSUE_ANALYSES/hook_without_jq/`.

**1. The hook required `jq` (D80).** macOS ships none. Every call was guarded with
`command -v jq`, so without it the hook wrote **no state file and exited 0** — no red dot, no
error, nothing to diagnose from. Rewritten with `awk` and bash string operators, so the hook
now has **no external dependency at all**. It is also **4× faster: 33 ms per call against
121–128 ms** for the `jq` version, measured 20 invocations each, and that cost was paid on
every prompt of every session.

Covered by a real test suite — `ISSUE_ANALYSES/Python/test_claude_dashboard_hook.py`, run
with `jq` off the `PATH`: hostile paths, `\uXXXX` payloads including a surrogate pair, the
D19 nudge filter end to end, and four kinds of degraded input. All pass.

**2. Only Terminal.app produced a session line (D81).** Not just no Desktop line — no line
anywhere, since `sessionEntries` iterates the same Terminal-derived table. Non-Terminal
sessions are now drawn from their hook state files in the `T#` list, with dots, the project,
the question and the terminal's name, and **no Desktop line** (a hook file knows the repo,
not the window — D67). Shown even in Desktops mode, in a `Sessions elsewhere:` block. The
hook writes `$TERM_PROGRAM` so the two paths cannot draw the same session twice.

**Verified live** with a fake `Cursor` state file: the panel drew
`T4 ● ● MODIS_L2_Manuscript · Cursor`, red claude dot, green git dot, question beneath.
**And the deployed hook was synced** — `settings.json` runs the `claude-config` copy, so the
repo's copy alone would have changed nothing (the Task #1 trap, hit again).

`v55` → **`v56`**.

**Not done — iTerm2 Desktop placement.** Two measurements have to come first and neither is
possible on a machine with no iTerm: whether iTerm2's AppleScript enumerates windows on
inactive Spaces, and whether its window `id` is the one `hs.spaces` uses. Peter has offered
to install it.


## Task #14 — Read iTerm2 as well as Terminal (completes #13)

**Status:** done (2026-08-06)

Peter installed iTerm2 and opened a session so the two blocking measurements could finally be
taken. **Both passed** (**D82**): iTerm2's AppleScript reports windows on inactive Spaces, and
its window `id` is the id `hs.spaces.windowSpaces` accepts — `{205}` for window 26169, while
the active Spaces were 12 and 532.

So iTerm is now read by the same poll, in the same AppleScript, and its sessions get real
Desktop lines rather than D81's window-less `T#` entries. It is excluded from the hook-only
list so it cannot appear twice.

**iTerm is the better source of the two.** Terminal composes one string and the working
directory has to be parsed off the front; iTerm's `variable named "session.path"` **is** the
working directory. Only the spinner glyph is read from prose in either case.

**Verified live and photographed:** `Desktop 8 ● ● → opendap-registry` with the iTerm icon,
and `T5 ● ● opendap-registry` in the sessions list.

`v56` → **`v57`**.

**Cursor is still out of reach**, and D81's `T#` line remains its ceiling.
