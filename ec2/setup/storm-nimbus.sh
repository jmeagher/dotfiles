#! /bin/bash
# Sets up the storm master node, run storm-core.sh before this
# This should really be something in /etc/init.d, but hey this is for development

nohup /opt/storm/bin/storm nimbus &

