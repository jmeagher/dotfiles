#! /bin/bash
# Sets up the storm ui, run storm-core.sh before this
# This should really be something in /etc/init.d, but hey this is for development

nohup /opt/storm/bin/storm ui &

