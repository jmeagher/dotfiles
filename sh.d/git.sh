if [ "" != "`which git 2> /dev/null `" ] ; then
    function git_all_status() {
        for g in */.git ; do
            cd $(dirname $g)
            git status -s
            cd ..
            echo ""
        done

    }
    alias gitup='for D in $(ls -df */.git) ; do echo $(dirname $D) ; (cd $(dirname $D) && pwd && git pull); done'
fi

