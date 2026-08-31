# Minimal macOS terminal environment for the dotfiles.
#
# Keep this focused on dependencies used by the shell/Git/tmux/Micro setup.
# Personal apps and language-specific development toolchains belong elsewhere.

# Core shell / dotfile tooling
brew 'git'
brew 'wget'
brew 'stow'
brew 'tmux'
brew 'micro'

# Shell navigation / fuzzy search / file tools
brew 'fzf'
brew 'fd'
brew 'ripgrep'
brew 'eza'
brew 'zoxide'
brew 'bat'
brew 'bat-extras' # various cli tools integrate with bat
brew 'tldr'
brew 'jq'
brew 'jless'
brew 'tree' # pretty-print directory contents
brew 'fastfetch' # system info script

# Prompt
brew 'starship'

# Git config dependencies
brew 'git-delta'
brew 'difftastic'
brew 'lazygit' # TUI for git commands

# The tracked Git config contains Git LFS filters. Keeping git-lfs avoids
# failures if this machine later opens a repository that uses LFS.
brew 'git-lfs'

# Terminal application
cask 'iterm2'

# One Nerd Font is enough for Starship and tmux icon glyphs.
cask 'font-fira-code-nerd-font'

# Fonts
cask 'font-0xproto-nerd-font'
cask 'font-cascadia-code'
cask 'font-commit-mono'
cask 'font-commit-mono-nerd-font'
cask 'font-fira-code'
cask 'font-hack'
cask 'font-hack-nerd-font'
cask 'font-monaspace'
cask 'font-monaspace-nerd-font'