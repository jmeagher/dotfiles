function tag_to_host() {
    FILTER=$1
    hl=`ec2-describe-instances --region $REGION -F $FILTER | grep INSTANCE | grep running | awk '{print $4}'`
    HOSTS=
    for h in $hl ; do
        if [ "$HOSTS" = "" ] ; then
            HOSTS=$h
        else
            HOSTS=$HOSTS,$h
        fi
    done
    echo $HOSTS

}

REGION=us-west-2

TAG_LIST="Name=JPM-Storm-Master Name=JPM-Storm-Node Name=JPM-Kafka-Server Name=JPM-Cassandra"
PORT=8649
CONF=/etc/ganglia/gmetad.conf

if [ ! -e $CONF.orig ] ; then
    cp $CONF $CONF.orig
fi
 
rm -f $CONF.bak
cp $CONF $CONF.bak
rm -f $CONF
cp $CONF.orig $CONF

for tag in $TAG_LIST ; do
    line="data_source \"$tag\""
    for host in `tag_to_host tag:$tag | sed "s/,/ /g"` ; do
        line="$line $host:$PORT"
    done
    echo $line >> $CONF
done

service gmetad restart


