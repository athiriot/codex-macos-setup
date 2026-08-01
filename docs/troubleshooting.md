# Troubleshooting

## `brew: command not found`

Open a new terminal window first. If it still fails, check the expected Homebrew prefix:

```sh
uname -m
```

Apple Silicon normally uses:

```sh
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Intel normally uses:

```sh
eval "$(/usr/local/bin/brew shellenv)"
```

Then rerun:

```sh
brew --version
```

## `codex: command not found`

Open a new terminal window. The standalone Codex installer places the visible command in `~/.local/bin` by default on macOS and Linux.

For the current shell:

```sh
export PATH="$HOME/.local/bin:$PATH"
codex --version
```

If that works, add the same PATH line to `~/.zprofile`.

## `code: command not found`

Open Visual Studio Code, press `Cmd+Shift+P`, run `Shell Command: Install 'code' command in PATH`, then open a new terminal window.

To install one extension manually:

```sh
code --install-extension openai.chatgpt
```

## Xcode Command Line Tools Did Not Finish

Run:

```sh
xcode-select -p
```

If it fails, run:

```sh
xcode-select --install
```

Finish Apple's installer, then rerun:

```sh
./install.sh
```

## Codex Browser Login Fails

Try device-code authentication:

```sh
codex login --device-auth
```

If you are using an API key instead of ChatGPT sign-in:

```sh
printenv OPENAI_API_KEY | codex login --with-api-key
```

Check the current auth state:

```sh
codex login status
```

## GitHub CLI Is Not Authenticated

Run:

```sh
gh auth login
gh auth status
```

## Oh My Zsh Did Not Appear

Open a new terminal window. This installer uses the unattended Oh My Zsh install path and does not force a shell change. That keeps the setup less surprising for new users.

## Start Over Carefully

This repo avoids destructive cleanup. If something looks wrong, inspect the marked blocks in `~/.zprofile` and the timestamped backups next to it before removing anything.
