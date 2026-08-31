#!/usr/bin/env bash
set -Eeuo pipefail

# Lightweight macOS bootstrap for this dotfiles repo.
#
# Fresh-install focused:
# - Installs the terminal dependencies actually used by the dotfiles.
# - Keeps all custom Oh My Zsh plugins from the original installer.
# - Uses Micro as the terminal editor; Vim is intentionally not installed or configured.
# - Does not remove anything already installed.
#
# Usage:
#   git clone git@github.com:Unavaillable77/dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles
#   chmod +x install_mac.sh
#   ./install_mac.sh
#
# Optional environment variables:
#   DOTFILES_DIR=~/.dotfiles
#   BREWFILE=~/.dotfiles/Brewfile
#   ENABLE_GPG_SIGNING=1     Install GnuPG/pinentry and leave commit signing enabled (default: 0)

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -d "$SCRIPT_DIR/zsh" && -d "$SCRIPT_DIR/tmux" ]]; then
  DEFAULT_DOTFILES_DIR="$SCRIPT_DIR"
else
  DEFAULT_DOTFILES_DIR="$HOME/.dotfiles"
fi

DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DOTFILES_DIR}"
BREWFILE="${BREWFILE:-$DOTFILES_DIR/Brewfile}"
ENABLE_GPG_SIGNING="${ENABLE_GPG_SIGNING:-0}"

[[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS only."
[[ -d "$DOTFILES_DIR" ]] || die "Dotfiles directory not found: $DOTFILES_DIR"
[[ -d "$DOTFILES_DIR/zsh" ]] || die "This does not look like the expected dotfiles repo: $DOTFILES_DIR"
[[ -f "$BREWFILE" ]] || die "Brewfile not found: $BREWFILE"

mkdir -p "$HOME/.config" "$HOME/.local/bin"

backup_regular_file() {
  local target="$1"

  if [[ -f "$target" && ! -L "$target" ]]; then
    local stamp backup
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${stamp}"
    mv "$target" "$backup"
    log "Backed up $target to $backup"
  fi
}

clone_or_pull() {
  local repo_url="$1"
  local directory="$2"

  if [[ ! -d "$directory/.git" ]]; then
    if [[ -e "$directory" ]]; then
      warn "$directory exists but is not a Git checkout; leaving it untouched."
      return 1
    fi

    git clone --depth 1 "$repo_url" "$directory"
  else
    git -C "$directory" pull --ff-only ||
      warn "Could not update $directory; keeping the existing checkout."
  fi
}

setup_homebrew() {
  if ! command_exists brew; then
    log "Installing Homebrew"
    /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Homebrew is /opt/homebrew on Apple Silicon and /usr/local on Intel.
  if ! command_exists brew; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    else
      die "Homebrew installed but brew could not be located."
    fi
  fi

  local brew_bin
  brew_bin="$(command -v brew)"

  # Persist Homebrew's PATH setup without duplicating the line on reruns.
  touch "$HOME/.zprofile"
  local shellenv_line="eval \"\$($brew_bin shellenv)\""

  if ! grep -Fq "$brew_bin shellenv" "$HOME/.zprofile"; then
    printf '\n%s\n' "$shellenv_line" >> "$HOME/.zprofile"
  fi

  eval "$("$brew_bin" shellenv)"

  log "Updating Homebrew"
  brew update

  log "Installing terminal dependencies from $(basename "$BREWFILE")"
  brew bundle --file "$BREWFILE"
}

setup_optional_gpg() {
  touch "$HOME/.gitconfig.local"

  if [[ "$ENABLE_GPG_SIGNING" == "1" ]]; then
    log "Installing GPG signing tools"
    brew install gnupg pinentry-mac

    warn "GPG signing is enabled by the shared Git config."
    warn "You still need to create/import a private key and configure user.signingkey."
  else
    # The tracked Git config enables gpgsign=true. A fresh machine has no key,
    # so override it locally rather than changing the shared tracked config.
    git config --file "$HOME/.gitconfig.local" commit.gpgsign false
  fi
}

setup_local_files() {
  touch "$HOME/.zshrc.local" "$HOME/.gitconfig.local"
}

stow_package() {
  local package="$1"

  if [[ -d "$DOTFILES_DIR/$package" ]]; then
    log "Stowing $package"
    stow \
      --dir "$DOTFILES_DIR" \
      --target "$HOME" \
      --restow "$package"
  fi
}

setup_oh_my_zsh() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh"

    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      /bin/sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
  fi

  local zsh_custom="$HOME/.oh-my-zsh/custom"
  mkdir -p "$zsh_custom/plugins" "$zsh_custom/themes"

  log "Installing/updating Zsh plugins"

  clone_or_pull \
    https://github.com/Pilaton/OhMyZsh-full-autoupdate.git \
    "$zsh_custom/plugins/ohmyzsh-full-autoupdate"

  clone_or_pull \
    https://github.com/MichaelAquilina/zsh-you-should-use.git \
    "$zsh_custom/plugins/you-should-use"

  clone_or_pull \
    https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$zsh_custom/plugins/zsh-syntax-highlighting"

  clone_or_pull \
    https://github.com/zsh-users/zsh-autosuggestions.git \
    "$zsh_custom/plugins/zsh-autosuggestions"

  clone_or_pull \
    https://github.com/Aloxaf/fzf-tab.git \
    "$zsh_custom/plugins/fzf-tab"
}

setup_dotfiles() {
  backup_regular_file "$HOME/.zshrc"
  setup_local_files

  # Stow zsh first so Oh My Zsh does not create a competing ~/.zshrc.
  stow_package stow
  stow_package zsh

  setup_oh_my_zsh

  local package
  for package in \
    tmux \
    git \
    lazygit \
    fd \
    bat \
    neovim \
    iterm2 \
    starship; do
    stow_package "$package"
  done
}

setup_iterm2() {
  if [[ ! -d "/Applications/iTerm.app" ]]; then
    warn "iTerm2 is not present in /Applications; skipping preference setup."
    return 0
  fi

  log "Setting up iTerm2 preferences"

  # Use the absolute path; this avoids relying on iTerm2 expanding "~".
  defaults write com.googlecode.iterm2 \
    PrefsCustomFolder -string "$HOME/.config/iterm2_settings"

  defaults write com.googlecode.iterm2 \
    LoadPrefsFromCustomFolder -bool true

  defaults write com.googlecode.iterm2 \
    NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2
}

setup_tmux() {
  log "Installing/updating tmux plugin manager"

  clone_or_pull \
    https://github.com/tmux-plugins/tpm \
    "$HOME/.tmux/plugins/tpm"
}


main() {
  log "Setting up macOS terminal environment"

  setup_homebrew
  setup_dotfiles
  setup_optional_gpg
  setup_iterm2
  setup_tmux
  log "Setup complete"
  printf '%s\n' "Open a new iTerm2 window, or run: exec zsh"
  printf '%s\n' "Inside tmux, install TPM plugins with: prefix + I"
  printf '%s\n' "To enable signed Git commits later, configure GPG and remove the local gpgsign=false override."
}

main "$@"
