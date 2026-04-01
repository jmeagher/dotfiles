
if command -v python > /dev/null 2>&1 ; then
    function pyserver() {
        python -m SimpleHTTPServer
    }

    # Pretty print json: echo '{"json":{"foo":"bar", "baz":"blah"}}'  | jsonpp
    if command -v jq > /dev/null 2>&1 ; then
        alias jsonpp="jq ."
    else
        alias jsonpp="python -m json.tool"
    fi
fi

