
if command -v mcfly > /dev/null 2>&1; then
  export MCFLY_FUZZY=2
  if [ -n "$BASH_VERSION" ]; then
    eval "$(mcfly init bash)"
  elif [ -n "$ZSH_VERSION" ]; then
    eval "$(mcfly init zsh)"
  fi
fi
