#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const HOOKS_CONFIG = {
  PreToolUse: [
    {
      matcher: 'Bash',
      hooks: [
        { type: 'command', command: 'bash ~/.truthguard/scripts/block-dangerous.sh', timeout: 5 },
        { type: 'command', command: 'bash ~/.truthguard/scripts/pre-commit-tests.sh', timeout: 120 }
      ]
    },
    {
      matcher: 'Write|Edit',
      hooks: [
        { type: 'command', command: 'bash ~/.truthguard/scripts/pre-file-change.sh', timeout: 5 }
      ]
    }
  ],
  PostToolUse: [
    {
      matcher: 'Bash',
      hooks: [
        { type: 'command', command: 'bash ~/.truthguard/scripts/check-exit-code.sh', timeout: 10 },
        { type: 'command', command: 'bash ~/.truthguard/scripts/post-commit-remind.sh', timeout: 5 }
      ]
    },
    {
      matcher: 'Write|Edit',
      hooks: [
        { type: 'command', command: 'bash ~/.truthguard/scripts/check-file-change.sh', timeout: 5 }
      ]
    }
  ]
};

const commands = {
  init: initProject,
  install: installGlobal,
  status: showStatus,
  help: showHelp
};

const command = process.argv[2] || 'help';

if (commands[command]) {
  commands[command]();
} else {
  console.error(`Unknown command: ${command}`);
  showHelp();
  process.exit(1);
}

function installGlobal() {
  const homeDir = process.env.HOME || process.env.USERPROFILE;
  const targetDir = path.join(homeDir, '.truthguard');

  if (fs.existsSync(targetDir)) {
    console.log('~/.truthguard already exists. Updating scripts...');
  } else {
    console.log('Installing TruthGuard to ~/.truthguard...');
    fs.mkdirSync(targetDir, { recursive: true });
  }

  // Copy scripts from package
  const pkgRoot = path.resolve(__dirname, '..');
  const dirs = ['scripts', 'hooks', 'skills'];

  for (const dir of dirs) {
    const src = path.join(pkgRoot, dir);
    const dst = path.join(targetDir, dir);
    if (fs.existsSync(src)) {
      fs.mkdirSync(dst, { recursive: true });
      for (const file of fs.readdirSync(src)) {
        const srcFile = path.join(src, file);
        const dstFile = path.join(dst, file);
        if (fs.statSync(srcFile).isFile()) {
          fs.copyFileSync(srcFile, dstFile);
          if (file.endsWith('.sh')) {
            fs.chmodSync(dstFile, 0o755);
          }
        }
      }
    }
  }

  // Copy extras
  for (const file of ['GEMINI.md', 'gemini-extension.json', '.truthguard.yml.example']) {
    const src = path.join(pkgRoot, file);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, path.join(targetDir, file));
    }
  }

  // Create log directory
  fs.mkdirSync(path.join(targetDir, 'checksums'), { recursive: true });

  console.log('');
  console.log('  Scripts installed to ~/.truthguard/');
  console.log('');
  console.log('  Next: run `truthguard init` in your project to add hooks.');
}

function initProject() {
  const homeDir = process.env.HOME || process.env.USERPROFILE;
  const truthguardDir = path.join(homeDir, '.truthguard');

  // Check if scripts are installed
  if (!fs.existsSync(path.join(truthguardDir, 'scripts', 'block-dangerous.sh'))) {
    console.log('TruthGuard scripts not found. Installing...');
    installGlobal();
    console.log('');
  }

  // Find or create .claude/settings.json
  const claudeDir = path.join(process.cwd(), '.claude');
  const settingsPath = path.join(claudeDir, 'settings.json');

  fs.mkdirSync(claudeDir, { recursive: true });

  let settings = {};
  if (fs.existsSync(settingsPath)) {
    try {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
      console.log('Found existing .claude/settings.json');
    } catch {
      console.log('Warning: could not parse existing settings.json, creating backup...');
      fs.copyFileSync(settingsPath, settingsPath + '.bak');
      settings = {};
    }
  }

  // Check if hooks already configured
  if (settings.hooks && settings.hooks.PreToolUse) {
    const hasBlock = JSON.stringify(settings.hooks).includes('block-dangerous');
    if (hasBlock) {
      console.log('');
      console.log('  TruthGuard hooks already configured in this project.');
      console.log('  Run `truthguard status` to check session log.');
      return;
    }
  }

  // Merge hooks
  if (!settings.hooks) {
    settings.hooks = {};
  }

  // Add TruthGuard hooks (merge with existing)
  for (const [event, hookGroups] of Object.entries(HOOKS_CONFIG)) {
    if (!settings.hooks[event]) {
      settings.hooks[event] = [];
    }
    for (const group of hookGroups) {
      settings.hooks[event].push(group);
    }
  }

  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');

  console.log('');
  console.log('  TruthGuard activated!');
  console.log('');
  console.log('  Hooks added to .claude/settings.json');
  console.log('  Restart Claude Code to activate.');
  console.log('');
  console.log('  What happens now:');
  console.log('    - Dangerous commands (--force, --no-verify) are blocked');
  console.log('    - Tests run automatically before git commit');
  console.log('    - Phantom edits (unchanged files) are detected');
  console.log('    - Exit codes are verified against claims');
  console.log('    - Verification reminder after every commit');
}

function showStatus() {
  const homeDir = process.env.HOME || process.env.USERPROFILE;
  const logPath = process.env.TRUTHGUARD_LOG || path.join(homeDir, '.truthguard', 'session.log');

  if (!fs.existsSync(logPath)) {
    console.log('No TruthGuard session log found.');
    console.log(`Expected at: ${logPath}`);
    return;
  }

  const lines = fs.readFileSync(logPath, 'utf-8').trim().split('\n').filter(Boolean);

  const counts = {
    blocked: 0,
    'phantom-edit': 0,
    'test-fail': 0,
    'build-fail': 0,
    'exit-code': 0,
    'commit-blocked': 0,
    'commit-verify-reminder': 0
  };

  for (const line of lines) {
    for (const key of Object.keys(counts)) {
      if (line.includes(key)) {
        counts[key]++;
      }
    }
  }

  console.log('');
  console.log('  TruthGuard Status');
  console.log('  ─────────────────────');
  console.log(`  Commands blocked:      ${counts.blocked}`);
  console.log(`  Phantom edits:         ${counts['phantom-edit']}`);
  console.log(`  Test failures caught:  ${counts['test-fail']}`);
  console.log(`  Build failures caught: ${counts['build-fail']}`);
  console.log(`  Exit code warnings:    ${counts['exit-code']}`);
  console.log(`  Commits blocked:       ${counts['commit-blocked']}`);
  console.log(`  Verify reminders:      ${counts['commit-verify-reminder']}`);
  console.log(`  ─────────────────────`);
  console.log(`  Total events:          ${lines.length}`);
  console.log('');
}

function showHelp() {
  console.log('');
  console.log('  TruthGuard - catches false claims from AI coding agents');
  console.log('');
  console.log('  Usage:');
  console.log('    truthguard install   Install scripts to ~/.truthguard');
  console.log('    truthguard init      Add hooks to current project (.claude/settings.json)');
  console.log('    truthguard status    Show session statistics');
  console.log('    truthguard help      Show this help');
  console.log('');
  console.log('  Quick start:');
  console.log('    npx truthguard install');
  console.log('    cd your-project && npx truthguard init');
  console.log('');
}
