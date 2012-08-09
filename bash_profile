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


# Set a default prompt of: user@host and current_directory and git branch
parse_git_branch() {
   git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/git:\1/'
}
PS1='\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\] \[\e[36m\]$(parse_git_branch)\[\e[0m\]\n\$ '


if [ -f /opt/local/etc/bash_completion ]; then
        . /opt/local/etc/bash_completion
fi

if [ -f ~/.bash_profile_local ]; then
        . ~/.bash_profile_local
fi



