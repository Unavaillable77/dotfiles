#!/bin/bash

# Encoding stuff for the terminal
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# (macOS-only) Prevent Homebrew from reporting - https://github.com/Homebrew/brew/blob/master/docs/Analytics.md
export HOMEBREW_NO_ANALYTICS=1

# golang paths
export GOPATH=$HOME/GolandProjects
export PATH="$GOPATH/bin:$PATH"

# User-installed binaries
export PATH="$HOME/.local/bin:$PATH"

# Tools
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"

## Modern fzf floating layout
export FZF_DEFAULT_OPTS="--height 40% --border --inline-info"
export FZF_CTRL_R_OPTS="--sort --exact"