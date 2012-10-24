#! /bin/bash
# Sets up the storm ui, run storm-core.sh before this
# This should really be something in /etc/init.d, but hey this is for development

init_status Storm-UI
nohup /opt/storm/bin/storm ui &

