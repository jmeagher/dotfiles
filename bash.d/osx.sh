
if [ "`uname`" == "Darwin" ] ; then

    # Set java home to the OSX java
    if [ "$JAVA_HOME" = "" ] ; then
        if [ -d /System/Library/Frameworks/JavaVM.framework/Home ] ; then
            JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Home
            export JAVA_HOME
        fi
    fi
fi

# If Sublime is installed add it to bin for cli support
if [ -e /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl ] ; then
    if [ ! -e ~/bin/subl ] ; then
        ln -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl ~/bin/subl
    fi
fi


