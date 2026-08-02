# ShedOS Bash Configuration
# shellcheck shell=bash

# Interactive shells only.
[[ $- != *i* ]] && return

# ble.sh drives autosuggestions and syntax highlighting. Sourced first
# with --noattach and attached on the last line — the order ble.sh and
# starship both document.
[[ -f /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh --noattach

# ─────────────────────────────────────────────────────────────
# Environment Variables
# ─────────────────────────────────────────────────────────────

# Editors
export EDITOR="nvim"
export VISUAL="nvim"
export SUDO_EDITOR="nvim"

# Terminal
export TERMINAL="kitty"

# XDG Base Directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Locale comes from /etc/locale.conf; not forced here.

# Path additions (guarded so a re-sourced rc doesn't stack duplicates)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH" ;;
esac

# Man pages
export MANPAGER="nvim +Man!"
export MANWIDTH=999

# ─────────────────────────────────────────────────────────────
# History + shell options
# ─────────────────────────────────────────────────────────────

HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize globstar cdspell autocd

# ─────────────────────────────────────────────────────────────
# mise (runtime version manager)
# ─────────────────────────────────────────────────────────────

if command -v mise &> /dev/null; then
    eval "$(mise activate bash)"
fi

# ─────────────────────────────────────────────────────────────
# Modern CLI Replacements
# ─────────────────────────────────────────────────────────────

# The modern CLI tools (eza, bat, fd, dust, duf, procs, btm) are installed
# under their own names — the core commands are never aliased over, so
# scripts and muscle memory get exactly what they ask for.

# eza extras (ls itself stays ls)
if command -v eza &> /dev/null; then
    alias ll="eza -la --icons --group-directories-first"
    alias lt="eza -T --icons --level=2"
    alias la="eza -a --icons --group-directories-first"
fi

# bat with paging, without touching cat
if command -v bat &> /dev/null; then
    alias catp="bat"
fi

# zoxide: the z command, cd untouched
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# ─────────────────────────────────────────────────────────────
# Git Aliases
# ─────────────────────────────────────────────────────────────

alias g="git"
alias ga="git add"
alias gaa="git add --all"
alias gc="git commit -v"
alias gcm="git commit -m"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gd="git diff"
alias gds="git diff --staged"
alias gf="git fetch"
alias gl="git pull"
alias gp="git push"
alias gst="git status"
alias glog="git log --oneline --graph --all"
alias lg="lazygit"

# ─────────────────────────────────────────────────────────────
# Docker Aliases
# ─────────────────────────────────────────────────────────────

alias d="docker"
alias dc="docker-compose"
alias dps="docker ps"
alias dpsa="docker ps -a"
alias di="docker images"
alias drm="docker rm"
alias drmi="docker rmi"
alias dex="docker exec -it"
alias dlogs="docker logs -f"
alias lzd="lazydocker"

# ─────────────────────────────────────────────────────────────
# Kubernetes Aliases
# ─────────────────────────────────────────────────────────────

alias k="kubectl"
alias kgp="kubectl get pods"
alias kgs="kubectl get services"
alias kgd="kubectl get deployments"
alias kgn="kubectl get nodes"
alias kdp="kubectl describe pod"
alias klogs="kubectl logs -f"
alias kex="kubectl exec -it"
alias kctx="kubectx"
alias kns="kubens"

# ─────────────────────────────────────────────────────────────
# System Aliases
# ─────────────────────────────────────────────────────────────

alias v="nvim"
alias vim="nvim"
alias vi="nvim"
alias c="clear"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ports="ss -tulpn"

# Package management goes through shedman (snapshots + review flow):
#   shedman install / update / uninstall

# ─────────────────────────────────────────────────────────────
# FZF Configuration
# ─────────────────────────────────────────────────────────────

# Colors come from the active ShedOS theme; the Mocha block below is
# the fallback when the render is missing.
if [[ -f /etc/shedos/themes/current/fzf.bash ]]; then
    source /etc/shedos/themes/current/fzf.bash
else
    export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--border='rounded' --border-label='' --preview-window='border-rounded' \
--prompt=' ' --marker='󰸞 ' --pointer=' ' --separator='─'"
fi

# Use fd for fzf
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"

# Enable fzf
[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash

# ─────────────────────────────────────────────────────────────
# Direnv
# ─────────────────────────────────────────────────────────────

if command -v direnv &> /dev/null; then
    eval "$(direnv hook bash)"
fi

# ─────────────────────────────────────────────────────────────
# Custom Functions
# ─────────────────────────────────────────────────────────────

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

# Extract any archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.tar.xz)    tar xJf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Find in files
fif() {
    rg --column --line-number --no-heading --color=always --smart-case "$@" |
        fzf --ansi --delimiter : \
            --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
            --preview-window up,60%,border-bottom
}

# ─────────────────────────────────────────────────────────────
# Prompt
# ─────────────────────────────────────────────────────────────

# Rendered per-theme by shedman theme apply. The :- default keeps any
# value a user set before this line; point it at a copy to customize.
export STARSHIP_CONFIG="${STARSHIP_CONFIG:-/etc/shedos/themes/current/starship.toml}"
eval "$(starship init bash)"

# ─────────────────────────────────────────────────────────────
# ShedOS Welcome; fastfetch on first interactive shell per session.
# Marker lives in XDG_RUNTIME_DIR (tmpfs, cleared on reboot / final logout),
# so the banner shows once per boot and stays quiet for subsequent terminals.
# ─────────────────────────────────────────────────────────────

_shedos_runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
_shedos_marker="$_shedos_runtime/shedos-welcome-shown"
if [[ -d "$_shedos_runtime" && ! -e "$_shedos_marker" ]]; then
    fastfetch 2>/dev/null || true
    : > "$_shedos_marker" 2>/dev/null
fi
unset _shedos_runtime _shedos_marker

[[ ${BLE_VERSION-} ]] && ble-attach
