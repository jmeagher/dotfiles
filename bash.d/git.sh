if [ "" != "`which git 2> /dev/null `" ] ; then
    function git_all_status() {
        for g in */.git ; do
            echo ""
            echo "*****************************"
            #d=`dirname $g`
            cd `dirname $g`
            #echo $d
            git status -s
            cd ..
        done

    }
fi

