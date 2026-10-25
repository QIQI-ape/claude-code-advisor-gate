# Advisor gate

`~/.claude/hooks/advisor-gate.sh` blocks the first attempt at outward-facing commands
(`gh pr create/merge`, `git push`, `gh issue create/comment`, ssh to prod that edits `.env`
or runs `systemctl restart`). When blocked, actually call the advisor to review the change,
the test evidence and the risks, then retry the identical command. Never retry without reviewing.
