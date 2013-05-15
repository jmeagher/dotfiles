
for file in /opt/local/etc/bash_completion /etc/bash_completion ; do
	[ -r "$file" ] && source "$file"
done
unset file

