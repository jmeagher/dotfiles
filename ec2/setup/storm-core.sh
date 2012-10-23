#! /bin/bash
# Installs the base things needed for storm, but doesn't setup anything to run
# See the nimbus, supervisor, and node files for the actual setup

STORM_VER=0.8.1
ZERO_MQ_VER=2.0.10
# Use the older version of ZeroMQ per storm recomendations on https://github.com/nathanmarz/storm/wiki/Setting-up-a-Storm-cluster

STORM_URL=https://github.com/downloads/nathanmarz/storm/storm-$STORM_VER.zip
ZERO_MQ_URL=http://download.zeromq.org/zeromq-$ZERO_MQ_VER.tar.gz


# Install things required for packages in here
yum -y install git libtool libuuid-devel gcc-c++ java-1.6.0-openjdk-devel


# Install ZeroMQ
TMP_DIR=/tmp/zmq
INSTALL_BASE=/opt
INSTALL_DIR=$INSTALL_BASE/zmq

mkdir -p $TMP_DIR
cd $TMP_DIR
wget $ZERO_MQ_URL

mkdir -p $INSTALL_BASE
cd $INSTALL_BASE
tar xzf $TMP_DIR/zeromq*.tar.gz

ln -s $INSTALL_BASE/zeromq-* $INSTALL_DIR
cd $INSTALL_DIR
./configure
make
make install


# Install jzmq
TMP_DIR=/tmp/jzmq
mkdir -p $TMP_DIR
cd $TMP_DIR
git clone https://github.com/nathanmarz/jzmq.git
cd jzmq
JAVA_HOME=/usr/lib/jvm/java ./autogen.sh
JAVA_HOME=/usr/lib/jvm/java ./configure
JAVA_HOME=/usr/lib/jvm/java make
JAVA_HOME=/usr/lib/jvm/java make install



# Install Storm
TMP_DIR=/tmp/storm
INSTALL_BASE=/opt
INSTALL_DIR=$INSTALL_BASE/storm

mkdir -p $TMP_DIR
cd $TMP_DIR
wget $STORM_URL

mkdir -p $INSTALL_BASE
cd $INSTALL_BASE
unzip $TMP_DIR/storm*.zip

ln -s $INSTALL_BASE/storm-* $INSTALL_DIR

