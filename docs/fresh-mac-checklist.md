# Fresh Mac Checklist

Use this order for a new user who has little or no terminal setup.

## Before Running The Installer

- Update macOS.
- Sign in to the App Store if Apple prompts for Command Line Tools.
- Have a ChatGPT account ready for Codex login.
- Have a GitHub account ready if you want `gh` authenticated.
- Open Terminal or iTerm2.

## First Pass

From the repo folder:

```sh
./install.sh --dry-run
```

Read the planned actions. If the machine is fresh, the script may say that Xcode Command Line Tools need to be installed first. Finish the Apple installer, then rerun the setup.

## Recommended Guided Install

```sh
./install.sh
```

Choose optional apps based on the person:

- iTerm2 for a better terminal.
- Visual Studio Code for a friendly editor.
- Obsidian if they will keep local notes or knowledge bases.

## Minimal Install

```sh
./install.sh --core-only
```

Use this when you only want the pieces required for Codex and GitHub CLI.

## Verify

Open a new terminal window, then run:

```sh
codex --version
codex login status
gh auth status
```

If `codex` or `brew` is not found, see [troubleshooting.md](troubleshooting.md).
