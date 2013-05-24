#! /bin/bash

# Pre-run overrides, if the files are defined
for file in ~/.{bash_profile_local_pre,bash_${HOSTNAME}_pre}; do
	[ -r "$file" ] && source "$file"
done
unset file


# Setup a few really basic things

# Lots of path overrides later ones take precedence 
for p in /usr/local/opt/coreutils/libexec/gnubin /usr/local/bin ~/bin ; do
    if [ -d $p ] ; then
        PATH=$p:$PATH
    fi
done
unset p
export PATH

# Handle mac vs gnu ls color options
ls --color >& /dev/null && alias ls="ls -F --color" || alias ls="ls -F -G"

# Setup common aliases
alias vi=vim

# A few things from https://github.com/mathiasbynens/dotfiles
# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# Append to the Bash history file, rather than overwriting it
shopt -s histappend

# Autocorrect typos in path names when using `cd`
shopt -s cdspell


# Run the bulk of the custom setup scripts
for file in `ls ~/.mydotfiles/bash.d/* | grep -v "~"` ; do
    source $file
done
unset file

# Final post-run options for local settings
for file in ~/.{bash_profile_local,bash_${HOSTNAME}}; do
	[ -r "$file" ] && source "$file"
done
unset file


