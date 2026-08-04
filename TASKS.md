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

**Status:** todo

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
