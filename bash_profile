if [ -d ~/bin ] ; then
    export PATH=~/bin:$PATH
fi

alias ls="ls -F -G"

# Setup common aliases
alias vi=vim

# Setup custom maven shortcuts
if [ "" != "`which mvn`" ] ; then
    m() {
        start=`pwd`
        found=false
        top=
        d=`pwd`
        while [ "$d" != "/" ] ; do
            echo "Check $d"
            if [ -e $d/pom.xml ] ; then
                found=true
                top=$d
                d=/
            else 
                cd ..
                d=`pwd`
            fi
        done
        if [ -e $top/pom.xml ] ; then
            cd $top
            mvn "$@"
            cd $start
        else 
            echo "Couldn't find pom.xml file"
            cd $start
        fi
    }
    #alias m=mvn
    alias mci="m clean install"
    alias mt="m surefire-report:report"
    alias msetup="m eclipse:eclipse -DdownloadSources=true"
    alias mc="m compiler:compile"
    alias mdt="m dependency:tree"
fi


# Set a default prompt of: user@host and current_directory and git branch
parse_git_branch() {
   git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/git:\1/'
}
PS1='\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\] \[\e[35m\]$(date +%Y-%m-%d\ %H:%M:%S)\[\e[0m\] \[\e[36m\]$(parse_git_branch)\[\e[0m\]\n\$ '


if [ -f /opt/local/etc/bash_completion ]; then
        . /opt/local/etc/bash_completion
fi

if [ -f ~/.bash_profile_local ]; then
        . ~/.bash_profile_local
fi



