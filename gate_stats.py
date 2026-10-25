"""Count advisor-gate blocks in Claude Code transcripts and what happened after each one.

Usage: python3 -I gate_stats.py ["<start of your deny reason>"]
Reads ~/.claude/projects/*/*.jsonl (read-only).
Buckets:
  after          = advisor called within 60 events after the block
  before         = advisor called within 12 events before the block
  none_with_tool = neither, in a session that did use the advisor elsewhere
  none_no_tool   = neither, in a session that never called the advisor
"""
import collections, glob, json, os, sys

MARK = sys.argv[1] if len(sys.argv) > 1 else "Advisor gate: this command"
stats = collections.Counter()
kinds = collections.Counter()
days, seen = set(), set()

for f in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")):
    ev = []
    for line in open(f, encoding="utf-8", errors="ignore"):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        c = (e.get("message") or {}).get("content")
        if isinstance(c, list):
            ev += [(b, e.get("timestamp")) for b in c if isinstance(b, dict)]
    has_advisor = any(b.get("name") == "advisor" for b, _ in ev)
    uses = {b["id"]: b for b, _ in ev if b.get("type") == "tool_use"}
    for i, (b, ts) in enumerate(ev):
        text = json.dumps(b.get("content"), ensure_ascii=False)
        # Real blocks start with "PreToolUse:Bash hook error"; this skips pasted scripts and test output
        if b.get("type") != "tool_result" or "PreToolUse:Bash hook error" not in text[:40] or MARK not in text:
            continue
        if b["tool_use_id"] in seen:
            continue
        seen.add(b["tool_use_id"])
        days.add((ts or "")[:10])
        cmd = (uses.get(b["tool_use_id"], {}).get("input") or {}).get("command", "")
        kinds["push" if "git push" in cmd else "pr" if "gh pr" in cmd
              else "issue" if "gh issue" in cmd else "prod"] += 1
        after = False
        for x, _ in ev[i + 1:i + 60]:
            if x.get("name") == "advisor":
                after = True
            if x.get("type") == "tool_use" and x.get("name") == "Bash" \
                    and (x.get("input") or {}).get("command") == cmd:
                break
        before = any(x.get("name") == "advisor" for x, _ in ev[max(0, i - 12):i])
        if after:
            stats["after"] += 1
        elif before:
            stats["before"] += 1
        else:
            stats["none_with_tool" if has_advisor else "none_no_tool"] += 1

print("blocks", len(seen), "days", len(days - {""}))
print("by type", dict(kinds))
print("review", dict(stats))
