# From this with some tweaks https://developer.1password.com/docs/ssh/agent/
if [ -e ~/.1password/agent.sock ] ; then
  if [ "" = "$SSH_AUTH_SOCK" ] ; then
    export SSH_AUTH_SOCK=~/.1password/agent.sock
  fi
fi