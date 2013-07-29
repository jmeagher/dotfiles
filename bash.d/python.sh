
if [ "" != "`which python 2> /dev/null `" ] ; then
    function pyserver() {
        python -m SimpleHTTPServer
    }
fi
