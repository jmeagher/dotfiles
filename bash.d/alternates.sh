
# Sed with extended regex
if [ "`echo "test" | sed -r "s/t(es)t/\1/" 2>&1 > /dev/null`" = "es" ] ; then
    alias extsed="sed -r"
else
    # OSX mode
    alias extsed="sed -E"
fi
