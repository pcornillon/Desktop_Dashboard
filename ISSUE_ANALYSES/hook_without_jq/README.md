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

## Still open

- **iTerm2 placement.** Extending the title poll to iTerm would give its sessions real
  Desktop lines. Two things have to be measured first, and neither can be measured on a
  machine with no iTerm: whether iTerm2's AppleScript enumerates windows on **inactive**
  Spaces the way Terminal's does, and whether its window `id` is the id `hs.spaces` uses —
  D67 had to establish both for Terminal.
- **Cursor placement is not reachable** by any route found here. It is an Electron app with
  no usable AppleScript dictionary, and its window titles name a file and a workspace, never
  the session. The `T#` line is the ceiling.
