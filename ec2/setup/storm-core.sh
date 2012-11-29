#! /bin/bash
# Installs the base things needed for storm, but doesn't setup anything to run
# See the nimbus and supervisor files for the actual setup
# This requires the EC2 tag that identifies the zookeeper nodes or a zookeeper server list, same for nimbus
# Specify these with either (Note, for the EC2_TAG version to work the tagged host needs to already be up and running):
# ZK_EC2_TAG=Name=JPM-Zookeeper
# ZK_SERVER_LIST=server1,server2,server3
# DPRC_EC2_TAG=Name=JPM-Zookeeper
# DPRC_SERVER_LIST=server1,server2,server3
# NIMBUS_EC2_TAG=Name=JPM-Nimbus
# NIMBUS_SERVER=nimbus

STORM_VER=0.9.0-wip4
ZERO_MQ_VER=2.0.10
# Use the older version of ZeroMQ per storm recomendations on https://github.com/nathanmarz/storm/wiki/Setting-up-a-Storm-cluster

init_status Storm-Starting

STORM_URL=https://github.com/downloads/nathanmarz/storm/storm-$STORM_VER.zip
ZERO_MQ_URL=http://download.zeromq.org/zeromq-$ZERO_MQ_VER.tar.gz


# Install things required for packages in here
yum -y install libtool libuuid-devel gcc-c++ 


# Install ZeroMQ
TMP_DIR=/tmp/zmq
INSTALL_BASE=/opt
INSTALL_DIR=$INSTALL_BASE/zmq

init_status Storm-ZMQ-Download
mkdir -p $TMP_DIR
cd $TMP_DIR
wget $ZERO_MQ_URL

mkdir -p $INSTALL_BASE
cd $INSTALL_BASE
tar xzf $TMP_DIR/zeromq*.tar.gz

init_status Storm-ZMQ-Build
ln -s $INSTALL_BASE/zeromq-* $INSTALL_DIR
cd $INSTALL_DIR
./configure
make
make install


# Install jzmq
init_status Storm-jzmq-Download
TMP_DIR=/tmp/jzmq
mkdir -p $TMP_DIR
cd $TMP_DIR
git clone https://github.com/nathanmarz/jzmq.git
cd jzmq
init_status Storm-jzmq-Build
JAVA_HOME=/usr/lib/jvm/java ./autogen.sh
JAVA_HOME=/usr/lib/jvm/java ./configure
JAVA_HOME=/usr/lib/jvm/java make
JAVA_HOME=/usr/lib/jvm/java make install



# Install Storm
TMP_DIR=/tmp/storm
INSTALL_BASE=/opt
INSTALL_DIR=$INSTALL_BASE/storm

init_status Storm-Download
mkdir -p $TMP_DIR
cd $TMP_DIR
wget $STORM_URL

mkdir -p $INSTALL_BASE
cd $INSTALL_BASE
unzip $TMP_DIR/storm*.zip

init_status Storm-Setup
ln -s $INSTALL_BASE/storm-* $INSTALL_DIR

# Setup the storm config file

if [ "$ZK_SERVER_LIST" = "" ] ; then
    ZK_SERVER_LIST=`tag_to_host tag:$ZK_EC2_TAG`
fi

if [ "$DPRC_SERVER_LIST" = "" ] ; then
    DPRC_SERVER_LIST=`tag_to_host tag:$DPRC_EC2_TAG`
fi

if [ "$NIMBUS_SERVER" = "" ] ; then
    NIMBUS_SERVER=`tag_to_host tag:$NIMBUS_EC2_TAG`
fi

echo "Using ZK Servers: $ZK_SERVER_LIST"
echo "Using Nimbus Server: $NIMBUS_SERVER"
echo "Using DPRC Servers: $DPRC_SERVER_LIST"

config=/opt/storm/conf/storm.yaml
echo "storm.zookeeper.servers:" >> $config
for s in `echo $ZK_SERVER_LIST | sed "s/,/ /g"` ; do
    echo "    - \"$s\"" >> $config
done
echo "" >> $config
mkdir -p /var/storm
echo "storm.local.dir: /var/storm" >> $config
echo "" >> $config
echo "nimbus.host: \"$NIMBUS_SERVER\"" >> $config
echo "" >> $config

echo "drpc.servers:" >> $config
for s in `echo $DPRC_SERVER_LIST | sed "s/,/ /g"` ; do
    echo "    - \"$s\"" >> $config
done
echo "" >> $config

