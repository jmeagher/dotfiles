
	if command -v powerline-go >& /dev/null ; then

  if [ ! -n "${POWERLINE_MODE+1}" ]; then
  	POWERLINE_MODE="compatible"
  fi

  if [ ! -n "${POWERLINE_THEME+1}" ]; then
  	POWERLINE_THEME="default"
  fi

  function powerline_precmd() {
      eval "$(powerline-go \
        -mode $POWERLINE_MODE \
        -modules user,host,ssh,time,venv,terraform-workspace,jobs,perms,git,newline,exit,cwd,root \
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