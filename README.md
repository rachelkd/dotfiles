# Dotfiles

This directory contains the dotfiles for my system.

## Requirements

### Git

### Stow

```
brew install stow
```

## Installation

```
git clone https://github.com/rachelkd/dotfiles.git
cd dotfiles
```

Then, use GNU Stow to symlink the dotfiles:

```
stow .
```

## Tips

### Adding a new config to dotfiles

1. Create the directory structure in dotfiles:
   ```
   mkdir -p .config/newapp
   ```

2. Use stow with --adopt to move files from HOME into dotfiles:
   ```
   stow --adopt .
   ```

This will move the existing files from `~/.config/newapp` into `~/dotfiles/.config/newapp` and replace them with symlinks.
