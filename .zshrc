# ============================================================================
# PATH Configuration
# ============================================================================

# Homebrew
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# TeX Live 2024
export PATH="/usr/local/texlive/2024/bin/universal-darwin:$PATH"

# JupyterLab
export PATH="/opt/homebrew/opt/jupyterlab/bin/jupyter-lab:$PATH"

# Qt5
export PATH="/opt/homebrew/opt/qt@5/bin:$PATH"

# Local binaries
export PATH="$HOME/.local/bin:$PATH"

# SSL Certificate for Ruby/OpenSSL
export SSL_CERT_FILE=/etc/ssl/cert.pem

# Google Cloud SDK
if [ -f '/Users/rachel/google-cloud-sdk/path.zsh.inc' ]; then
  . '/Users/rachel/google-cloud-sdk/path.zsh.inc'
fi
if [ -f '/Users/rachel/google-cloud-sdk/completion.zsh.inc' ]; then
  . '/Users/rachel/google-cloud-sdk/completion.zsh.inc'
fi

# ============================================================================
# Zinit Plugin Manager
# ============================================================================

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit if not present
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

# Plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Oh My Zsh snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit
zinit cdreplay -q

# ============================================================================
# History Configuration
# ============================================================================

HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_save_no_dups
setopt hist_ignore_all_dups
setopt hist_find_no_dups

# ============================================================================
# Keybindings
# ============================================================================

bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# ============================================================================
# Completion Styling
# ============================================================================

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -G $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls -G $realpath'

# ============================================================================
# Aliases
# ============================================================================

alias ls='ls -G'
alias vim='nvim'
alias c='clear'
alias cc='claude'

# ============================================================================
# Functions
# ============================================================================

# Claude Code wrapper to fix zoxide compatibility
claude() {
  SHELL=/bin/bash command claude "$@"
}

# ============================================================================
# Conda (managed by conda init)
# ============================================================================

__conda_setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup

# ============================================================================
# Shell Integrations
# ============================================================================

eval "$(starship init zsh)"
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
eval "$(rbenv init - zsh)"
