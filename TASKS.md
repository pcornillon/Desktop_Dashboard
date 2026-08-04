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

**Status:** blocked (on Peter — it is a decision, not a cleanup)

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
