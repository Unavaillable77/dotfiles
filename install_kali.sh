#!/usr/bin/env bash
set -Eeuo pipefail

# Kali Linux bootstrap for guptarohit/dotfiles.
#
# Fresh-install focused:
# - Installs only the tools needed for the shared terminal experience.
# - Does not remove or clean up any previously installed packages.
# - Avoids Cargo/Go compilation for optional tools.
#
# Usage:
#   git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles
#   chmod +x ./install_kali.sh
#   ./install_kali.sh
#
# Optional environment variables:
#   DOTFILES_DIR=~/.dotfiles    Override dotfiles location.
#   INSTALL_VIM_PLUGINS=1      Install Vim plugins automatically (default: 0).

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
INSTALL_VIM_PLUGINS="${INSTALL_VIM_PLUGINS:-0}"

[[ "$(uname -s)" == "Linux" ]] || die "This installer is for Linux only."
[[ -f /etc/debian_version ]] || die "This installer requires Kali/Debian or another Debian-family distribution."
[[ -d "$DOTFILES_DIR" ]] || die "Dotfiles directory not found: $DOTFILES_DIR"
[[ -d "$DOTFILES_DIR/zsh" ]] || die "This does not look like the expected dotfiles repo: $DOTFILES_DIR"

mkdir -p "$HOME/.config" "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

SUDO=()

setup_sudo() {
  if [[ $EUID -eq 0 ]]; then
    SUDO=()
  elif command_exists sudo; then
    SUDO=(sudo)
  else
    die "sudo is required to install APT packages."
  fi
}

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
      warn "Could not update $directory; keeping existing checkout."
  fi
}

apt_install_available() {
  local available=()
  local pkg

  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      warn "APT package not available: $pkg"
    fi
  done

  if ((${#available[@]} > 0)); then
    "${SUDO[@]}" apt-get install -y --no-install-recommends "${available[@]}"
  fi
}

setup_packages() {
  setup_sudo

  log "Updating APT metadata"
  "${SUDO[@]}" apt-get update

  log "Installing minimal Kali terminal packages"
  apt_install_available \
    zsh \
    git \
    lazygit \
    curl \
    stow \
    tmux \
    vim \
    fzf \
    bat \
    fd-find \
    ripgrep \
    jq \
    eza \
    zoxide \
    tldr \
    xdg-utils \
    locales \
    micro

  # Debian/Kali may expose these under different executable names.
  if ! command_exists bat && command_exists batcat; then
    ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi

  if ! command_exists fd && command_exists fdfind; then
    ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi

  setup_starship
  setup_git_delta
  setup_locale
}

setup_starship() {
  if command_exists starship; then
    return 0
  fi

  log "Installing Starship prebuilt binary"

  curl -fsSL https://starship.rs/install.sh |
    sh -s -- --yes --bin-dir "$HOME/.local/bin"

  if ! command_exists starship; then
    die "Starship installation failed."
  fi
}

setup_git_delta() {
  if command_exists delta; then
    return 0
  fi

  if apt-cache show git-delta >/dev/null 2>&1; then
    log "Installing git-delta"
    "${SUDO[@]}" apt-get install -y --no-install-recommends git-delta
  else
    warn "git-delta is unavailable via APT; Git will use the standard pager."
  fi
}

setup_locale() {
  if locale -a 2>/dev/null | grep -qi '^en_US\.utf8$'; then
    return 0
  fi

  if [[ -f /etc/locale.gen ]]; then
    log "Generating en_US.UTF-8 locale"

    "${SUDO[@]}" sed -i \
      's/^# *\(en_US.UTF-8 UTF-8\)/\1/' \
      /etc/locale.gen

    "${SUDO[@]}" locale-gen en_US.UTF-8 ||
      warn "Could not generate en_US.UTF-8 locale"
  fi
}

setup_local_overrides() {
  touch "$HOME/.zshrc.local" "$HOME/.gitconfig.local" "$HOME/.vimrc.local"

  if ! grep -Fq '# >>> Kali overrides >>>' "$HOME/.zshrc.local"; then
    cat >> "$HOME/.zshrc.local" <<'ZSHLOCAL'

# >>> Kali overrides >>>

# macOS `open` equivalent.
alias o='xdg-open'

# Undo the upstream macOS-style `ip` alias so Kali's real `ip` command works.
unalias ip 2>/dev/null || true

# macOS `ipconfig getifaddr en0` equivalent.
alias localip="hostname -I | awk '{print \$1}'"

# The shared dotfiles may define a macOS browser executable.
unset CHROME_EXECUTABLE

# <<< Kali overrides <<<
ZSHLOCAL
  fi

  # The upstream Git config enables commit signing.
  # Keep a fresh Kali install usable before a GPG key is configured.
  if ! grep -Fq '# >>> Kali Git overrides >>>' "$HOME/.gitconfig.local"; then
    cat >> "$HOME/.gitconfig.local" <<'GITLOCAL'

# >>> Kali Git overrides >>>
[commit]
    gpgsign = false
# <<< Kali Git overrides <<<
GITLOCAL
  fi

  # If git-delta is unavailable, override the shared pager config.
  if ! command_exists delta &&
     ! grep -Fq '# >>> Kali no-delta fallback >>>' "$HOME/.gitconfig.local"; then
    cat >> "$HOME/.gitconfig.local" <<'GITDELTA'

# >>> Kali no-delta fallback >>>
[core]
    pager = less -FRX
[interactive]
    diffFilter =
[pager]
    diff = less -FRX
    show = less -FRX
# <<< Kali no-delta fallback <<<
GITDELTA
  fi
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
  setup_local_overrides

  # Stow zsh before installing Oh My Zsh so OMZ doesn't create a competing ~/.zshrc.
  stow_package stow
  stow_package zsh

  setup_oh_my_zsh

  local package
  for package in \
    tmux \
    vim \
    git \
    lazygit \
    fd \
    bat \
    starship; do
    stow_package "$package"
  done
}

setup_tmux() {
  log "Installing/updating tmux plugin manager"

  clone_or_pull \
    https://github.com/tmux-plugins/tpm \
    "$HOME/.tmux/plugins/tpm"
}

setup_vim() {
  if [[ "$INSTALL_VIM_PLUGINS" != "1" ]]; then
    log "Skipping Vim plugin download"
    printf '%s\n' "Run this later if wanted: vim +PlugInstall +qall"
    return 0
  fi

  log "Installing Vim plugins"

  if ! vim +PlugInstall +qall; then
    warn "Vim plugin installation failed."
    warn "Retry later with: vim +PlugInstall +qall"
  fi
}

maybe_change_shell() {
  command_exists zsh || return 0

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    warn "Your login shell is still ${SHELL:-unknown}."
    warn "To switch to Zsh, run: chsh -s $zsh_path"
  fi
}

main() {
  log "Setting up Kali terminal environment"

  setup_packages
  setup_dotfiles
  setup_tmux
  setup_vim
  maybe_change_shell

  log "Setup complete"
  printf '%s\n' "Open a new terminal, or run: exec zsh"
  printf '%s\n' "Inside tmux, install TPM plugins with: prefix + I"
  printf '%s\n' "Vim plugins are skipped by default to keep the install lightweight."
}

main "$@"
