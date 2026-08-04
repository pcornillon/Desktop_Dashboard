# STATUS.md — Desktop Dashboard

Living snapshot of where this project stands. Rewritten, not appended.
Last updated: **2026-08-03 23:15 EDT** (`satdat1`, during the spine migration).

---

## State

- **The tool is at `v46` and in daily use.** `M.version` reads
  `"v46 (name both ways to read the unread Desktops, 2026-08-01)"`
  (`desktop_dashboard.lua:68`). 2,736 lines, one file.
- **The last functional change was 2026-08-01** (`f9c4d05`, v46). The only commit since
  is `6442953` on 2026-08-02, a documentation correction: the claim that renaming a Space
  requires SIP-off was wrong, and the README now points at SpaceJump for anyone who only
  wants renaming (**D1**).
- **Nothing is in flight.** No feature was half-built and left; there is no `doing` task.
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

## Decisions taken (D1–D64)

All lifted from `CLAUDE.md` on 2026-08-03; none is new.

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

## Active thread — resume here

**Nothing is in flight.** The tool works, the tree is clean, and the migration is
complete.

**One thing is waiting on Peter: Task #1** — the two copies of
`claude-dashboard-state.sh` have diverged and the copy this repo ships is the older one
(see *Verified during the migration* above). Three options, none applied:

1. this repo is authoritative and `claude-config` syncs from it;
2. `claude-config` is authoritative and this repo ships a copy refreshed from it;
3. this repo's copy is deleted and `INSTALL.md` points at `claude-config`.

Option 3 is the only one that cannot drift again, but it makes this repo
un-installable by anyone who does not also have `claude-config` — which is most people,
since this repo is the public one. **That trade-off is the decision, and it is Peter's.**

**Next natural piece of work, if any:** nothing outstanding. The known open gap in the
tool itself is recorded as **D32's live tension** — TeXShop is invisible to the pull's
open-file check, and closing that gap needs an `AXDocument` timing measurement first.

**Finder tags do not travel in git.** After pulling this repo on the other machine, run
`~/Git_Repos/claude-config/tag-spine.sh ~/Git_Repos/Desktop_Dashboard`.
