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
