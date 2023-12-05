#! /bin/bash

# get the aliases and functions
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Pre-run overrides, if the files are defined
for file in ~/.{bash_profile_local,bash_$(hostname),bash_$(hostname -s)}_pre; do
  [ -r "$file" ] && source "$file"
done


# Setup a few really basic things

if [ "" = "$EDITOR" ] ; then
  # Preferred editor list
  for EDITOR in vim vi ; do
    if command -v $EDITOR >& /dev/null ; then
      export EDITOR
      break
    else
      unset EDITOR
    fi
  done
fi

for TRY in mvim $EDITOR ; do
	if command -v $TRY >& /dev/null ; then
		alias e="$TRY"
		break
	fi
done

# Lots of path overrides later ones take precedence 
for p in /usr/local/opt/coreutils/libexec/gnubin /usr/local/bin ~/bin ; do
  if [ -d $p ] ; then
    PATH=$p:$PATH
    export PATH
  fi
done
unset p

if [ -d /usr/local/opt/coreutils/libexec/gnuman ] ; then
  MANPATH="/usr/local/opt/coreutils/libexec/gnuman:$MANPATH"
  export MANPATH
fi

# Handle mac vs gnu ls color options
ls --color >& /dev/null && alias ls="ls -F --color" || alias ls="ls -F -G"

# Setup common aliases
alias vi=vim

# Get less to support ansi codes in files
alias less="less -r"

# A few things from https://github.com/mathiasbynens/dotfiles
# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# Append to the Bash history file, rather than overwriting it
shopt -s histappend

# Autocorrect typos in path names when using `cd`
shopt -s cdspell


# Run the bulk of the custom setup scripts
for file in ~/.mydotfiles/bash.d/*.sh ; do
  source $file
done

# Final post-run options for local settings
for file in ~/.{bash_profile_local,bash_$(hostname),bash_$(hostname -s)}; do
  [ -r "$file" ] && source "$file"
done
unset file


. "$HOME/.cargo/env"
