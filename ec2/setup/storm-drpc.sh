#! /bin/bash
# Sets up the storm master node, run storm-core.sh before this
# This should really be something in /etc/init.d, but hey this is for development

init_status Storm-Drpc
nohup /opt/storm/bin/storm drpc &

