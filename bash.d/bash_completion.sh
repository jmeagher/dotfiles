
# Run the system wide completion setup
for file in /usr/local/etc/bash_completion /opt/local/etc/bash_completion /etc/bash_completion ; do
	[ -r "$file" ] && source "$file"
done

# Special homebrew version
if [ "" != "`which brew 2> /dev/null `" ] ; then
  if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
  fi
fi

# run any user completion setup
if [ -d ~/.bash_completion.d ] ; then
    for file in ~/.bash_completion.d/* ; do
        [ -r "$file" ] && source "$file"
    done
fi

if [ -f ~/.bazel/bin/bazel-complete.bash ] ; then
  source ~/.bazel/bin/bazel-complete.bash 
fi
unset file

