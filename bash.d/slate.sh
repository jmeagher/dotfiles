# Custom stuff for helping out with the https://github.com/jigish/slate window layout tool

# Check if slate is even installed...


HAS_SLATE=false

for d in /Applications/Slate.app ~/Applications/Slate.app /opt/homebrew-cask/Caskroom/slate/latest/Slate.app ; do
    if [ -d $d ] ; then
        HAS_SLATE=true
    fi
done

if [ "$HAS_SLATE" = "true" ] ; then

    function slate_rebuild() {
        # This does something weird, slate supports functions in a single .slate.js file, but not from an imported file
        # This concatonates several files together so some utilities can be imported and used for the local config

        # ~/.slate_vars.js is to setup really basic things like which monitor is which
        # ~/.slate_local.js is to setup the system-specific layouts using the heoper functions from base-slate.js
        SLATE_PRE_FILES="$HOME/.slate_vars.js $HOME/.mydotfiles/osx/slate/base-slate.js $EXTRA_SLATE_PRE_FILES"
        SLATE_LOCAL_FILES="$HOME/.slate_local.js"
        SLATE_POST_FILES="$EXTRA_SLATE_POST_FILES"

        if [ -e $HOME/.slate.js ] ; then
            mv $HOME/.slate.js $HOME/.slate.js.bak
        fi
        for f in $SLATE_PRE_FILES $SLATE_LOCAL_FILES $SLATE_POST_FILES ; do
            if [ -e $f ] ; then
                cat $f >> $HOME/.slate.js
            fi
        done
    }

    if [[ ! -e $HOME/.slate.js || ! -z "$(find $HOME/.slate.js 2>&1 -ctime +2)" ]] ; then
        slate_rebuild
    fi

fi


