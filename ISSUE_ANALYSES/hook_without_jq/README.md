# A colleague's Mac shows nothing — the hook's `jq` dependency, and terminals other than Terminal.app

**Scripts this issue uses** (they live flat in `ISSUE_ANALYSES/Python/`, per D22):

- `test_claude_dashboard_hook.py` — runs `claude-dashboard-state.sh` end to end in a
  temporary `HOME` with `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, so `jq` is not reachable.
  `--bench` also times it.

## What was reported

2026-08-06. A colleague could not get the panel to show his Claude sessions. He runs `claude`
in **iTerm** and in **Cursor's built-in terminal**.

## Two separate causes, both silent

**1. The hook needed `jq`, which macOS does not ship.** Every `jq` call in
`claude-dashboard-state.sh` was guarded with `command -v jq`, so on a machine without it the
hook wrote **no state file and exited 0**. No error, no log line, no red dot — and no way to
tell that from "nothing is waiting on you". Guarding a dependency turned a missing tool into
a silent absence of behaviour. **D80** removed it: `awk` and bash's own string operators do
the JSON now.

Measured while replacing it, 20 invocations each, same payload and sandboxed `HOME`:

| implementation | per call |
|---|---|
| `jq` | 121–128 ms |
| `awk` | **33 ms** |

The hook runs on `UserPromptSubmit`, so the old cost was paid on every prompt of every
session.

**2. Only Terminal.app produces a session line at all.** Sessions are found by asking
Terminal for its window titles — the only API that answers for Spaces you are not looking at.
A session anywhere else appeared **nowhere**: not as a Desktop line, and not in the `T#` list
either, because `sessionEntries` iterates the same Terminal-derived table. Meanwhile every
one of those sessions was already writing a hook state file, and `readHookStates` was
discarding the per-session detail to build a `repo → state` map. **D81** draws them from
those files — dots, project, terminal name, no Desktop line.

## What was verified, and how

- The hook: the test above, which covers hostile paths, `\uXXXX` payloads, the D19 nudge
  filter, and four kinds of degraded input. All pass with no `jq` on `PATH`.
- The panel: a fake `Cursor` state file was written into `~/.hammerspoon/claude_state/` and
  the panel photographed — `hs.window.snapshotForID` on the panel's own CoreGraphics window
  id. It drew `T4 ● ● MODIS_L2_Manuscript · Cursor`, red claude dot, green git dot, with the
  question on the dimmed line under it. **`hs.screen:snapshot()` does not work for this** —
  it returns the desktop without Hammerspoon's canvases. See `CLAUDE.md`'s Testing section.

## Resolved the same day: iTerm2 (D82)

Peter installed iTerm2 and opened a session so the two measurements could be taken. **Both
passed**, against a live window on a Desktop he was not standing on:

| question | result |
|---|---|
| Does iTerm2's AppleScript report windows on **inactive** Spaces? | **Yes** — returned a window on Space 205 while 12 and 532 were active |
| Is its AppleScript window `id` the id `hs.spaces` takes? | **Yes** — `windowSpaces(26169)` → `{205}` |

So iTerm sessions get real Desktop lines, from the same poll, and iTerm is excluded from the
hook-only list. It is also the **better** source: `variable named "session.path"` *is* the
working directory, where Terminal's has to be parsed off the front of a composed title.

Two traps: `variable named "x" of sn` raises **-1723 "Access not allowed"**, which is a syntax
error and not a permissions one (`variable named` is a command — `tell sn to ...`); and
enumeration is window → tab → **session**, because a split pane is a session.

**A third terminal has to pass those same two measurements** before it can be added to
`M.hookSessionTerminals`.

## Still open

- **Cursor placement is not reachable** by any route found here. It is an Electron app with
  no usable AppleScript dictionary, and its window titles name a file and a workspace, never
  the session. The `T#` line is the ceiling.
- **The hook does not fire on session start** — only on `UserPromptSubmit`, `Notification`,
  `Stop` and `SessionEnd`. So a session opened but not yet prompted has no state file and, in
  a terminal the poll cannot read, appears nowhere. This is what Peter hit first. Registering
  it on `SessionStart` too, writing an `idle` state, would close the gap.
