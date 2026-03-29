
# Various setup things related to golang

if [ "" != "`which go 2> /dev/null `" ] ; then

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
