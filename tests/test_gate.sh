#!/bin/bash
# Runs advisor-gate.sh against sample commands with a throwaway HOME, so real markers are untouched.
# Usage: bash tests/test_gate.sh
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

check() { # expected session command
  local out got
  out=$(jq -nc --arg s "$2" --arg c "$3" '{session_id:$s,tool_name:"Bash",tool_input:{command:$c}}' \
    | HOME="$tmp" bash "$here/advisor-gate.sh")
  got=$([ -z "$out" ] && echo allow || echo "$out" | jq -r '.hookSpecificOutput.permissionDecision')
  if [ "$got" = "$1" ]; then echo "ok    $got  $3"; else echo "FAIL  want $1 got $got  $3"; fail=1; fi
}

check allow s1 "git status"
check deny  s1 "git push origin main"
check allow s1 "git push origin main"          # identical retry passes
check deny  s2 "git push origin main"          # new session, blocked again
check deny  s1 "npm test && git push"
check deny  s1 "gh pr create --fill"
check deny  s1 "gh issue comment 12 --body hi"
check deny  s1 "ssh <your-prod-host> 'sudo systemctl restart app'"
check allow s1 "ssh <your-prod-host> 'tail -n 50 app.log'"
# Known gaps, documented in the README. These pass on purpose.
check allow s1 "git -C ~/repo push"
check allow s1 'bash -c "git push"'

exit $fail
