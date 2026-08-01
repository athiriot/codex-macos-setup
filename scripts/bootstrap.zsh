#!/bin/zsh

set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
CORE_ONLY=0
SKIP_CODEX_LOGIN=0
SKIP_SHELL_EDITS=0
WITH_APPS=()

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
ZPROFILE="$HOME/.zprofile"
BREW_BIN=""
BREW_PREFIX=""
EXPECTED_BREW_PREFIX=""
ARCH="$(uname -m)"
CODE_BIN=""

CORE_FORMULAE=(git gh)
KNOWN_APPS=(iterm2 visual-studio-code obsidian)
VSCODE_EXTENSIONS=(
  openai.chatgpt
  eamodio.gitlens
  mhutchie.git-graph
  GitHub.vscode-pull-request-github
  GitHub.vscode-github-actions
  editorconfig.editorconfig
  streetsidesoftware.code-spell-checker
)

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Guided macOS bootstrap for Codex.

Options:
  --dry-run                 Print planned actions without changing the system
  --yes                     Accept safe defaults
  --core-only               Skip optional app and Oh My Zsh prompts
  --with-apps LIST          Preselect optional apps: iterm2,vscode,obsidian
  --skip-codex-login        Install Codex but do not run codex login
  --skip-shell-edits        Print PATH/profile edits instead of writing files
  -h, --help                Show this help

Examples:
  ./install.sh
  ./install.sh --dry-run
  ./install.sh --core-only --yes
  ./install.sh --with-apps iterm2,vscode,obsidian
EOF
}

log() {
  print -r -- "==> $*"
}

warn() {
  print -ru2 -- "WARN: $*"
}

die() {
  print -ru2 -- "ERROR: $*"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

normalize_app_name() {
  case "$1" in
    vscode|code|visual-studio-code) print -r -- "visual-studio-code" ;;
    iterm|iterm2) print -r -- "iterm2" ;;
    obsidian) print -r -- "obsidian" ;;
    *) return 1 ;;
  esac
}

parse_app_list() {
  local raw="$1"
  local part normalized
  local parts=("${(@s:,:)raw}")
  for part in "${parts[@]}"; do
    [[ -z "$part" ]] && continue
    normalized="$(normalize_app_name "$part")" || die "Unknown app in --with-apps: $part"
    contains "$normalized" "${WITH_APPS[@]}" || WITH_APPS+=("$normalized")
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    --core-only) CORE_ONLY=1 ;;
    --with-apps)
      [[ $# -ge 2 ]] || die "--with-apps requires a comma-separated value"
      parse_app_list "$2"
      shift
      ;;
    --skip-codex-login) SKIP_CODEX_LOGIN=1 ;;
    --skip-shell-edits) SKIP_SHELL_EDITS=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

run_shell() {
  local description="$1"
  local command_text="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print -r -- "[dry-run] $description"
    print -r -- "          $command_text"
  else
    log "$description"
    eval "$command_text"
  fi
}

run_cmd() {
  local description="$1"
  shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print -r -- "[dry-run] $description"
    print -r -- "          $*"
  else
    log "$description"
    "$@"
  fi
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local suffix="[y/N]"
  [[ "$default" == "y" ]] && suffix="[Y/n]"

  if [[ "$ASSUME_YES" -eq 1 ]]; then
    [[ "$default" == "y" ]]
    return $?
  fi

  local answer
  while true; do
    printf "%s %s " "$prompt" "$suffix"
    read -r answer
    answer="${answer:l}"
    if [[ -z "$answer" ]]; then
      [[ "$default" == "y" ]]
      return $?
    fi
    case "$answer" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
    esac
    print -r -- "Please answer yes or no."
  done
}

detect_platform() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This bootstrap currently supports macOS only."

  case "$ARCH" in
    arm64) EXPECTED_BREW_PREFIX="/opt/homebrew" ;;
    x86_64) EXPECTED_BREW_PREFIX="/usr/local" ;;
    *) die "Unsupported Mac architecture: $ARCH" ;;
  esac

  log "Detected macOS on $ARCH. Expected Homebrew prefix: $EXPECTED_BREW_PREFIX"
  sw_vers || true
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools are installed."
    return
  fi

  warn "Xcode Command Line Tools are required before Homebrew can install packages."
  run_cmd "Open the Xcode Command Line Tools installer" xcode-select --install
  if [[ "$DRY_RUN" -eq 0 ]]; then
    cat <<'EOF'

Finish the Apple installer, then rerun:

  ./install.sh

EOF
    exit 1
  fi
}

find_brew() {
  if command_exists brew; then
    BREW_BIN="$(command -v brew)"
  elif [[ -x "$EXPECTED_BREW_PREFIX/bin/brew" ]]; then
    BREW_BIN="$EXPECTED_BREW_PREFIX/bin/brew"
  else
    BREW_BIN=""
  fi

  if [[ -n "$BREW_BIN" ]]; then
    BREW_PREFIX="$("$BREW_BIN" --prefix)"
  else
    BREW_PREFIX="$EXPECTED_BREW_PREFIX"
  fi
}

append_profile_block() {
  local file="$1"
  local marker="$2"
  local content="$3"
  local begin="# >>> $marker >>>"
  local end="# <<< $marker <<<"

  if [[ -f "$file" ]] && grep -Fq "$begin" "$file"; then
    log "$file already contains $marker."
    return
  fi

  if [[ "$SKIP_SHELL_EDITS" -eq 1 ]]; then
    cat <<EOF

Add this to $file:

$begin
$content
$end

EOF
    return
  fi

  if ! ask_yes_no "Add $marker to $file?" "y"; then
    warn "Skipped shell profile update for $marker."
    cat <<EOF

Add this manually if needed:

$begin
$content
$end

EOF
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    print -r -- "[dry-run] Would append $marker block to $file"
    return
  fi

  mkdir -p "${file:h}"
  if [[ -f "$file" ]]; then
    cp "$file" "$file.backup.$(date +%Y%m%d%H%M%S)"
  fi
  {
    print -r -- ""
    print -r -- "$begin"
    print -r -- "$content"
    print -r -- "$end"
  } >> "$file"
  log "Updated $file."
}

ensure_homebrew_shellenv() {
  local shellenv='eval "$('"$BREW_PREFIX"'/bin/brew shellenv)"'
  append_profile_block "$ZPROFILE" "codex-macos-setup: homebrew shellenv" "$shellenv"

  if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
    eval "$("$BREW_PREFIX/bin/brew" shellenv)"
    BREW_BIN="$BREW_PREFIX/bin/brew"
  fi
}

ensure_homebrew() {
  find_brew
  if [[ -n "$BREW_BIN" ]]; then
    log "Homebrew found at $BREW_BIN."
    ensure_homebrew_shellenv
    return
  fi

  run_shell "Install Homebrew" '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  if [[ "$DRY_RUN" -eq 1 ]]; then
    BREW_PREFIX="$EXPECTED_BREW_PREFIX"
    BREW_BIN="$EXPECTED_BREW_PREFIX/bin/brew"
    return
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    find_brew
    [[ -n "$BREW_BIN" ]] || die "Homebrew install completed, but brew was not found at the expected path."
    ensure_homebrew_shellenv
  fi
}

brew_formula_installed() {
  "$BREW_BIN" list --formula "$1" >/dev/null 2>&1
}

brew_cask_installed() {
  "$BREW_BIN" list --cask "$1" >/dev/null 2>&1
}

ensure_formula() {
  local formula="$1"
  if [[ -n "$BREW_BIN" ]] && brew_formula_installed "$formula"; then
    log "Homebrew formula already installed: $formula"
  else
    run_cmd "Install Homebrew formula: $formula" "$BREW_BIN" install "$formula"
  fi
}

ensure_core_formulae() {
  local formula
  for formula in "${CORE_FORMULAE[@]}"; do
    ensure_formula "$formula"
  done
}

ensure_cask() {
  local cask="$1"
  if [[ -n "$BREW_BIN" ]] && brew_cask_installed "$cask"; then
    log "Homebrew cask already installed: $cask"
  else
    run_cmd "Install Homebrew cask: $cask" "$BREW_BIN" install --cask "$cask"
  fi
}

find_vscode_cli() {
  if command_exists code; then
    CODE_BIN="$(command -v code)"
  elif [[ -x "$BREW_PREFIX/bin/code" ]]; then
    CODE_BIN="$BREW_PREFIX/bin/code"
  elif [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  elif [[ -x "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    CODE_BIN="$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  else
    CODE_BIN=""
  fi
}

vscode_extension_installed() {
  local extension="$1"
  local installed
  local installed_extensions=("${(@f)$("$CODE_BIN" --list-extensions 2>/dev/null)}")

  for installed in "${installed_extensions[@]}"; do
    [[ "${installed:l}" == "${extension:l}" ]] && return 0
  done
  return 1
}

ensure_vscode_extension() {
  local extension="$1"
  if [[ "$DRY_RUN" -eq 0 ]] && vscode_extension_installed "$extension"; then
    log "VS Code extension already installed: $extension"
  else
    run_cmd "Install VS Code extension: $extension" "$CODE_BIN" --install-extension "$extension"
  fi
}

ensure_vscode_extensions() {
  find_vscode_cli

  if [[ -z "$CODE_BIN" && "$DRY_RUN" -eq 1 ]]; then
    CODE_BIN="code"
  fi

  if [[ -z "$CODE_BIN" ]]; then
    warn "Visual Studio Code is installed, but the code CLI was not found. Open VS Code and run \"Shell Command: Install 'code' command in PATH\", then install extensions with 'code --install-extension <publisher.extension>'."
    return
  fi

  local extension
  for extension in "${VSCODE_EXTENSIONS[@]}"; do
    ensure_vscode_extension "$extension"
  done
}

ensure_optional_app() {
  local app="$1"
  ensure_cask "$app"

  if [[ "$app" == "visual-studio-code" ]]; then
    ensure_vscode_extensions
  fi
}

install_optional_apps() {
  [[ "$CORE_ONLY" -eq 1 ]] && return

  local app
  for app in "${KNOWN_APPS[@]}"; do
    if contains "$app" "${WITH_APPS[@]}"; then
      ensure_optional_app "$app"
      continue
    fi
    if ask_yes_no "Install optional app $app?" "n"; then
      ensure_optional_app "$app"
    else
      log "Skipped optional app: $app"
    fi
  done
}

install_oh_my_zsh() {
  [[ "$CORE_ONLY" -eq 1 ]] && return

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log "Oh My Zsh already appears to be installed."
    return
  fi

  if ! ask_yes_no "Install Oh My Zsh? Existing zsh files will not be overwritten by this script." "n"; then
    log "Skipped Oh My Zsh."
    return
  fi

  run_shell "Install Oh My Zsh without changing the current shell" 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
}

ensure_codex_path() {
  local path_line='export PATH="$HOME/.local/bin:$PATH"'
  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    log "~/.local/bin is already on PATH for this shell."
    return
  fi
  append_profile_block "$ZPROFILE" "codex-macos-setup: codex path" "$path_line"
  export PATH="$HOME/.local/bin:$PATH"
}

ensure_codex() {
  if command_exists codex; then
    log "Codex CLI found at $(command -v codex)."
  else
    local codex_install='curl -fsSL https://chatgpt.com/codex/install.sh | sh'
    if [[ "$ASSUME_YES" -eq 1 ]]; then
      codex_install='curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh'
    fi
    run_shell "Install Codex CLI with the official standalone installer" "$codex_install"
    ensure_codex_path
  fi

  if command_exists codex || [[ "$DRY_RUN" -eq 1 ]]; then
    run_cmd "Check Codex CLI version" codex --version || true
  elif [[ "$DRY_RUN" -eq 0 ]]; then
    warn "Codex was installed, but the codex command is not on PATH yet. Open a new terminal or add ~/.local/bin to PATH."
  fi
}

codex_logged_in() {
  command_exists codex && codex login status >/dev/null 2>&1
}

maybe_codex_login() {
  [[ "$SKIP_CODEX_LOGIN" -eq 1 ]] && return
  if codex_logged_in; then
    log "Codex is already authenticated."
    return
  fi

  if ask_yes_no "Run codex login now? This opens a browser for ChatGPT sign-in." "y"; then
    run_cmd "Authenticate Codex" codex login
  else
    warn "Skipped Codex login. Run 'codex login' later."
  fi
}

maybe_gh_login() {
  if ! command_exists gh; then
    warn "GitHub CLI is not on PATH yet."
    return
  fi
  if gh auth status >/dev/null 2>&1; then
    log "GitHub CLI is already authenticated."
    return
  fi
  if ask_yes_no "Run gh auth login now?" "n"; then
    run_cmd "Authenticate GitHub CLI" gh auth login
  else
    warn "Skipped GitHub CLI login. Run 'gh auth login' later."
  fi
}

maybe_codex_doctor() {
  if command_exists codex; then
    run_cmd "Run codex doctor" codex doctor
  else
    warn "Skipping codex doctor because codex is not on PATH."
  fi
}

main() {
  print -r -- "Codex macOS setup"
  print -r -- "Repo: $REPO_ROOT"
  [[ "$DRY_RUN" -eq 1 ]] && warn "Dry-run mode: no system changes will be made."

  detect_platform
  ensure_xcode_clt
  ensure_homebrew
  ensure_core_formulae
  install_optional_apps
  install_oh_my_zsh
  ensure_codex
  maybe_codex_login
  maybe_gh_login
  maybe_codex_doctor

  cat <<'EOF'

Setup pass complete.

Next useful checks:
  codex --version
  codex login status
  gh auth status

If a command is not found, open a new terminal window so shell profile changes load.
EOF
}

main
