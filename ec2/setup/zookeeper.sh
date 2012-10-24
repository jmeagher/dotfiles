#! /bin/bash
# Installs and sets up a zookeeper server using the CDH install

init_status Zookeeper-Install
yum -y install hadoop-zookeeper hadoop-zookeeper-server
init_status Zookeeper-Starting
/sbin/service hadoop-zookeeper-server start

