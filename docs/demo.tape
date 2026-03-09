# VHS tape for TruthGuard demo
# Record: cd truthguard && vhs docs/demo.tape

Output docs/demo.gif

Set Shell "bash"
Set FontSize 15
Set Width 800
Set Height 450
Set Padding 15
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms

# Title
Type "# TruthGuard - catches false claims from AI agents"
Enter
Sleep 1.5s

# Scene 1: Dangerous command blocked
Type "# 1. Agent tries git push --force:"
Enter
Sleep 800ms

Type@80ms `echo '{"tool_input":{"command":"git push --force origin main"}}' | bash scripts/block-dangerous.sh | jq -r '.hookSpecificOutput.permissionDecisionReason'`
Enter
Sleep 2.5s

# Scene 2: Test failure caught
Type "# 2. Agent runs tests - they fail:"
Enter
Sleep 800ms

Type@80ms `echo '{"tool_input":{"command":"npm test"},"tool_response":{"stdout":"1 test failed","stderr":"FAIL src/app.test.js","exit_code":1}}' | bash scripts/check-exit-code.sh | jq -r '.systemMessage'`
Enter
Sleep 2.5s

# Scene 3: Phantom edit detected
Type "# 3. Agent claims file was edited - it wasn't:"
Enter
Sleep 800ms

Type "echo 'hello' > /tmp/tg-demo.txt"
Enter
Sleep 300ms

Type@80ms `echo '{"tool_input":{"file_path":"/tmp/tg-demo.txt"}}' | bash scripts/pre-file-change.sh`
Enter
Sleep 300ms

Type@80ms `echo '{"tool_input":{"file_path":"/tmp/tg-demo.txt"}}' | bash scripts/check-file-change.sh | jq -r '.systemMessage'`
Enter
Sleep 2.5s

# Scene 4: Post-commit reminder
Type "# 4. After commit - forces verification:"
Enter
Sleep 800ms

Type@80ms `echo '{"tool_input":{"command":"git commit -m fix"},"tool_response":{"exit_code":0}}' | bash scripts/post-commit-remind.sh | jq -r '.systemMessage'`
Enter
Sleep 2.5s

# Outro
Type "# Zero config. Zero false positives. Just honest agents."
Enter
Sleep 2s
