
# Some of this is taken from from https://github.com/mathiasbynens/dotfiles


parse_git_branch() {
  GIT_BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/git:\1/'`
  # Can't figure out how to get this to work with the built in OSX sed
  GIT_EXTRA=`git status --porcelain 2> /dev/null | cut -c 1-2 | tr "?" "N" | extsed 's/(.)/-\1/g' | tr "-" "\n" | sort | uniq | tr "\n" " " | sed "s/ //g"`
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


if [ "" != "`which rbenv 2> /dev/null `" ] ; then
  _RUBY_CHECK=rbenv
elif [ "" != "`which rvm 2> /dev/null `" ] ; then
  _RUBY_CHECK=rvm
else
  _RUBY_CHECK=
fi

parse_ruby_info() {
  if [ -e ~/.ruby_prompt ] ; then
    _RUBY_DATA=$(cat ~/.ruby_prompt)
    _PROMPT_DATA=${_RUBY_DATA%% *}
    _RV=${_RUBY_DATA##* }
    _LAST_RUBY_DIR=${_PROMPT_DATA%%:*}
    _LAST_RUBY_TIME=${_PROMPT_DATA##*:}
  else
    _LAST_RUBY_DIR=/blah
    _LAST_RUBY_TIME=0
    _RV=
  fi

  if [ "$_LAST_RUBY_DIR" = "$PWD" ] ; then
    if [ $_LAST_RUBY_TIME -gt $(($(date +%s)-60)) ] ; then
      _RUBY_STAT=skip
    fi
  else
    _LAST_RUBY_DIR="$PWD"
    export _LAST_RUBY_DIR
    _RUBY_STAT=
  fi

  if [ "$_RUBY_STAT" != "skip" ] ; then

    if [ "$_RUBY_CHECK" = "rbenv" ] ; then
      _RV=$(rbenv version | cut -f1 -d ' ')
      if [ "" != "$_RV" ] ; then
        _GS=$(rbenv gemset active 2>&1 | grep -v "no active gemse" | sed "s/\bglobal\b//" | sed "s/ $//")
        if [ "$_GS" != "" ] ; then
          _RV="$_RV($_GS)"
        fi
      fi
    elif [ "$_RUBY_CHECK" = "rvm" ] ; then
      _RV=$(rvm list 2>&1 | egrep '^=. ' | cut -d' ' -f2)
    fi

    if [ "$_RV" != "" ] ; then
      _RP=$_RUBY_CHECK:$_RV
    fi

  fi

  echo -ne $_RV
  echo "$PWD:$(date +%s) $_RV" > ~/.ruby_prompt

}

parse_last_command_error() {
  code=$?
  if [ "$code" != "0" ] ; then
    echo "Err ◕︵◕ $code"
  fi
}

__DO_UNICODE=false
[[ "$(locale charmap)" = "UTF-8" ]] && __DO_UNICODE=true
export __DO_UNICODE
prompt_time() {
  p_icon=
  if [ "$__DO_UNICODE" = "true" ] ; then
    declare -i t_hour=$(date +%H%M | sed 's/^0*//')
    if [[ $t_hour -lt 0600 ]] ; then 
      p_icon="☣  "
    elif [[ $t_hour -lt 1100 ]] ; then 
      p_icon="☕  "
    elif [[ $t_hour -lt 1330 ]] ; then
      p_icon="🍔  "
    elif [[ $t_hour -lt 1600 ]] ; then
      p_icon="☀  "
    elif [[ $t_hour -lt 2200 ]] ; then 
      p_icon="🍺  "
    else
      p_icon="☣  "
    fi
  fi
  echo -n "${p_icon}$(date +%Y-%m-%d\ %H:%M:%S)"
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
		_BLACK=$(tput setaf 0)
		_RED=$(tput setaf 124)
		_GREEN=$(tput setaf 46)
		_YELLOW=$(tput setaf 192)
		_BLUE=$(tput setaf 25)
		_MAGENTA=$(tput setaf 129)
		_CYAN=$(tput setaf 51)
		_WHITE=$(tput setaf 15)
	else
		_BLACK=$(tput setaf 0)
		_RED=$(tput setaf 1)
		_GREEN=$(tput setaf 2)
		_YELLOW=$(tput setaf 3)
		_BLUE=$(tput setaf 4)
		_MAGENTA=$(tput setaf 5)
		_CYAN=$(tput setaf 6)
		_WHITE=$(tput setaf 7)
	fi
	_BOLD=$(tput bold)
	_RESET=$(tput sgr0)
else
	_BLACK="\033[30m"
	_RED="\033[31m"
	_GREEN="\033[32m"
	_YELLOW="\033[33m"
	_BLUE="\033[34m"
	_MAGENTA="\033[35m"
	_CYAN="\033[36m"
	_WHITE="\033[37m"
	_BOLD=""
	_RESET="\033[m"
fi
# Couldn't get this one working the same was with tput
TITLE="\e]0;"

export _BLACK
export _RED
export _GREEN
export _YELLOW
export _BLUE
export _MAGENTA
export _CYAN
export _WHITE
export _BOLD
export _RESET


# Now build up all the pieces of the command prompt
PS_TITLE="\[$TITLE\w\a\]"
PS_USER="\[${_GREEN}\]\u@\h"
PS_DIR="\[${_YELLOW}\]\w"
PS_ERROR="\[$_RED\]\$(parse_last_command_error)"
PS_END="\n\[${_RESET}\]$ "

PS_TIME="\[${_MAGENTA}\]\$(prompt_time)"

# Extra stuff
if [ "" != "`which git 2> /dev/null `" ] ; then
  PS_GIT="\[${_CYAN}\]\$(parse_git_branch)"
else
  PS_GIT=
fi

PS_AWS="\[${_WHITE}\]\$(parse_aws_info) "

parse_ruby_info 2>&1 > /dev/null
if [ "false" != "_RUBY_CHECK" ] ; then
  PS_RUBY="\[${_BLUE}\]\$(parse_ruby_info)"
else
  PS_RUBY=
fi

# And put them all together
PS1="${PS_TITLE}${PS_ERROR}\n${PS_USER} ${PS_TIME}\n${PS_DIR} ${PS_GIT} ${PS_RUBY} ${PS_AWS} ${PS_EXTRAS} ${PS_END}"


