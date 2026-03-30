#!/bin/sh
# shell_config.sh — entry point for shell configuration
# Sources shared scripts (sh.d), then shell-specific scripts (bash.d or zsh.d)

# Resolve the dotfiles directory regardless of how this file is sourced
if [ -n "$ZSH_VERSION" ]; then
  _DOTFILES=$(dirname "${(%):-%x}")
else
  _DOTFILES=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
fi

# Source shared scripts (compatible with both bash and zsh)
for _f in "$_DOTFILES/sh.d"/*.sh; do
  [ -r "$_f" ] && . "$_f"
done

# Source shell-specific scripts
if [ -n "$ZSH_VERSION" ]; then
  for _f in "$_DOTFILES/zsh.d"/*.sh(N) "$_DOTFILES/zsh.d"/*.zsh(N); do
    [ -r "$_f" ] && . "$_f"
  done
elif [ -n "$BASH_VERSION" ]; then
  for _f in "$_DOTFILES/bash.d"/*.sh; do
    [ -r "$_f" ] && . "$_f"
  done
fi

unset _f _DOTFILES
