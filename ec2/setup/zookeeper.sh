#! /bin/bash
# Installs and sets up a zookeeper server using the CDH install

yum -y install hadoop-zookeeper hadoop-zookeeper-server
/sbin/service hadoop-zookeeper-server start

