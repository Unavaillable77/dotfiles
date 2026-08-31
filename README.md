# Unavaillable77's Dotfiles

My personal terminal and development setup for **macOS** and **Kali Linux**, managed with **GNU Stow**.
![iTerm2 setup screenshot](./.github/images/setup_screenshot.png)

## The setup is built around:
- Zsh + Oh My Zsh
- Starship
- Tmux
- Neovim + LazyVim
- Lazygit
- iTerm2 on macOS
- Kitty on Kali Linux
- Nerd Fonts
- Git, bat, fd, fzf, ripgrep, zoxide and other CLI tools

## Highlights
- Shared terminal environment across macOS and Kali Linux
- Platform-specific install scripts
- Dotfiles managed using GNU Stow
- Zsh with plugins, aliases and local overrides
- Tmux with Catppuccin
- Neovim/LazyVim development environment
- Nerd Font support for terminal icons
- Machine-specific Git and shell configuration kept outside the repository

## Installation

Clone the repository:

```bash
git clone https://github.com/Unavaillable77/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash ./install_mac.sh / bash ./install_kali.sh
```

> [!NOTE]
> Please backup configurations before running script.


## Acknowledgements

Inspired by various resources shared by the vibrant open-source community, including online resources and dotfiles repositories:

- [Rohit's dotfiles](https://github.com/guptarohit/dotfiles)
- [GitHub ❤ ~/](http://dotfiles.github.io/)
- [Using stow for dotfiles (video)](https://www.youtube.com/watch?v=y6XCebnB9gs)
- [Mathias's dotfiles](https://github.com/mathiasbynens/dotfiles)
- [Artem's dotfiles](https://github.com/sapegin/dotfiles)
- [Nico's dotfiles](https://github.com/snics/dotfiles)
- [Jonas's dotfiles](https://github.com/JDevlieghere/dotfiles)
- [Alan's dotfiles](https://github.com/apinstein/dotfiles)
