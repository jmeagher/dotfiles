
# Various setup things related to golang

if command -v go > /dev/null 2>&1 ; then

    if [ "" = "$GOPATH" ] ; then
        GOPATH=~/.gocode
        if [ ! -e $GOPATH ] ; then
            mkdir -p $GOPATH
        fi

    fi
    PATH=$PATH:$GOPATH/bin
    export GOPATH
    export PATH
fi
