alias sumit="awk '{s+=\$1} END {print s}'"
alias avg="awk '{s+=\$1; count++} END {print s/count}'"
alias stdev="awk '{sum+=\$1; sumsq+=\$1*\$1} END {print sqrt(sumsq/NR - (sum/NR)**2)}'"
alias fgr="grep -riHn"

# Nifty helper from @onelinetips and @jakehofman
alias gtip="curl -s jakehofman.com/lists/tips.txt | grep -i"

# From @climagic: https://twitter.com/climagic/status/413868766993190912
scp(){ if [[ "$@" =~ : ]];then /usr/bin/scp $@ ; else echo 'You forgot the colon dumbass!'; fi;}

alias ssh-add-day='ssh-add -t 70000'
