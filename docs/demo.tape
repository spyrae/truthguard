# VHS tape for recording TruthGuard demo GIF
# Install VHS: brew install charmbracelet/tap/vhs
# Record: vhs docs/demo.tape

Output docs/demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 500
Set Padding 20
Set Theme "Catppuccin Mocha"

# Scene 1: Show a failing test
Type "# Let's see what happens when tests fail..."
Enter
Sleep 1s

Type "echo 'test('should pass', () => { expect(1).toBe(2); });' > test.js"
Enter
Sleep 500ms

Type "node --test test.js"
Enter
Sleep 2s

# Scene 2: TruthGuard catches it
Type "# TruthGuard intercepts non-zero exit code:"
Enter
Sleep 1s

Type 'echo '"'"'{"tool_input":{"command":"node --test"},"tool_response":{"stdout":"1 test failed","stderr":"","exit_code":1}}'"'"' | bash scripts/check-exit-code.sh | jq .'
Enter
Sleep 3s

# Scene 3: Dangerous command blocked
Type "# And blocks dangerous commands:"
Enter
Sleep 1s

Type 'echo '"'"'{"tool_input":{"command":"git push --force"}}'"'"' | bash scripts/block-dangerous.sh | jq .hookSpecificOutput.permissionDecisionReason'
Enter
Sleep 3s

# Scene 4: Phantom edit detection
Type "# Catches phantom edits too:"
Enter
Sleep 1s

Type "echo 'unchanged' > /tmp/test.txt"
Enter
Sleep 500ms

Type 'echo '"'"'{"tool_input":{"file_path":"/tmp/test.txt"}}'"'"' | bash scripts/pre-file-change.sh'
Enter
Sleep 500ms

Type 'echo '"'"'{"tool_input":{"file_path":"/tmp/test.txt"}}'"'"' | bash scripts/check-file-change.sh | jq .systemMessage'
Enter
Sleep 3s

Type "# TruthGuard: Keeping AI agents honest."
Enter
Sleep 2s
