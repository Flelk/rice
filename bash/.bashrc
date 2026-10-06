#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Just flelk >
# PS1='\[\e[1;37m\]\u\[\e[0m\] \[\e[90m\]>\[\e[0m\] '

# With the File Path
PS1='\[\e[1;37m\]\u\[\e[0m\] \[\e[90m\]\w >\[\e[0m\] '
