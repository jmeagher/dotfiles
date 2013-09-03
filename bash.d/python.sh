
if [ "" != "`which python 2> /dev/null `" ] ; then
    function pyserver() {
        python -m SimpleHTTPServer
    }

    # Pretty print json: echo '{"json":{"foo":"bar", "baz":"blah"}}'  | jsonpp
    alias jsonpp="python -m json.tool"
fi

