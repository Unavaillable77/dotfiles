#!/usr/bin/env bash
set -Eeuo pipefail

# Kali Linux bootstrap for guptarohit/dotfiles.
#
# Usage:
#   git clone https://github.com/guptarohit/dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles
#   cp /path/to/install-kali.sh ./install-kali.sh
#   chmod +x ./install-kali.sh
#   ./install-kali.sh
#
# Optional environment variables:
#   DOTFILES_DIR=~/.dotfiles    Override dotfiles location.
#   ADOPT_AGENTS=1             Allow `stow --adopt agents`.
#   INSTALL_GO_EXTRAS=1        Install sesh + lazydocker with Go (default: 1).

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
ADOPT_AGENTS="${ADOPT_AGENTS:-0}"
INSTALL_GO_EXTRAS="${INSTALL_GO_EXTRAS:-1}"

[[ "$(uname -s)" == "Linux" ]] || die "This installer is for Linux only."
[[ -f /etc/debian_version ]] || die "This installer requires a Debian-family system such as Kali Linux."
[[ -d "$DOTFILES_DIR" ]] || die "Dotfiles directory not found: $DOTFILES_DIR"
[[ -d "$DOTFILES_DIR/zsh" ]] || die "This does not look like the guptarohit dotfiles repo: $DOTFILES_DIR"

mkdir -p "$HOME/.config" "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"

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

    git clone "$repo_url" "$directory"
  else
    git -C "$directory" pull --ff-only
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
    "${SUDO[@]}" apt-get install -y "${available[@]}"
  fi
}

cargo_install_if_missing() {
  local command_name="$1"
  local crate="$2"

  command_exists "$command_name" && return 0

  if ! command_exists cargo; then
    warn "cargo is unavailable; cannot install $command_name"
    return 0
  fi

  log "Installing $command_name with Cargo"
  cargo install "$crate" --locked ||
    warn "Cargo install failed for $crate; continuing."
}

setup_packages() {
  setup_sudo

  log "Updating APT metadata"
  "${SUDO[@]}" apt-get update

  log "Installing Kali/Debian packages"
  apt_install_available \
    zsh \
    git \
    git-lfs \
    curl \
    wget \
    rsync \
    stow \
    tmux \
    vim \
    fzf \
    bat \
    fd-find \
    ripgrep \
    jq \
    tree \
    htop \
    btop \
    httpie \
    tldr \
    eza \
    zoxide \
    gnupg \
    pinentry-curses \
    rustc \
    cargo \
    golang-go \
    pyenv \
    fastfetch \
    lazygit \
    asciinema \
    difftastic \
    bat-extras \
    xdg-utils \
    locales \
    build-essential \
    pkg-config \
    libssl-dev

  # Debian-family distros sometimes expose these commands under different names.
  if ! command_exists bat && command_exists batcat; then
    ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi

  if ! command_exists fd && command_exists fdfind; then
    ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi

  # Git config in the repo expects delta.
  if ! command_exists delta; then
    if apt-cache show git-delta >/dev/null 2>&1; then
      "${SUDO[@]}" apt-get install -y git-delta
    else
      cargo_install_if_missing delta git-delta
    fi
  fi

  # Fallbacks for tools that may not exist in the current Kali repositories.
  cargo_install_if_missing starship starship
  cargo_install_if_missing eza eza
  cargo_install_if_missing zoxide zoxide
  cargo_install_if_missing bat bat
  cargo_install_if_missing fd fd-find
  cargo_install_if_missing tldr tealdeer
  cargo_install_if_missing difft difftastic
  cargo_install_if_missing jless jless
  cargo_install_if_missing git-absorb git-absorb

  setup_pyenv
  setup_go_extras
  setup_locale
}

setup_pyenv() {
  if ! command_exists pyenv; then
    log "Installing pyenv"
    clone_or_pull https://github.com/pyenv/pyenv.git "$HOME/.pyenv"
  fi

  local pyenv_root="$HOME/.pyenv"

  if command_exists pyenv; then
    pyenv_root="$(pyenv root 2>/dev/null || printf '%s' "$HOME/.pyenv")"
  fi

  mkdir -p "$pyenv_root/plugins"

  if [[ ! -d "$pyenv_root/plugins/pyenv-virtualenv/.git" ]]; then
    log "Installing pyenv-virtualenv"
    clone_or_pull \
      https://github.com/pyenv/pyenv-virtualenv.git \
      "$pyenv_root/plugins/pyenv-virtualenv" || true
  else
    git -C "$pyenv_root/plugins/pyenv-virtualenv" pull --ff-only || true
  fi
}

setup_go_extras() {
  [[ "$INSTALL_GO_EXTRAS" == "1" ]] || return 0
  command_exists go || return 0

  if ! command_exists sesh; then
    log "Installing sesh"
    GOBIN="$HOME/.local/bin" \
      go install github.com/joshmedeski/sesh/v2@latest ||
      warn "Could not install sesh"
  fi

  if ! command_exists lazydocker; then
    log "Installing lazydocker"
    GOBIN="$HOME/.local/bin" \
      go install github.com/jesseduffield/lazydocker@latest ||
      warn "Could not install lazydocker"
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

# macOS `ipconfig getifaddr en0` equivalent.
alias localip="hostname -I | awk '{print \$1}'"

# Support pyenv when installed directly into ~/.pyenv.
if [[ -d "$HOME/.pyenv" ]]; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
fi

# Replace the macOS browser path used by the shared dotfiles.
if command -v chromium >/dev/null 2>&1; then
  export CHROME_EXECUTABLE="$(command -v chromium)"
elif command -v chromium-browser >/dev/null 2>&1; then
  export CHROME_EXECUTABLE="$(command -v chromium-browser)"
elif command -v google-chrome >/dev/null 2>&1; then
  export CHROME_EXECUTABLE="$(command -v google-chrome)"
else
  unset CHROME_EXECUTABLE
fi

# <<< Kali overrides <<<
ZSHLOCAL
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
    fd \
    bat \
    lazygit \
    fastfetch \
    starship \
    btop \
    lazydocker; do
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
  printf '%s\n' "Note: the shared Git config enables GPG commit signing."
  printf '%s\n' "Configure a signing key in ~/.gitconfig.local, or override signing there."
}

main "$@"

