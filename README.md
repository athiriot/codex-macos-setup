# Codex macOS Setup

Guided bootstrap for a new macOS user preparing a terminal-first Codex environment.

This repo is public. The goal is to keep the setup simple enough that new users can follow it with minimal hand-holding.

## Quickstart

```sh
git clone https://github.com/athiriot/codex-macos-setup.git
cd codex-macos-setup
./install.sh
```

Preview the actions first:

```sh
./install.sh --dry-run
```

## What It Sets Up

- Verifies macOS and detects Apple Silicon vs Intel.
- Checks for Xcode Command Line Tools.
- Installs Homebrew if needed.
- Adds Homebrew shell setup to `~/.zprofile` when approved.
- Installs core CLI tools: `git` and `gh`.
- Optionally installs iTerm2, Visual Studio Code, and Obsidian.
- When Visual Studio Code is selected, installs a small recommended extension set:
  - Codex: `openai.chatgpt`
  - GitLens: `eamodio.gitlens`
  - Git Graph: `mhutchie.git-graph`
  - GitHub Pull Requests and Issues: `GitHub.vscode-pull-request-github`
  - GitHub Actions: `GitHub.vscode-github-actions`
  - EditorConfig: `editorconfig.editorconfig`
  - Code Spell Checker: `streetsidesoftware.code-spell-checker`
- Optionally installs Oh My Zsh without changing the current shell.
- Installs Codex CLI using the official standalone installer.
- Adds `~/.local/bin` to PATH when needed.
- Runs `codex login` unless skipped.
- Offers `gh auth login`.
- Runs `codex doctor` as a final health check.

## Options

```text
--dry-run                 Print planned actions without changing the system
--yes                     Accept safe defaults
--core-only               Skip optional app and Oh My Zsh prompts
--with-apps LIST          Preselect optional apps: iterm2,vscode,obsidian
--skip-codex-login        Install Codex but do not run codex login
--skip-shell-edits        Print PATH/profile edits instead of writing files
-h, --help                Show help
```

Examples:

```sh
./install.sh --core-only --yes
./install.sh --with-apps iterm2,vscode,obsidian
./install.sh --dry-run --skip-shell-edits
```

## Architecture Notes

The script expects Homebrew at:

- Apple Silicon: `/opt/homebrew`
- Intel: `/usr/local`

It does not install Rosetta or try to force Intel Homebrew on Apple Silicon. If a machine already has Homebrew in a nonstandard location, the script uses the `brew` found on PATH.

## Safety

- The script asks before editing shell profile files unless `--yes` is used.
- Profile edits are written as clearly marked blocks.
- Existing `~/.zprofile` is backed up before writing.
- Credentials are not collected or stored by this repo.
- Codex authentication is handled by `codex login`.
- GitHub authentication is handled by `gh auth login`.

## Official References

- Codex standalone installer: `https://chatgpt.com/codex/install.sh`
- Codex CLI authentication: `codex login`
- Codex auth check: `codex login status`
- Homebrew installer: `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`
- VS Code extension CLI: `code --install-extension <publisher.extension>`
- Codex VS Code extension: `https://marketplace.visualstudio.com/items?itemName=OpenAI.chatgpt`

See [docs/fresh-mac-checklist.md](docs/fresh-mac-checklist.md) for a beginner-friendly run order and [docs/troubleshooting.md](docs/troubleshooting.md) when a command is not found or auth fails.
