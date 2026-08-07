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
#
# NO EXTERNAL TOOLS. This used to parse and emit JSON with `jq`, which macOS does
# not ship: every call was guarded with `command -v jq`, so on a machine without
# it the hook wrote NO state file and still exited 0 — the red dot simply never
# lit, with no error anywhere to explain why. That is exactly the machine this
# runs on first, a colleague's fresh Mac. It now uses only `awk` and bash's own
# string operators, both always present (D80).

set -u

# ---- JSON, without jq ------------------------------------------------------

# Value of a TOP-LEVEL string field, from JSON on stdin. Nested objects are
# skipped by depth, so a `.cwd` inside some sub-object cannot be mistaken for
# the real one.
#
# `\uXXXX` is decoded to real UTF-8, surrogate pairs included. Claude Code's own
# payloads do not use it — JavaScript's JSON.stringify emits non-ASCII raw — but
# the first version of this returned "?" for every escaped character, which is a
# silent corruption of a path, and awk emits raw bytes from a decimal `%c`
# (verified: 226,156,179 -> ✳), so decoding it properly costs nothing.
json_get() {
  awk -v want="$1" '
    function utf8(cp) {
      if (cp < 128)   return sprintf("%c", cp)
      if (cp < 2048)  return sprintf("%c%c", 192 + int(cp/64), 128 + cp%64)
      if (cp < 65536) return sprintf("%c%c%c", 224 + int(cp/4096), \
                                     128 + int(cp/64)%64, 128 + cp%64)
      return sprintf("%c%c%c%c", 240 + int(cp/262144), 128 + int(cp/4096)%64, \
                                 128 + int(cp/64)%64, 128 + cp%64)
    }
    function hexval(h,   k, d, v) {
      v = 0
      for (k = 1; k <= length(h); k++) {
        d = index("0123456789abcdef", tolower(substr(h, k, 1))) - 1
        if (d < 0) return -1
        v = v * 16 + d
      }
      return v
    }
    { doc = doc $0 "\n" }
    END {
      n = length(doc); i = 1; depth = 0; lastkey = ""
      while (i <= n) {
        c = substr(doc, i, 1)
        if (c == "\"") {
          i++; val = ""
          while (i <= n) {
            c = substr(doc, i, 1)
            if (c == "\\") {
              e = substr(doc, i + 1, 1)
              if (e == "u") {
                cp = hexval(substr(doc, i + 2, 4)); i += 6
                # A character outside the BMP arrives as a surrogate PAIR; the
                # halves are meaningless alone, so they are joined here or the
                # emoji becomes two invalid code points.
                if (cp >= 55296 && cp <= 56319 && substr(doc, i, 2) == "\\u") {
                  lo = hexval(substr(doc, i + 2, 4))
                  if (lo >= 56320 && lo <= 57343) {
                    cp = 65536 + (cp - 55296) * 1024 + (lo - 56320); i += 6
                  }
                }
                val = val (cp < 0 ? "?" : utf8(cp))
                continue
              }
              if      (e == "n") val = val "\n"
              else if (e == "t") val = val "\t"
              else if (e == "r") val = val "\r"
              else if (e == "b" || e == "f") val = val " "
              else val = val e
              i += 2; continue
            }
            if (c == "\"") { i++; break }
            val = val c; i++
          }
          j = i
          while (j <= n && substr(doc, j, 1) ~ /[ \t\r\n]/) j++
          if (substr(doc, j, 1) == ":") { lastkey = val; i = j + 1 }
          else {
            if (depth == 1 && lastkey == want) { printf "%s", val; exit }
            lastkey = ""
          }
          continue
        }
        if (c == "{" || c == "[") depth++
        else if (c == "}" || c == "]") depth--
        i++
      }
    }
  '
}

# One string, escaped for embedding in JSON. Backslash FIRST, or every escape
# added after it would be escaped again.
json_esc() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  s=${s//$'\n'/\\n}
  # Remaining C0 controls have no short escape and would make the file invalid.
  # UTF-8 is untouched: every byte of a multi-byte character is >= 0x80.
  printf '%s' "$s" | awk '{ gsub(/[\001-\010\013\014\016-\037]/, ""); printf "%s", $0 }'
}

state="${1:-}"
[ -n "$state" ] || exit 0

dir="$HOME/.hammerspoon/claude_state"

# ---- remote alerting (opt-in; absent config = nothing happens) -------------
#
# The red dot solves "which Desktop wants me" for someone sitting at this
# machine. It cannot solve "I am 60 miles away and this session has been blocked
# on a permission prompt for an hour" — and this hook is the only thing that
# fires at the exact moment that becomes true. So it optionally also raises an
# alert that leaves the machine.
#
# Config, if present, is sourced from ~/.claude/dashboard-notify.conf:
#
#   NOTIFY_DROPBOX=1                       # drop a marker for another Mac
#   NOTIFY_NTFY_URL="https://ntfy.sh/…"    # push to phone via ntfy
#   NOTIFY_PUSHOVER_TOKEN="…"              # or push via Pushover
#   NOTIFY_PUSHOVER_USER="…"
#   NOTIFY_DETAIL=0                        # 1 also sends cwd + the prompt text
#
# No config file means no marker, no network call, no behaviour change at all.
# That is the deliberate default: this script runs on every prompt of every
# session, and it must never surprise anyone with traffic they didn't ask for.
NOTIFY_DROPBOX=0
NOTIFY_NTFY_URL=""
NOTIFY_PUSHOVER_TOKEN=""
NOTIFY_PUSHOVER_USER=""
NOTIFY_DETAIL=0
notify_conf="$HOME/.claude/dashboard-notify.conf"
# shellcheck disable=SC1090
[ -f "$notify_conf" ] && . "$notify_conf" 2>/dev/null || true

# LocalHostName, not `hostname` — on the laptop `hostname` returns a VPN DHCP
# name that changes between sessions and would scatter markers across it.
host="$(scutil --get LocalHostName 2>/dev/null || echo mac)"
host="$(printf '%s' "$host" | tr -c 'A-Za-z0-9._-' '_')"
alert_dir="$HOME/Dropbox/claude/dashboard_alerts"

# A marker exists exactly while a session is blocked on you. Raised on the
# `waiting` that survives the nudge filter below, and cleared by ANY later state
# — answering the question writes `working`, so the marker clears itself without
# the other machine having to decide when an alert is stale.
alert_clear() {
  [ "$NOTIFY_DROPBOX" = "1" ] || return 0
  rm -f "$alert_dir/${host}_${sid}.json" 2>/dev/null || true
}

# Everything here is backgrounded and time-limited. A hook that blocks holds up
# the session it is meant to observe, and this is the one part that touches the
# network — see the header: never fail, never delay.
alert_raise() {
  repo_name="$(basename "$cwd")"
  if [ "$NOTIFY_DROPBOX" = "1" ]; then
    mkdir -p "$alert_dir" 2>/dev/null && \
    printf '{"host":"%s","repo":"%s","cwd":"%s","sid":"%s","at":%s,"message":"%s"}\n' \
      "$(json_esc "$host")" "$(json_esc "$repo_name")" "$(json_esc "$cwd")" \
      "$(json_esc "$sid")" "$(date +%s)" "$(json_esc "$msg")" \
      > "$alert_dir/${host}_${sid}.json" 2>/dev/null || true
  fi

  # The default body is deliberately thin — host and repo, enough to know which
  # machine and which project. NOTIFY_DETAIL=1 adds the working directory and
  # the prompt text, which is real content leaving your machine; see the README.
  title="Claude waiting — $repo_name"
  body="$host · $repo_name"
  if [ "$NOTIFY_DETAIL" = "1" ]; then
    body="$host · $cwd"
    [ -n "$msg" ] && body="$body
$msg"
  fi

  if [ -n "$NOTIFY_NTFY_URL" ] && command -v curl >/dev/null 2>&1; then
    ( curl -fsS -m 8 -X POST \
        -H "Title: $title" -H "Priority: high" -H "Tags: warning" \
        -d "$body" "$NOTIFY_NTFY_URL" >/dev/null 2>&1 & ) 2>/dev/null || true
  fi
  if [ -n "$NOTIFY_PUSHOVER_TOKEN" ] && [ -n "$NOTIFY_PUSHOVER_USER" ] \
     && command -v curl >/dev/null 2>&1; then
    ( curl -fsS -m 8 \
        --form-string "token=$NOTIFY_PUSHOVER_TOKEN" \
        --form-string "user=$NOTIFY_PUSHOVER_USER" \
        --form-string "title=$title" \
        --form-string "message=$body" \
        https://api.pushover.net/1/messages.json >/dev/null 2>&1 & ) 2>/dev/null || true
  fi
}

# No Hammerspoon on this machine — do nothing. The hook is registered in a
# settings.json shared across machines (symlinked to the claude-config repo), so
# it runs wherever that is checked out, Hammerspoon or not.
[ -d "$HOME/.hammerspoon" ] || exit 0

payload="$(cat 2>/dev/null || true)"

# `cwd` and `session_id` come from the hook payload; fall back sensibly so a
# payload shape change degrades instead of breaking.
cwd=""
sid=""
if [ -n "$payload" ]; then
  cwd="$(printf '%s' "$payload" | json_get cwd 2>/dev/null || true)"
  sid="$(printf '%s' "$payload" | json_get session_id 2>/dev/null || true)"
fi
[ -n "$cwd" ] || cwd="$PWD"
[ -n "$sid" ] || sid="nosession-$$"

# Keep the id filesystem-safe.
sid="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')"

if [ "$state" = "gone" ]; then
  rm -f "$dir/$sid.json" 2>/dev/null || true
  alert_clear
  exit 0
fi

mkdir -p "$dir" 2>/dev/null || exit 0

# Append-only trace of every invocation, capped. Set DASHBOARD_HOOK_TRACE=0 to
# disable. Exists because hook writes failing silently is otherwise invisible:
# the hook still exits 0 and nothing is logged anywhere.
if [ "${DASHBOARD_HOOK_TRACE:-1}" = "1" ]; then
  {
    prev_dbg="$(json_get state < "$dir/$sid.json" 2>/dev/null || true)"
    [ -n "$prev_dbg" ] || prev_dbg=none
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
if [ "$state" = "waiting" ]; then
  prev="$(json_get state < "$dir/$sid.json" 2>/dev/null || true)"
  if [ "$prev" = "done" ]; then
    exit 0
  fi
fi

# `message` is recorded only for diagnosis — nothing branches on it. Lifted out
# of the write below because the remote alert wants it too.
msg=""
if [ -n "$payload" ]; then
  msg="$(printf '%s' "$payload" | json_get message 2>/dev/null || true)"
fi

# `term` and `sid` are what let the panel draw a session it cannot see (D81).
# The dashboard finds sessions by asking Terminal.app for its window titles,
# which is the only API that answers for Spaces you are not looking at — so a
# session in iTerm, Ghostty, kitty or Cursor's built-in terminal is invisible to
# it. This file is not: Claude Code writes it from inside the session, whatever
# it is running in. TERM_PROGRAM says which, so the panel can draw the ones the
# title poll did not already account for, and skip the ones it did.
printf '{"state":"%s","cwd":"%s","repo":"%s","at":%s,"term":"%s","sid":"%s","message":"%s"}\n' \
  "$(json_esc "$state")" \
  "$(json_esc "$cwd")" \
  "$(json_esc "$(basename "$cwd")")" \
  "$(date +%s)" \
  "$(json_esc "${TERM_PROGRAM:-unknown}")" \
  "$(json_esc "$sid")" \
  "$(json_esc "$msg")" \
  > "$dir/$sid.json" 2>/dev/null || true

# The local state file is written FIRST and unconditionally: the red dot on this
# machine must never depend on a Dropbox folder existing or a network call
# succeeding. Only then does the alert go out.
#
# Reaching here with state=waiting means it survived the nudge filter above, so
# it is a real question or permission prompt. Every other state clears.
if [ "$state" = "waiting" ]; then
  alert_raise
else
  alert_clear
fi

exit 0
