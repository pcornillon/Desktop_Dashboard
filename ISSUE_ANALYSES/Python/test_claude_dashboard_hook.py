#!/usr/bin/env python3
"""Exercise claude-dashboard-state.sh end to end, with no `jq` reachable.

Written for D80, which removed the hook's `jq` dependency. The point of the test
is the PATH: it runs the hook with `/usr/bin:/bin:/usr/sbin:/sbin` and asserts
`jq` is not on it, so a regression that quietly reaches for jq again fails here
rather than on someone's fresh Mac — where the only symptom is a red dot that
never lights and nothing in any log.

Everything happens in a temporary HOME. Nothing touches the real
~/.hammerspoon/claude_state.

    python3 ISSUE_ANALYSES/Python/test_claude_dashboard_hook.py
    python3 ISSUE_ANALYSES/Python/test_claude_dashboard_hook.py --bench

Exit status is 0 only if every check passes.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOOK = os.path.join(REPO, "claude-dashboard-state.sh")
CLEAN_PATH = "/usr/bin:/bin:/usr/sbin:/sbin"

fails = []


def check(name, cond, detail=""):
    print(("  PASS  " if cond else "  FAIL  ") + name + (("   " + detail) if detail and not cond else ""))
    if not cond:
        fails.append(name)


class Sandbox:
    def __init__(self):
        self.home = tempfile.mkdtemp(prefix="dashboard-hook-test-")
        os.makedirs(os.path.join(self.home, ".hammerspoon"), exist_ok=True)
        self.state = os.path.join(self.home, ".hammerspoon", "claude_state")

    def run(self, state, payload=None, term="Apple_Terminal", raw=None):
        env = dict(os.environ, HOME=self.home, PATH=CLEAN_PATH, TERM_PROGRAM=term)
        data = raw if raw is not None else json.dumps(payload or {}).encode()
        argv = [HOOK] if state is None else [HOOK, state]
        return subprocess.run(argv, input=data, capture_output=True, env=env)

    def read(self, sid):
        with open(os.path.join(self.state, sid + ".json")) as f:
            return json.load(f)

    def cleanup(self):
        shutil.rmtree(self.home, ignore_errors=True)


def main():
    check("jq is NOT on the test PATH", shutil.which("jq", path=CLEAN_PATH) is None)
    check("hook exists and is executable", os.access(HOOK, os.X_OK), HOOK)
    if fails:
        return 1

    sb = Sandbox()
    try:
        print("\n== ordinary payload ==")
        sb.run("working", {"session_id": "abc-123", "cwd": "/Users/x/Git_Repos/my_repo",
                           "message": ""})
        d = sb.read("abc-123")
        check("state and repo", d["state"] == "working" and d["repo"] == "my_repo")
        check("TERM_PROGRAM recorded (D81)", d["term"] == "Apple_Terminal")
        check("session id inside the file", d["sid"] == "abc-123")

        print("\n== hostile strings ==")
        cwd = "/Users/x/Git_Repos/Peter's \"repo\" \\ back"
        msg = "Run `rm -rf \"x\"`?\nLine two\ttabbed — é ✳ \U0001f680\x07bell"
        sb.run("waiting", {"session_id": "nasty-1", "cwd": cwd, "message": msg,
                           "extra": {"cwd": "/DECOY", "session_id": "DECOY"}},
               term="iTerm.app")
        d = sb.read("nasty-1")
        check("cwd survives quotes and backslashes", d["cwd"] == cwd, repr(d["cwd"]))
        check("repo is its basename", d["repo"] == "Peter's \"repo\" \\ back", repr(d["repo"]))
        check("a nested cwd cannot win", "DECOY" not in json.dumps(d))
        check("newline and tab survive", "\n" in d["message"] and "\t" in d["message"])
        check("unicode survives, emoji included",
              "✳" in d["message"] and "\U0001f680" in d["message"], repr(d["message"]))
        check("C0 control bytes stripped", "\x07" not in d["message"])
        check("term is the other terminal", d["term"] == "iTerm.app")

        print("\n== \\uXXXX-escaped payload (some encoders do this) ==")
        raw = json.dumps({"session_id": "uni-1", "cwd": "/tmp/répo — ✳",
                          "message": "\U0001f680 done"}, ensure_ascii=True).encode()
        sb.run("working", raw=raw)
        d = sb.read("uni-1")
        check("escaped cwd decoded", d["cwd"] == "/tmp/répo — ✳", repr(d["cwd"]))
        check("surrogate pair decoded", d["message"].startswith("\U0001f680"), repr(d["message"]))

        print("\n== the nudge filter (D19) ==")
        seq = {"session_id": "seq-1", "cwd": "/tmp/r", "message": ""}
        sb.run("working", seq)
        check("working", sb.read("seq-1")["state"] == "working")
        sb.run("waiting", dict(seq, message="a real question"))
        check("waiting mid-turn is a real question", sb.read("seq-1")["state"] == "waiting")
        sb.run("working", seq)
        check("answering clears it", sb.read("seq-1")["state"] == "working")
        sb.run("done", seq)
        check("done", sb.read("seq-1")["state"] == "done")
        sb.run("waiting", dict(seq, message="idle nudge"))
        check("a nudge after done is ignored", sb.read("seq-1")["state"] == "done",
              "state is " + sb.read("seq-1")["state"])
        sb.run("gone", seq)
        check("SessionEnd removes the file",
              not os.path.exists(os.path.join(sb.state, "seq-1.json")))

        print("\n== degraded input: never fail the session ==")
        check("missing session_id exits 0", sb.run("working", {"cwd": "/tmp/nosid"}).returncode == 0)
        check("falls back to nosession-<pid>",
              any(f.startswith("nosession-") for f in os.listdir(sb.state)))
        check("empty payload exits 0", sb.run("working", raw=b"").returncode == 0)
        check("garbage payload exits 0", sb.run("working", raw=b"not json").returncode == 0)
        check("no argument exits 0", sb.run(None, raw=b"{}").returncode == 0)

        print("\n== every file written is valid JSON ==")
        bad = []
        for f in sorted(os.listdir(sb.state)):
            if f.endswith(".json"):
                try:
                    json.load(open(os.path.join(sb.state, f)))
                except Exception as exc:
                    bad.append((f, str(exc)))
        check("all state files parse", not bad, str(bad))

        if "--bench" in sys.argv:
            print("\n== cost per invocation ==")
            payload = {"session_id": "perf-1", "cwd": "/tmp/r", "message": "x" * 200}
            t0 = time.time()
            for _ in range(20):
                sb.run("working", payload)
            print("  %.1f ms per call, including this harness's fork"
                  % ((time.time() - t0) / 20 * 1000))
    finally:
        sb.cleanup()

    print("\nFAILURES: " + (", ".join(fails) if fails else "none"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
