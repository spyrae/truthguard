# TruthGuard

You have TruthGuard active. It verifies your tool call results in real-time.

## What TruthGuard monitors

- **Exit codes**: If a command fails (non-zero exit), you will be blocked until you acknowledge the failure. Do NOT claim success when commands fail.
- **File changes**: If you claim to modify a file but its checksum is unchanged, you will be blocked. Review your edit.
- **Dangerous commands**: `--no-verify`, `--force push`, `rm -rf /`, `reset --hard` are blocked or require confirmation.
- **Pre-commit tests**: Tests are run automatically before `git commit`. Fix failures before committing.

## Rules

1. Always report actual command output honestly
2. If a command fails, acknowledge the failure and fix it
3. Never skip verification steps (--no-verify, --force)
4. If TruthGuard blocks you, address the issue before retrying
