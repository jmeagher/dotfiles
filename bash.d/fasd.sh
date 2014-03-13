

if [ "" != "`which fasd 2> /dev/null `" ] ; then
  eval "$(fasd --init auto)"
  alias fv="fasd -aie $EDITOR"
  alias v="fasd -aie $EDITOR"
  alias d="fasd_cd -di"

  # Copied from the fasd init code to detect completion
  if [ "$BASH_VERSION" ] && complete > /dev/null 2>&1; then # bash
    complete -F _fasd_bash_cmd_complete d
    complete -F _fasd_bash_cmd_complete v
    complete -F _fasd_bash_cmd_complete fv
  fi
else
  function setup_fasd() {
    echo "Setting up fasd in ~/bin"
    ( cd ~; mkdir -p .tools; cd .tools ; git clone git@github.com:clvv/fasd.git; cd ~/bin; ln -s ../.tools/fasd/fasd . )
  }
fi

