# ~/.config/bash/00-options.sh — shell options & history

# don't put duplicate lines or lines starting with space in the history
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# history length
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and update LINES/COLUMNS
shopt -s checkwinsize
