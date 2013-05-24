
# Some of this is taken from from https://github.com/mathiasbynens/dotfiles


parse_git_branch() {
   GIT_BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/git:\1/'`
   GIT_MOD=`git status -s 2> /dev/null | egrep "^ ?M" > /dev/null && echo M`
   GIT_ADD=`git status -s 2> /dev/null | egrep "^ ?A" > /dev/null && echo A`
   GIT_NEW=`git status -s 2> /dev/null | egrep "^\?\?" > /dev/null && echo N`
   GIT_EXTRA=${GIT_MOD}${GIT_NEW}${GIT_ADD}
   if [ "$GIT_EXTRA" = "" ] ; then
       echo "$GIT_BRANCH"
   else
       echo "$GIT_BRANCH (${GIT_EXTRA})"
   fi
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
            # The instance printing proved too slow, just print AWS instead
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

parse_last_command_error() {
    code=$?
    if [ "$code" != "0" ] ; then
        echo "Err: $code "
    fi
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
		RED=$(tput setaf 124)
		GREEN=$(tput setaf 46)
		YELLOW=$(tput setaf 192)
		BLUE=$(tput setaf 39)
		MAGENTA=$(tput setaf 129)
		CYAN=$(tput setaf 39)
		WHITE=$(tput setaf 15)
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
	BLACK="\033[30m"
	RED="\033[31m"
	GREEN="\033[32m"
	YELLOW="\033[33m"
	BLUE="\033[34m"
	MAGENTA="\033[35m"
	CYAN="\033[36m"
	WHITE="\033[37m"
	BOLD=""
	RESET="\033[m"
fi
# Couldn't get this one working the same was with tput
TITLE="\e]0;"

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


# Now build up all the pieces of the command prompt
PS_TITLE="\[$TITLE\w\a\]"
PS_BASIC="\[${GREEN}\]\u@\h \[${YELLOW}\]\w \[${MAGENTA}\]\$(date +%Y-%m-%d\ %H:%M:%S)"
PS_ERROR="\[$RED\]\$(parse_last_command_error)"
PS_END="\n\[${RESET}\]$ "

# Extra stuff
if [ "" != "`which git 2> /dev/null `" ] ; then
    PS_GIT="\[${CYAN}\]\$(parse_git_branch)"
fi

PS_AWS="\[${WHITE}\]\$(parse_aws_info)"

# And put them all together
PS1="${PS_TITLE}${PS_ERROR}\n${PS_BASIC} ${PS_GIT} ${PS_AWS} ${PS_EXTRAS} ${PS_END}"


