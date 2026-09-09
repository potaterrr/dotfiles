# ~/.config/bash/30-aliases.sh — aliases

# APT shortcuts
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install -y'
alias remove='sudo apt purge -y && sudo apt autoremove -y'
alias search='apt search'

# general shortcuts
alias c='clear'
alias ..='cd ..'
alias reload='source ~/.bashrc'
alias basher='${EDITOR:-nano} ~/.config/bash/'

# opencode
alias code='opencode'

# ls colors
if command -v dircolors >/dev/null 2>&1; then
    [ -r ~/.dircolors ] && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
fi

# code editor
alias edit='nvim'
