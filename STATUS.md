# STATUS.md — Desktop Dashboard

Living snapshot of where this project stands. Rewritten, not appended.
Last updated: **2026-08-06 18:45 EDT** (`cornillon-laptop`).

---

## State

- **The tool is at `v57`, in daily use, and everything since `v52` has now been run.**
  `M.version` reads `"v57 (iTerm sessions get real Desktop lines; measured, not assumed,
  2026-08-06)"`.
  `v51` before it was the **merge of two machines' parallel work**. One file.
- **`v53` fixed two connected naming faults, both found from the laptop on 2026-08-05.**
  `M.docApps` listed `["MacDown 3000"]` and the app is called **`MacDown`** — so no MacDown
  window was ever asked for its document and **D75**'s first rule could not fire for the
  editor Peter reads every `.md` in. Wrong since the first commit; invisible until D75 made
  a document the only evidence (Task **#8**). And the per-Desktop ⌘⌃⌥N override is **gone**:
  ⌘⌃⌥N now renames a **project** on every line, so the name follows the work and leaves a
  Desktop when the work does (**D76**, Task **#9**). **Both are now verified live** — see the
  active thread for what was measured.
- **The last functional change was today**, and it was a repair. Every dot on the panel had
  gone dead: `hs.task` deadlocks on more than ~512 bytes of output unless a streaming
  callback drains the pipe, which took out four of the six subprocess reads at once, and
  the in-flight guards above them stayed pinned — one child ran 5 h 21 min. Neither ⌘⌃⌥S
  nor a Hammerspoon restart could clear it. Fixed by routing every read through one
  `runTask` helper that streams and times out (**D65**, Task **#4**). That fix then
  **truncated** the session list — `hs.task` splits its output between its two callbacks and
  drops any chunk ending inside a multi-byte character — so `runTask` now captures to a file
  instead of a pipe (**D66**, Task **#6**). Verified: 62 consecutive samples of the live
  session list, no truncation, against 8 truncated in 56 before. The measurements are in D65
  and D66.
- **A Desktop is named by the projects with live sessions on it** (Task #5, **D67**), one
  line each, joined to their Desktops by **window** rather than by name — and those lines
  are the only coloured ones on the panel (**D75**, teal). A Desktop with no session is
  named after the projects whose **documents** are open on it, in white, with no dots;
  nothing reads a window's title any more (**D75**, Task #7).
- **The two machines are merged.** The laptop's `73803a4` (clickable legend words,
  cross-machine alerts) and this machine's `a6a8c5b` (v47–v50) diverged from `6442953` and
  are now one history. Only three hunks conflicted — the version line, `M.stop`, and one
  block in `CLAUDE.md` — and the laptop's 59 lines of decision prose were **lifted into
  `DECISIONS.md` as D68–D73** rather than discarded with the conflict.
- **Task #1 is closed by the merge:** this repo's `claude-dashboard-state.sh` is now 206
  lines, byte-identical to the `claude-config` copy that actually runs (`diff`, after the
  merge).
- **This repo was migrated onto the project spine on 2026-08-03** (`claude-config`
  Tasks #11 and #19). What changed:
  - `DECISIONS.md` now exists and holds **D1–D64**, lifted out of `CLAUDE.md` where they
    had accumulated for want of such a file. **The measurements came across intact** —
    the ~40 ms `hs.window.get` cost, the ~750-sample dot study of 2026-07-28, the Menlo 13
    glyph widths, the 26-second blocked-session observation, the ~14 ms CoreGraphics pass.
    Nothing was added, dropped or softened.
  - `CLAUDE.md` went from **556 lines to architecture and layout only**, and gained the
    **What / Produces / State** block.
  - `docs/` → `DOCS/`, `archive/` → `PRE_CONVERSION/` (**D63**); `SESSIONS/`, `LATEX/`
    and `ISSUE_ANALYSES/` added empty.
  - **The code did not move** (**D64**) — `~/.hammerspoon/init.lua` and
    `~/.claude/settings.json` both name files here by path.

## Verified during the migration

Everything in this section was run or read, not recalled.

- **The two copies of `claude-dashboard-state.sh` have drifted, and the one in this repo
  is the stale one.** `diff` against
  `~/Git_Repos/claude-config/hooks/claude-dashboard-state.sh` — which is what
  `~/.claude/settings.json` actually registers on all four events — shows the
  `claude-config` copy is **~90 lines longer**. It has an opt-in remote-alerting block
  (Dropbox marker, ntfy, Pushover, all off by default) that this repo's copy does not, and
  it hoists the `message` extraction out of the state write so the alert can use it.
  **Consequence:** anyone installing from this repo by following `INSTALL.md` gets a
  script without that feature, and an edit made here would never reach this machine.
  **Reported, not fixed** — which copy is authoritative is a decision, not a cleanup.
  Tracked as **Task #1**.
- `~/.claude/settings.json` registers the `claude-config` path four times, once per state:
  `working`, `waiting`, `done`, `gone`.
- Working tree clean and level with `origin/main` before the migration began
  (`6442953`).

## Decisions taken (D1–D82)

D1–D64 were lifted from `CLAUDE.md` on 2026-08-03. **Eleven are new on 2026-08-04.** Written
here: every `hs.task` carries a timeout (**D65**), a subprocess writes to a file rather than
a pipe (**D66**), a Desktop is named by its live sessions and failing that by the projects
its windows belong to (**D67**), that colour lands on the session lines instead (**D74**,
**D75**), and only a document names a project (**D75**). Lifted out of the
laptop's `CLAUDE.md` prose by the merge, measurements intact: the clickable legend
(**D68**–**D71**) and the cross-machine alert (**D72**, **D73**).

Platform: overlay rather than renaming (D1), Hammerspoon (D2), active-Space-only reads
(D3), one `allWindows()` snapshot per read (D4), the `docApps` allowlist (D5).
Detection: what decides a subject and what only hints at a repo (D6–D12), a live
session's cwd outranks prose (D13–D14), single app vs category (D15), manual overrides
(D16).
The claude dot: the title carries two states, not three (D17), red comes from hooks
(D18), tell the two `Notification` kinds apart by ordering (D19), ageing (D20),
"finished and unseen" (D21), key off the detected label (D22), acknowledge by focus in
sessions mode (D23), and four cost/latency rulings (D24–D27).
Git: the dot is local-only (D28), `ls-remote` not `fetch` (D29), `--ff-only` (D30), the
two pre-pull checks (D31–D32), the confirmation (D33–D34), git speaks for itself (D35),
no push button (D36), plus D37–D39.
Rendering: D40–D59.
Lifecycle: D60–D62.
Repo: `PRE_CONVERSION/` (D63), the code stays at the top level (D64).
Subprocesses: time out every read (D65), capture to a file (D66).
Naming: sessions first and in teal (D67, D74, D75), then the projects whose documents are
open there, in white (D75). A name typed by hand belongs to a **project**, never to a
Desktop (D76, superseding D16).
Portability: no synced folder, no polling (D77); the code's own install steps must not
contradict INSTALL.md (D78). TeXShop measured at 0.1 ms and let into docApps, closing D32's
five-day-old live tension (D79). The hook carries no external dependency (D80), and a session
with no window still gets a line (D81). iTerm2 is read by the same poll as Terminal, after
both blocking questions were measured (D82).
Remote work: legend words are buttons (D68–D71), the hook raises the alert (D72–D73).

## Active thread — resume here

**Nothing is in flight.** `v57` is loaded, and every terminal question the colleague raised is
now either solved or answered with a measurement.

**Where sessions come from, as of `v57`:**

- **Terminal.app and iTerm2** — full Desktop lines, dots, `T#` entries. Both have an
  AppleScript dictionary that reports windows on inactive Spaces and a window id `hs.spaces`
  accepts, which are the two things a Desktop line needs (**D82**, both measured).
- **Everything else** — Ghostty, kitty, Cursor's built-in terminal, ssh — a `T#` line from
  the hook state file, with dots and the terminal's name and **no Desktop** (**D81**).
- **Cursor cannot do better than that**: Electron, no usable AppleScript dictionary, and a
  title that names a file and a workspace rather than the session.

**A third terminal would have to pass D82's two measurements** before it could be added to
`M.hookSessionTerminals` and read by the poll. That is the procedure; it is not a matter of
adding a name to a list.

**One gap, deliberately left, and worth deciding on:** the hook fires on `UserPromptSubmit`,
`Notification`, `Stop` and `SessionEnd` — **not on session start**. So a session that has been
opened but not yet prompted writes no state file and, in a terminal the poll cannot read,
appears nowhere. That is exactly what Peter hit when he first started `claude` in iTerm.
Registering the hook on `SessionStart` as well, writing an `idle` state, would close it — one
more line in `settings.json` for every machine, and `hookSessionEntries` already draws `idle`
with no claude dot.

**Still never exercised:** click-to-cycle on a session line; ⌘⌃⌥g and its pull through the
rewritten `runTask`; the clickable legend words alongside the per-project Desktop lines.

**How to check the panel from a session** (in `CLAUDE.md`'s Testing section):
`hs.window.snapshotForID(<the panel's kCGWindowNumber>, true)`, taking the largest layer-3
Hammerspoon window from `hs.window.list(true)`. **`hs.screen:snapshot()` does not work** — it
returns the desktop with the canvases missing.

**The colleague needs both repos** — `Desktop_Dashboard` for `v57`, and whichever repo holds
his hook, for the copy that records `TERM_PROGRAM`. Without the new hook there are no
`Sessions elsewhere` lines; without `v57` there are no iTerm lines.

**The iMac has pulled none of today's work**, and its hook is still the `jq` version.

**Finder tags do not travel in git.** After pulling this repo on the other machine, run
`~/Git_Repos/claude-config/tag-spine.sh ~/Git_Repos/Desktop_Dashboard`.
