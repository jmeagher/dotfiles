
# Run the system wide completion setup
for file in /usr/local/etc/bash_completion /opt/local/etc/bash_completion /etc/bash_completion ; do
	[ -r "$file" ] && source "$file"
done

# run any user completion setup
if [ -d ~/.bash_completion.d ] ; then
    for file in ~/.bash_completion.d/* ; do
        [ -r "$file" ] && source "$file"
    done
fi
unset file

