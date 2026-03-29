
# Setup custom maven shortcuts
if [ "" != "`which mvn 2> /dev/null `" ] ; then
    function m() {
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
    alias mqp="m package -DskipTests"
fi


