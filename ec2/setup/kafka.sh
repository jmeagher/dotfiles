#! /bin/bash

# This requires the EC2 tag that identifies the zookeeper nodes or a zookeeper server list
# Specify these with either (Note, for the EC2_TAG version to work the tagged host needs to already be up and running):
# ZK_EC2_TAG=Name=JPM-Zookeeper
# ZK_SERVER_LIST=server1,server2,server3

KAFKA_VER=0.7.2
KAFKA_URL=http://mirror.cc.columbia.edu/pub/software/apache/incubator/kafka/kafka-$KAFKA_VER-incubating/kafka-$KAFKA_VER-incubating-src.tgz

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
./sbt update
./sbt package


if [ "$ZK_SERVER_LIST" = "" ] ; then
    ZK_SERVER_LIST=`tag_to_host tag:$ZK_EC2_TAG`
fi

# This is a hack, but should work in enough cases to be fine for development
BROKERID=`ifconfig | grep "inet addr" | grep -v "127.0.0.1" | sed -r "s/^.*inet addr:[0-9]+\\.[0-9]+\\.[0-9]+\\.([0-9]+)[^0-9]+.*$/\\1/"`

# First clean default values, then enter our values
PROP_FILE=config/kafka.properties
cat config/server.properties | \
    sed -r "s/^(zk.connect=)/#\\1/" | \
    sed -r "s/^(brokerid=)/#\\1/" > $PROP_FILE
echo "" >> $PROP_FILE
echo "# Property overrides" >> $PROP_FILE
echo "zk.connect=$ZK_SERVER_LIST" >> $PROP_FILE
echo "brokerid=$BROKERID" >> $PROP_FILE

