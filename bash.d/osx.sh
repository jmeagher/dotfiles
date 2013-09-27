
if [ "`uname`" == "Darwin" ] ; then

    # Set java home to the OSX java
    if [ "$JAVA_HOME" = "" ] ; then
        if [ -d /System/Library/Frameworks/JavaVM.framework/Home ] ; then
            JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Home
            export JAVA_HOME
        fi
    fi

    # Example of moving windows
    # osascript -e 'tell application "System Events" to set position of first window of application process "iTerm" to {20, 20} '
    
fi

# If Sublime is installed add it to bin for cli support
if [ -e /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl ] ; then
    if [ ! -e ~/bin/subl ] ; then
        ln -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl ~/bin/subl
    fi
fi


