# Sets up all the required basics for ganglia and sets up the host to be monitored
#
# Args to pass in
# GMETA_TAG=Name=JPM-GMeta
# GMETA_SERVER=1.2.3.4
# GMOND_PORT=8649
# GANGLIA_CLUSTER=ClusterName


if [ "$GMETA_SERVER" = "" ] ; then
    GMETA_SERVER=`tag_to_host tag:$GMETA_TAG`
fi

if [ "$GMOND_PORT" = "" ] ; then
    GMOND_PORT=8649
fi

init_status Ganglia-gmond-install
yum -y install ganglia-gmond

CONF=/etc/ganglia/gmond.conf
if [ ! -e $CONF.orig ] ; then
    cp $CONF $CONF.orig
fi
 
cp $CONF $CONF.bak


# Things left out of below so pulling stats will work instead of pushing stats
#  awk '/mcast_join/ && n == 0 { sub(/^([^#]*mcast_join.*$)/,"  host = GMETA_SERVER"); ++n } { print }' | \
#  sed -r "s/GMETA_SERVER/${GMETA_SERVER}/" | \

cat $CONF.orig | \
  sed -r "s/#bind_hostname/bind_hostname/" | \
  awk '/name/ && n == 0 { sub(/^([^#a-z]*name.*$)/,"  name = CLUSTER_NAME"); ++n } { print }' | \
  sed -r "s/CLUSTER_NAME/\"${GANGLIA_CLUSTER}\"/" | \
  awk '/mcast_join/ && n == 0 { sub(/^([^#]*mcast_join.*$)/,"  host = GMETA_SERVER"); ++n } { print }' | \
  sed -r "s/GMETA_SERVER/${GMETA_SERVER}/" | \
  sed -r "s/^([^#]*mcast_join.*$)/#\\1/" | \
  sed -r "s/^([^#]*bind =.*)$/#\\1/" | \
  sed -r "s/8649/$GMOND_PORT/g" \
  > $CONF

# Do a delayed restart since for some reason it doesn't come up right if started right away
service gmond start
echo service gmond start | at "now + 1 min"
echo service gmond start | at "now + 3 min"
echo service gmond start | at "now + 5 min"
echo service gmond start | at "now + 9 min"

