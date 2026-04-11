
if command -v python3 > /dev/null 2>&1 ; then
    _python=python3
elif command -v python > /dev/null 2>&1 ; then
    _python=python
fi

if [ -n "${_python:-}" ] ; then
    function pyserver() {
        $_python -m http.server "${1:-8000}"
    }

    # Pretty print json: echo '{"json":{"foo":"bar", "baz":"blah"}}'  | jsonpp
    if command -v jq > /dev/null 2>&1 ; then
        alias jsonpp="jq ."
    else
        alias jsonpp="$_python -m json.tool"
    fi

    unset _python
fi
