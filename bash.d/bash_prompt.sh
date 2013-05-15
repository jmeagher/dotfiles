
# Some of this is taken from from https://github.com/mathiasbynens/dotfiles


# Set a really fancy prompt
parse_git_branch() {
   git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/git:\1/'
}

parse_aws_info() {
    # To enable this the _AWS_CHECK variable will need to be defined somewhere else
    if [ "$_AWS_CHECK" = "" ] ; then

        TRY_EC2=false
        # Note, this is not the best check, but it's quick and should work for me
        # Need to get this to run once, but haven't figured it out yet
        uname -a | grep amzn >& /dev/null && TRY_EC2=true
        if [ "$TRY_EC2" = "true" ] ; then
            AWS_PROMPT=AWS
        #    EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
        #    INSTANCE_NAME="`ec2-describe-instances $EC2_INSTANCE_ID | grep TAG | grep Name | awk '{print $5}'`"
        #    if [ "$INSTANCE_NAME" != "" ] ; then
        #        AWS_PROMPT="AWS $INSTANCE_NAME $EC2_INSTANCE_ID"
        #    fi
        fi

        _AWS_CHECK=true
    fi
    echo -n $AWS_PROMPT
}


# Color test output from http://www.commandlinefu.com/commands/view/6533/print-all-256-colors-for-testing-term-or-for-a-quick-reference
# ( x=`tput op` y=`printf %$((${COLUMNS}-6))s`;for i in {0..256};do o=00$i;echo -e ${o:${#o}-3:3} `tput setaf $i;tput setab $i`${y// /=}$x;done; )
# 8 color version:  ( x=`tput op` y=`printf %$((${COLUMNS}-6))s`;for i in {0..7};do o=00$i;echo -e ${o:${#o}-3:3} `tput setaf $i;tput setab $i`${y// /=}$x;done; )

# Setup all the color variables
if [[ $COLORTERM = gnome-* && $TERM = xterm ]] && infocmp gnome-256color >/dev/null 2>&1; then
	export TERM=gnome-256color
elif infocmp xterm-256color >/dev/null 2>&1; then
	export TERM=xterm-256color
fi

HAS_TPUT=
tput setaf 1 &> /dev/null && HAS_TPUT=true
if [ "$HAS_TPUT" = "true" ] ; then
	tput sgr0
	if [[ `tput colors` -ge 256 ]] ; then
		BLACK=$(tput setaf 0)
		RED=$(tput setaf 1)
		GREEN=$(tput setaf 2)
		YELLOW=$(tput setaf 3)
		BLUE=$(tput setaf 4)
		MAGENTA=$(tput setaf 5)
		CYAN=$(tput setaf 6)
		WHITE=$(tput setaf 7)
	else
		BLACK=$(tput setaf 0)
		RED=$(tput setaf 1)
		GREEN=$(tput setaf 2)
		YELLOW=$(tput setaf 3)
		BLUE=$(tput setaf 4)
		MAGENTA=$(tput setaf 5)
		CYAN=$(tput setaf 6)
		WHITE=$(tput setaf 7)
	fi
	BOLD=$(tput bold)
	RESET=$(tput sgr0)
else
    # This doesn't work right now, not sure why, but tput seems pretty widely supported so it should be ok
	#BLACK="\033[1;30m"
	#RED="\033[1;31m"
	#GREEN="\033[1;32m"
	#YELLOW="\033[1;33m"
	#BLUE="\033[1;34m"
	#MAGENTA="\033[1;35m"
	#CYAN="\033[1;36m"
	#WHITE="\033[1;37m"
	#BOLD=""
	#RESET="\033[m"
fi

export BLACK
export RED
export GREEN
export YELLOW
export BLUE
export MAGENTA
export CYAN
export WHITE
export BOLD
export RESET



#PS1='\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\] \[\e[35m\]$(date +%Y-%m-%d\ %H:%M:%S)\[\e[0m\] \[\e[36m\]$(parse_git_branch)\[\e[0m\] \[\e[31m\]$(parse_aws_info)\[\e[0m\]\n\$ '

#PS1='\n${GREEN}\u@\h ${YELLOW}\w ${MAGENTA}]$(date +%Y-%m-%d\ %H:%M:%S) ${CYAN}$(parse_git_branch) ${RED}$(parse_aws_info)${RESET} \n$ '
#PS1="\n${GREEN}\u@\h ${YELLOW}\w ${MAGENTA}\$(date +%Y-%m-%d\ %H:%M:%S) ${CYAN}\$(parse_git_branch) ${RED}\$(parse_aws_info)${RESET} \n$ "

PS_BASIC="\n${GREEN}\u@\h ${YELLOW}\w ${MAGENTA}\$(date +%Y-%m-%d\ %H:%M:%S)"
PS_END="${RESET} \n$ "

PS_GIT="${CYAN}\$(parse_git_branch)"
PS_AWS="${RED}\$(parse_aws_info)"

PS1="$PS_BASIC $PS_GIT $PS_AWS $PS_END"


