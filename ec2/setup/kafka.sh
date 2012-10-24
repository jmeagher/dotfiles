#! /bin/bash

# This requires the EC2 tag that identifies the zookeeper nodes or a zookeeper server list
# Specify these with either (Note, for the EC2_TAG version to work the tagged host needs to already be up and running):
# ZK_EC2_TAG=Name=JPM-Zookeeper
# ZK_SERVER_LIST=server1,server2,server3

KAFKA_VER=0.7.2
KAFKA_URL=http://mirror.cc.columbia.edu/pub/software/apache/incubator/kafka/kafka-$KAFKA_VER-incubating/kafka-$KAFKA_VER-incubating-src.tgz

init_status Kafka-Starting

# Install Kafka
TMP_DIR=/tmp/kafka
INSTALL_BASE=/opt
INSTALL_DIR=$INSTALL_BASE/kafka

mkdir -p $TMP_DIR
cd $TMP_DIR
wget $KAFKA_URL

mkdir -p $INSTALL_BASE
cd $INSTALL_BASE
tar xzf $TMP_DIR/kafka-*.tgz
ln -s $INSTALL_BASE/kafka-* $INSTALL_DIR

cd $INSTALL_DIR
# Build from source
init_status Kafka-Update
./sbt update
init_status Kafka-Package
./sbt package


if [ "$ZK_SERVER_LIST" = "" ] ; then
    ZK_SERVER_LIST=`tag_to_host tag:$ZK_EC2_TAG`
fi

# This is a hack, but should work in enough cases to be fine for development
BROKERID=`ifconfig | grep "inet addr" | grep -v "127.0.0.1" | sed -r "s/^.*inet addr:[0-9]+\\.[0-9]+\\.[0-9]+\\.([0-9]+)[^0-9]+.*$/\\1/"`

# First clean default values, then enter our values
PROP_FILE=$INSTALL_DIR/config/kafka.properties
cat config/server.properties | \
    sed -r "s/^(zk.connect=)/#\\1/" | \
    sed -r "s/^(brokerid=)/#\\1/" > $PROP_FILE
echo "" >> $PROP_FILE
echo "# Property overrides" >> $PROP_FILE
echo "zk.connect=$ZK_SERVER_LIST" >> $PROP_FILE
echo "brokerid=$BROKERID" >> $PROP_FILE

# Setup a simple init script for the server
INIT=/etc/init.d/kafka
echo "#! /bin/sh" > $INIT
echo "case \"\$1\" in" >> $INIT
echo "start)" >> $INIT
echo " nohup $INSTALL_DIR/bin/kafka-server-start.sh $PROP_FILE &" >> $INIT
echo ";;" >> $INIT
echo "stop)" >> $INIT
# Note: This sucks, but mimics the kafka stop script and works
echo " ps ax | grep -i 'kafka.Kafka' | grep -v grep | awk '{print \$1}' | xargs -l1 kill -9 " >> $INIT
echo ";;" >> $INIT
echo "status)" >> $INIT
echo " ps ax | grep java | grep kafka | grep -v grep >& /dev/null && echo 'Kafka is running' || echo 'Kafka is shutdown'" >> $INIT
echo ";;" >> $INIT
echo "*)" >> $INIT
echo " echo Usage \$0 start,stop,status" >> $INIT
echo "esac" >> $INIT
chmod +x $INIT

init_status Kafka-Starting
ln -s $INIT /etc/rc3.d/S99kafka
/sbin/service kafka start


