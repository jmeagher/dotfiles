
alias rebash="source ~/.bash_profile"

# Detect non-ascii characters
nonascii() { LANG=C grep --color=always '[^ -~]\+'; }

# History control, skip dups
export HISTCONTROL=erasedups


if [ "" != "`which tput 2> /dev/null `" ] ; then
  alias diffw='diff -W $(( $(tput cols) - 2 ))'
else
  alias diffw='diff -W $(( $COLUMNS - 2 ))'
fi

