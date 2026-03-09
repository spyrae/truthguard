# Reddit Post

**Subreddits:** r/ClaudeAI, r/ChatGPTCoding, r/LocalLLaMA (crosspost)

---

**Title:** I built TruthGuard - hooks that catch when Claude Code lies about what it did

**Body:**

I got tired of Claude Code telling me "Done! All tests pass!" when tests were never run. Or "I updated the file" when the file is byte-for-byte identical.

This is a documented issue ([claude-code#1501](https://github.com/anthropics/claude-code/issues/1501)) and no amount of system prompts fixes it - Claude just ignores text instructions when it "wants" to.

So I built **TruthGuard** - a set of hooks that verify agent claims at the tool call level, before Claude can lie about the results.

### What it catches

- **Phantom edits** - agent says "file updated" but SHA256 checksum is unchanged
- **Exit code lies** - tests fail (exit 1) but agent claims success
- **Skipped verification** - blocks `--no-verify`, `--force push`, `rm -rf`
- **Pre-commit test skip** - auto-runs tests before every `git commit`, blocks if they fail
- **"Done" without proof** - after every commit, forces agent to verify the fix actually works

### How it works

It's pure shell scripts that hook into Claude Code's PreToolUse/PostToolUse pipeline. No backend, no API calls, no dependencies except `jq` and `bash`.

```
Agent decides to edit a file
    |
[PreToolUse] -> records SHA256 checksum
    |
Agent edits the file
    |
[PostToolUse] -> compares checksums -> BLOCKS if unchanged
```

### Real results from 2 days of dogfooding

- 5 commits blocked (failing tests)
- 3 dangerous commands blocked (--force, --no-verify)
- 0 false positives

### Install

```bash
npx truthguard install && npx truthguard init
```

Or: `brew tap spyrae/truthguard && brew install truthguard`

Works with Claude Code and Gemini CLI. Scripts are agent-agnostic (JSON stdin/stdout).

**GitHub:** https://github.com/spyrae/truthguard

---

Would love feedback. What other lies do you catch your AI agents telling?
