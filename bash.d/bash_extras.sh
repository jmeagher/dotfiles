alias sumit="awk '{s+=\$1} END {print s}'"
alias fgr="grep -riHn"

# Nifty helper from @onelinetips and @jakehofman
alias gtip="curl -s jakehofman.com/lists/tips.txt | grep -i"

alias rebash="source ~/.bash_profile"

# Detect non-ascii characters
nonascii() { LANG=C grep --color=always '[^ -~]\+'; }

# History control, skip dups
export HISTCONTROL=erasedups

