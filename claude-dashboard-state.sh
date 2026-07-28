#!/usr/bin/env bash
# claude-dashboard-state.sh — records this session's state for Desktop Dashboard.
#
# Usage (from ~/.claude/settings.json hooks):  claude-dashboard-state.sh <state>
#   working   UserPromptSubmit — you sent a prompt, Claude is now busy
#   waiting   Notification     — Claude wants your attention (permission/question)
#   done      Stop             — the response finished
#   gone      SessionEnd       — session over, drop its file
#
# Writes one small JSON file per session to a MACHINE-LOCAL directory:
#   ~/.hammerspoon/claude_state/<session_id>.json
# Machine-local on purpose — session ids and working directories are per-machine,
# so this must NOT live in Dropbox even though this script does.
#
# Why hooks at all: the dashboard can already tell "computing" from "not
# computing" by reading the terminal title (Claude Code animates a Braille
# spinner there). What the title CANNOT express is *why* it stopped — a session
# blocked on a question looks identical to one that finished. The Notification
# hook is the only authoritative source for that, and it is what drives the red
# dot. See CLAUDE.md in the Desktop_Dashboard repo.
#
# Never fails the hook: every step is guarded and the script always exits 0.
# A hook that errors would interrupt the session it is meant to observe.

set -u

state="${1:-}"
[ -n "$state" ] || exit 0

dir="$HOME/.hammerspoon/claude_state"

# No Hammerspoon on this machine (these settings sync via Dropbox) — do nothing.
[ -d "$HOME/.hammerspoon" ] || exit 0

payload="$(cat 2>/dev/null || true)"

# `cwd` and `session_id` come from the hook payload; fall back sensibly so a
# payload shape change degrades instead of breaking.
cwd=""
sid=""
if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
  sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi
[ -n "$cwd" ] || cwd="$PWD"
[ -n "$sid" ] || sid="nosession-$$"

# Keep the id filesystem-safe.
sid="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')"

if [ "$state" = "gone" ]; then
  rm -f "$dir/$sid.json" 2>/dev/null || true
  exit 0
fi

mkdir -p "$dir" 2>/dev/null || exit 0

# Append-only trace of every invocation, capped. Set DASHBOARD_HOOK_TRACE=0 to
# disable. Exists because hook writes failing silently is otherwise invisible:
# the hook still exits 0 and nothing is logged anywhere.
if [ "${DASHBOARD_HOOK_TRACE:-1}" = "1" ]; then
  {
    prev_dbg="$(jq -r '.state // "none"' "$dir/$sid.json" 2>/dev/null || echo none)"
    printf '%s  event=%-8s prev=%-8s sid=%s\n' "$(date +%H:%M:%S)" "$state" "$prev_dbg" "${sid:0:8}"
  } >> "$dir/trace.log" 2>/dev/null || true
  # keep the last 300 lines
  if [ -f "$dir/trace.log" ]; then
    tail -n 300 "$dir/trace.log" > "$dir/trace.log.tmp" 2>/dev/null && \
      mv "$dir/trace.log.tmp" "$dir/trace.log" 2>/dev/null || true
  fi
fi

# Notification fires for two different things, and only one of them is a
# question: Claude Code also sends an idle "waiting for your input" nudge about
# a minute AFTER a turn ends. Treating that as a question turned every finished
# session red once you looked away long enough.
#
# Distinguish by ordering rather than by message text, which is not a stable
# contract. A real question or permission prompt can only happen mid-turn,
# between UserPromptSubmit and Stop — so the last state recorded is "working".
# A nudge can only happen after Stop, when the last state is "done".
if [ "$state" = "waiting" ] && command -v jq >/dev/null 2>&1; then
  prev="$(jq -r '.state // empty' "$dir/$sid.json" 2>/dev/null || true)"
  if [ "$prev" = "done" ]; then
    exit 0
  fi
fi

# Build with jq so a path containing quotes cannot produce invalid JSON.
if command -v jq >/dev/null 2>&1; then
  # `message` is recorded only for diagnosis — nothing branches on it.
  msg=""
  [ -n "$payload" ] && msg="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null || true)"
  jq -n \
    --arg state "$state" \
    --arg cwd "$cwd" \
    --arg repo "$(basename "$cwd")" \
    --arg msg "$msg" \
    --argjson at "$(date +%s)" \
    '{state:$state, cwd:$cwd, repo:$repo, at:$at, message:$msg}' \
    > "$dir/$sid.json" 2>/dev/null || true
fi

exit 0
