if [ -d ~/bin ] ; then
    export PATH=~/bin:$PATH
fi

alias ls="ls -F -G"

# Setup common aliases
alias vi=vim

# Setup custom maven shortcuts
if [ "" != "`which mvn`" ] ; then
    alias m=mvn
    alias mci="mvn clean install"
    alias mt="mvn surefire-report:report"
    alias msetup="mvn eclipse:eclipse -DdownloadSources=true"
    alias mc="mvn compiler:compile"
    alias mdt="mvn dependency:tree"
fi

alias gitui="/Applications/SourceTree.app/Contents/MacOS/SourceTree"


# Set a default prompt of: user@host and current_directory
PS1='\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\]\n\$ '


if [ -f /opt/local/etc/bash_completion ]; then
        . /opt/local/etc/bash_completion
fi


