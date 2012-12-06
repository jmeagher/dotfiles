# Sets up all the required basics for the ganglia web server
# this should be run on the gmetad server


init_status Ganglia-Web-Install
yum -y install rrdtool php-mysql php-gd php httpd ganglia-web


CONF=/etc/httpd/conf.d/ganglia.conf
if [ ! -e $CONF.orig ] ; then
    cp $CONF $CONF.orig
fi
 
cp $CONF $CONF.bak

cat $CONF.orig | \
    sed -r "s/^(.*Deny from all)/#\\1\\n    Allow from all/" \
    > $CONF

service httpd start


