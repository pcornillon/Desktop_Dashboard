# STATUS.md — Desktop Dashboard

Living snapshot of where this project stands. Rewritten, not appended.
Last updated: **2026-08-04 15:25 EDT** (`satdat1`).

---

## State

- **The tool is at `v52` and in daily use.** `M.version` reads
  `"v52 (only a live session is coloured; only a document names a project, 2026-08-04)"`.
  `v51` before it was the **merge of two machines' parallel work**. One file.
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

## Decisions taken (D1–D75)

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
open there, in white (D75).
Remote work: legend words are buttons (D68–D71), the hook raises the alert (D72–D73).

## Active thread — resume here

**Nothing is in flight, and the two machines are back in step.** Today's three faults are
fixed and verified — the dead dots (**D65**), the flickering session list (**D66**), and the
naming rule that let an open document steal a Desktop's name from the session running on it
(**D67**, **D74**) — and the laptop's parallel work is merged in.

**What has never been exercised, and needs a person at the keyboard:**

- **Click-to-cycle and ⌘⌃⌥N on a session line.** Clicking raises that project's terminal
  window; clicking again takes the next session in the same project. ⌘⌃⌥N there renames the
  project everywhere it appears.
- **⌘⌃⌥g and its pull**, which now run through the rewritten `runTask`.
- **The two feature sets together.** The clickable legend words and the remote-alert line
  came from the laptop and have never run alongside the per-project Desktop lines. They
  coexist in the loaded build — `legendClicks` is populated, `remoteAlertDir` is set, the
  Desktop lines still render per project — but nobody has clicked anything.

**One migration consequence:** a ⌘⌃⌥N name set on a Desktop that now has a session is
ignored, because such a line is named by its project. `Desktop 4` reads
`three-way_SST_error_analysis_manuscript` again rather than `3-way_analysis`. Re-applying it
as a **project** name fixes it everywhere at once. Peter declined the automatic migration.

**Finder tags do not travel in git.** After pulling this repo on the other machine, run
`~/Git_Repos/claude-config/tag-spine.sh ~/Git_Repos/Desktop_Dashboard`.
