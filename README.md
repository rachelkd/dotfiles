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

Use `stow --adopt .` to adopt a folder if you try to stow a folder that already exists. Note that this will copy your files in `$HOME` to the dotfiles directory, and replace files in dotfiles.
