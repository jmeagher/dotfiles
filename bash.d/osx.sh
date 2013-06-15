
if [ "`uname`" == "Darwin" ] ; then

    # Set java home to the OSX java
    if [ "$JAVA_HOME" = "" ] ; then
        if [ -d /System/Library/Frameworks/JavaVM.framework/Home ] ; then
            JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Home
            export JAVA_HOME
        fi
    fi
fi
