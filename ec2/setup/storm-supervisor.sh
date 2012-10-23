#! /bin/bash
# Sets up the storm worker node, run storm-core.sh before this
# This has an optional configuration option to specifiy the supervisor ports
# This is what drives the number of workers running on the host
# SUPERVISOR_PORTS=6700,6701,6702,6703

if [ "$SUPERVISOR_PORTS" != "" ] ; then
    config=/opt/storm/conf/storm.yaml
    echo "supervisor.slots.ports:" >> $config
    for p in `echo $SUPERVISOR_PORTS | sed "s/,/ /g"` ; do
        echo "    - $p" >> $config
    done
    echo "" >> $config
fi

nohup /opt/storm/bin/storm supervisor

