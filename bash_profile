#! /bin/bash

if [ -f ~/.bash_profile_local_pre ]; then
        . ~/.bash_profile_local_pre
fi

if [ -d ~/bin ] ; then
    export PATH=~/bin:$PATH
fi

alias ls="ls -F -G"

# Setup common aliases
alias vi=vim

# Setup custom maven shortcuts
if [ "" != "`which mvn 2> /dev/null `" ] ; then
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

# Setup EC2 according to http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/SettingUp_CommandLine.html
if [ "" != "$EC2_HOME" ] ; then
    export PATH=$PATH:$EC2_HOME/bin

    # Check ~/.ec2/credentials.csv for AWS setup info
    if [ -f ~/.ec2/credentials.csv ] ; then
        export AWS_ACCESS_KEY=`cat ~/.ec2/credentials.csv | grep -v "User Name" | awk -F, '{print $2}' | sed 's/"//g'`
        export AWS_SECRET_KEY=`cat ~/.ec2/credentials.csv | grep -v "User Name" | awk -F, '{print $3}' | sed 's/"//g'`
    fi
fi


# Set a really fancy prompt
parse_git_branch() {
   git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/git:\1/'
}

parse_aws_info() {
    if [ "$_AWS_CHECK" = "" ] ; then

        TRY_EC2=false
        # Note, this is not the best check, but it's quick and should work for me
        # Need to get this to run once, but haven't figured it out yet
        uname -a | grep amzn >& /dev/null && TRY_EC2=true
        if [ "$TRY_EC2" = "true" ] ; then
            AWS_PROMPT=AWS
        #    EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
        #    INSTANCE_NAME="`ec2-describe-instances $EC2_INSTANCE_ID | grep TAG | grep Name | awk '{print $5}'`"
        #    if [ "$INSTANCE_NAME" != "" ] ; then
        #        AWS_PROMPT="AWS $INSTANCE_NAME $EC2_INSTANCE_ID"
        #    fi
        fi

        _AWS_CHECK=true
    fi
    echo -n $AWS_PROMPT
}


PS1='\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\] \[\e[35m\]$(date +%Y-%m-%d\ %H:%M:%S)\[\e[0m\] \[\e[36m\]$(parse_git_branch)\[\e[0m\] \[\e[31m\]$(parse_aws_info)\[\e[0m\]\n\$ '


if [ -f /opt/local/etc/bash_completion ]; then
        . /opt/local/etc/bash_completion
fi

if [ -f ~/.bash_profile_local ]; then
        . ~/.bash_profile_local
fi



