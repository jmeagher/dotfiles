

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

fi