#! /bin/bash
# Sets up the basic development tools that are needed for some of the from-source tools
# This probably pulls in more than what is needed, but is a good place to start

yum -y groupinstall "Development Tools" "Development Libraries"
yum -y install java-1.6.0-openjdk-devel git libtool

