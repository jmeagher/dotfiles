# Make sure this is only runs once to block include loops
if [ "$__BASHRC_RUN" = "" ] ; then
__BASHRC_RUN=true

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Change so bash_profile includes this instead
#if [ ~/.bash_profile ]; then
#  [ -n "$PS1" ] && source ~/.bash_profile
#fi 

fi
