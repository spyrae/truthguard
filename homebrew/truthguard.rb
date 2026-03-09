class Truthguard < Formula
  desc "Catches false claims from AI coding agents"
  homepage "https://github.com/spyrae/truthguard"
  url "https://github.com/spyrae/truthguard/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "cf10be4bd3651c17eda03669e25e06283ebe1c8f0ddc60fb8bdd54f29ece1516"
  license "BUSL-1.1"

  depends_on "jq"
  depends_on "bash"

  def install
    # Install scripts
    libexec.install Dir["scripts/*.sh"]

    # Make scripts executable
    Dir[libexec/"*.sh"].each { |f| chmod 0755, f }

    # Install hook configs
    (libexec/"hooks").install Dir["hooks/*.json"]

    # Install skills
    (libexec/"skills/verify").install "skills/verify/SKILL.md"
    (libexec/"skills/status").install "skills/status/SKILL.md"

    # Install extras
    libexec.install "GEMINI.md", "gemini-extension.json"
    libexec.install ".truthguard.yml.example"

    # Create wrapper that sets up symlinks
    (bin/"truthguard-install").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      TARGET="$HOME/.truthguard"
      mkdir -p "$TARGET/scripts" "$TARGET/hooks" "$TARGET/skills" "$TARGET/checksums"

      echo "Installing TruthGuard to $TARGET..."

      # Symlink scripts
      for f in #{libexec}/scripts/*.sh; do
        ln -sf "$f" "$TARGET/scripts/$(basename "$f")"
      done

      # Copy configs (user may modify)
      cp -n #{libexec}/hooks/*.json "$TARGET/hooks/" 2>/dev/null || true
      cp -rn #{libexec}/skills/* "$TARGET/skills/" 2>/dev/null || true
      cp -n #{libexec}/GEMINI.md "$TARGET/" 2>/dev/null || true
      cp -n #{libexec}/gemini-extension.json "$TARGET/" 2>/dev/null || true
      cp -n #{libexec}/.truthguard.yml.example "$TARGET/" 2>/dev/null || true

      echo ""
      echo "  TruthGuard installed to ~/.truthguard/"
      echo ""
      echo "  Add hooks to your project's .claude/settings.json:"
      echo "  See: https://github.com/spyrae/truthguard#quick-start"
    EOS
    chmod 0755, bin/"truthguard-install"
  end

  def post_install
    ohai "Run 'truthguard-install' to set up hooks in ~/.truthguard/"
  end

  test do
    # Test that block-dangerous detects --force
    output = shell_output(
      "echo '{\"tool_input\":{\"command\":\"git push --force\"}}' | bash #{libexec}/block-dangerous.sh"
    )
    assert_match "deny", output
  end
end
