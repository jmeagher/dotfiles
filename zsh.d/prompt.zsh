

if [ ! -n "${ZSH_THEME+1}" ]; then
	ZSH_THEME="ys"
fi


if command -v powerline-go >& /dev/null && test ! -n "${SKIP_POWERLINE+1}" ; then

  if [ ! -n "${POWERLINE_MODE+1}" ]; then
  	POWERLINE_MODE="compatible"
  fi

  if [ ! -n "${POWERLINE_THEME+1}" ]; then
  	POWERLINE_THEME="default"
  fi

  function powerline_precmd() {
      eval "$(powerline-go \
        -mode $POWERLINE_MODE \
        -modules user,host,ssh,venv,terraform-workspace,jobs,perms,git,newline,time,exit,cwd,newline,root \
        -error $? \
        -theme $POWERLINE_THEME \
        -shell zsh \
        -eval \
        )"
  }

  function install_powerline_precmd() {
    for s in "${precmd_functions[@]}"; do
      if [ "$s" = "powerline_precmd" ]; then
        return
      fi
    done
    precmd_functions+=(powerline_precmd)
  }

  if [ "$TERM" != "linux" ]; then
      install_powerline_precmd
  fi

else

  # Custom zsh prompt — used when powerline-go is not available or SKIP_POWERLINE is set

  setopt PROMPT_SUBST

  parse_git_info() {
    if [ "" = "${SKIP_GIT_STATUS}" ] ; then
      GIT_BRANCH=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/git:\1/')
      GIT_EXTRA=$(git status --porcelain 2> /dev/null | cut -c 1-2 | tr "?" "N" | extsed 's/(.)/-\1/g' | tr "-" "\n" | sort | uniq | tr "\n" " " | sed "s/ //g")
    else
      GIT_BRANCH='git:unknown'
      GIT_EXTRA='skip'
    fi
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
      uname -a | grep amzn >& /dev/null && TRY_EC2=true
      if [ "$TRY_EC2" = "true" ] ; then
        AWS_PROMPT=AWS
      fi
      _AWS_CHECK=true
    fi
    echo -n $AWS_PROMPT
  }

  __DO_UNICODE=false
  [[ "$(locale charmap 2>/dev/null)" = "UTF-8" ]] && __DO_UNICODE=true
  export __DO_UNICODE

  prompt_time() {
    p_icon=
    if [ "$__DO_UNICODE" = "true" ] ; then
      declare -i t_hour=$(date +%H%M | sed 's/^0*//')
      if [[ $t_hour -lt 600 ]] ; then
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

  # Color setup using tput
  if [[ $COLORTERM = gnome-* && $TERM = xterm ]] && infocmp gnome-256color >/dev/null 2>&1; then
    export TERM=gnome-256color
  elif infocmp xterm-256color >/dev/null 2>&1; then
    export TERM=xterm-256color
  fi

  HAS_TPUT=
  tput setaf 1 &> /dev/null && HAS_TPUT=true
  if [ "$HAS_TPUT" = "true" ] ; then
    tput sgr0
    if [[ $(tput colors) -ge 256 ]] ; then
      _BLACK=$(tput setaf 0)
      _RED=$(tput setaf 124)
      _GREEN=$(tput setaf 46)
      _YELLOW=$(tput setaf 192)
      _BLUE=$(tput setaf 25)
      _MAGENTA=$(tput setaf 129)
      _CYAN=$(tput setaf 51)
      _WHITE=$(tput setaf 15)
      _BRIGHT_YELLOW=$(tput setaf 226)
    else
      _BLACK=$(tput setaf 0)
      _RED=$(tput setaf 1)
      _GREEN=$(tput setaf 2)
      _YELLOW=$(tput setaf 3)
      _BLUE=$(tput setaf 4)
      _MAGENTA=$(tput setaf 5)
      _CYAN=$(tput setaf 6)
      _WHITE=$(tput setaf 7)
      _BRIGHT_YELLOW=$(tput setaf 3)
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
    _BRIGHT_YELLOW="\033[33m"
  fi

  export _BLACK _RED _GREEN _YELLOW _BLUE _MAGENTA _CYAN _WHITE _BOLD _RESET

  # Build prompt pieces
  _PS_USER="%{${_GREEN}%}%n%{${_WHITE}%}@%{${_BRIGHT_YELLOW}%}%m"
  _PS_TIME="%{${_MAGENTA}%}\$(prompt_time)"
  _PS_STATUS="%(?.%{${_GREEN}%}0%{${_RESET}%}.%{${_RED}%}%?%{${_RESET}%})"
  _PS_DIR="%{${_YELLOW}%}%~"

  if command -v git > /dev/null 2>&1 ; then
    _PS_GIT="%{${_CYAN}%}\$(parse_git_info)"
  else
    _PS_GIT=
  fi

  _PS_AWS="%{${_WHITE}%}\$(parse_aws_info)"

  PROMPT=$'\n'"${_PS_USER} ${_PS_TIME} %{${_YELLOW}%}[${_PS_STATUS}%{${_YELLOW}%}]"$'\n'"${_PS_DIR} ${_PS_GIT} ${_PS_AWS}%{${_RESET}%}"$'\n'"$ "

fi