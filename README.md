# claude-code-advisor-gate

A small [PreToolUse hook](https://code.claude.com/docs/en/hooks) for Claude Code. It makes the agent pause and review before running commands that can't be taken back.

The first time Claude tries to run one of these commands, the hook blocks it and tells Claude to review the change, the test evidence and the risks. If Claude then retries the identical command, the hook lets it through. You don't have to be at the keyboard.

Commands it gates:

- `git push`
- `gh pr create`, `gh pr merge`
- `gh issue create`, `gh issue comment`
- `ssh` to your production host, when the command also writes `.env` or runs `systemctl restart`

Write-up with four weeks of real data (810 blocks; about one in five, the agent skipped the review anyway): [I put a review gate in front of Claude Code's git push](https://qiqa-blog.pages.dev/posts/claude-code-review-gate/).

## Install

Requires `jq` and `shasum`.

1. Copy the hook and make it executable:

   ```bash
   mkdir -p ~/.claude/hooks
   cp advisor-gate.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/advisor-gate.sh
   ```

2. Edit `~/.claude/hooks/advisor-gate.sh` and replace `<your-prod-host>` with your production host's IP or hostname. If you ssh through an alias, put the alias in the regex too. If you have no production host to protect, leave it as is.

3. Merge [`examples/settings.json`](examples/settings.json) into `~/.claude/settings.json`, and add [`examples/CLAUDE.md`](examples/CLAUDE.md) to `~/.claude/CLAUDE.md`.

The CLAUDE.md part matters. The hook can only force a pause. The instruction tells Claude what to do during it, especially "never retry without reviewing".

**No advisor tool?** The deny message and the CLAUDE.md snippet say "call the advisor". If your setup doesn't have an advisor tool, change that wording to something you do have: a read-only reviewer subagent that reads `git diff` and the test output, or simply "write three lines (what changed, test results, risks) before retrying".

## Test

```bash
bash tests/test_gate.sh
```

It runs the hook against sample commands with a throwaway `HOME`, so your real markers are untouched.

## How it works

- Claude Code passes each tool call to the hook as JSON on stdin. The hook reads `tool_input.command` and `session_id`.
- A risky command gets a marker file named after a sha256 of session + command, and a `deny` decision with a reason. Claude Code shows that reason to Claude, so the reason is written as instructions for the model.
- An identical retry finds the marker, deletes it and passes. A changed command has a different hash and gets gated again.
- Markers live in `~/.claude/advisor-gate/` and are cleaned up after a day.

## What it does not catch

This is a speed bump for an agent that follows rules but moves fast. It is not a security boundary. These all pass:

| Command | Why |
|---|---|
| `git -C ~/repo push` | an argument sits between `git` and `push` |
| `bash -c "git push"` | `git` is preceded by a quote |
| `/usr/bin/git push` | `git` is preceded by `/` |
| `(cd repo && git push)` | `push` is followed by `)` |
| `make release` | the push is inside a script |

`git push --dry-run` is blocked once. That's harmless: the retry goes through.

Keep real protection where it belongs: branch protection, required CI, least-privilege production accounts. The hook and `settings.json` are plain files that an agent in auto mode could edit, so keep them in version control.

## Check your own numbers

```bash
python3 -I gate_stats.py
```

The script reads your transcripts under `~/.claude/projects` (read-only). It counts blocks, and how often a review happened after a block, just before it, or not at all. If you changed the deny message, pass its opening words as the first argument.

## License

MIT
