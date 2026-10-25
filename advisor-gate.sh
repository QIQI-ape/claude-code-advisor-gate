#!/bin/bash
# PreToolUse(Bash) advisor gate: the first time an outward-facing command runs (open/merge a PR,
# push, file or comment on an issue, change production config), block it and ask for a review.
# Retrying the exact same command in the same session lets it through. The hook cannot verify
# that a review actually happened; it only guarantees a pause before anything leaves the machine.
# Markers are keyed by a hash of session + command and cleaned up after a day.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

pattern='(^|[;&|[:space:]])(gh[[:space:]]+pr[[:space:]]+(create|merge)|gh[[:space:]]+issue[[:space:]]+(create|comment)|git[[:space:]]+push)([[:space:]]|$)'
prod='ssh[^|;&]*<your-prod-host>'
prod_write='(>>?[[:space:]]*[^[:space:]]*\.env|sed[[:space:]]+-i[^|;&]*\.env|cp[[:space:]][^|;&]*\.env|systemctl[[:space:]]+restart)'

hit=""
if printf '%s' "$cmd" | grep -Eq "$pattern"; then
  hit="an outward-facing git/gh operation"
elif printf '%s' "$cmd" | grep -Eq "$prod" && printf '%s' "$cmd" | grep -Eq "$prod_write"; then
  hit="a production config change or service restart"
fi
[ -z "$hit" ] && exit 0

session=$(printf '%s' "$input" | jq -r '.session_id // "nosession"')
dir="$HOME/.claude/advisor-gate"
mkdir -p "$dir"
find "$dir" -type f -mtime +1 -delete 2>/dev/null
key=$(printf '%s\n%s' "$session" "$cmd" | shasum -a 256 | cut -c1-32)
marker="$dir/$key"

if [ -f "$marker" ]; then
  rm -f "$marker"
  exit 0
fi
touch "$marker"

reason="Advisor gate: this command is ${hit}. Before running it, call the advisor to review the change, the test evidence and the risks. If you still want to run it after the review, retry the exact same command and it will go through. If the review finds a problem, fix it first."
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
