
for file in /usr/local/etc/bash_completion /opt/local/etc/bash_completion /etc/bash_completion ; do
	[ -r "$file" ] && source "$file"
done
unset file

