#! /bin/bash
# Sets up the storm worker node, run storm-core.sh before this
# This has an optional configuration option to specifiy the supervisor ports
# This is what drives the number of workers running on the host
# SUPERVISOR_PORTS=6700,6701,6702,6703
# or for the lazy:
# SUPERVISOR_PORT_COUNT=4

if [ "$SUPERVISOR_PORTS" = "" ] ; then
    if [ "$SUPERVISOR_PORT_COUNT" != "" ] ; then
        BASE_PORT=6700
        for i in `seq $SUPERVISOR_PORT_COUNT` ; do
            NEW_PORT=$(($BASE_PORT-1+$i))
            if [ "$SUPERVISOR_PORTS" = "" ] ; then
                SUPERVISOR_PORTS=$NEW_PORT
            else
                SUPERVISOR_PORTS=$SUPERVISOR_PORTS,$NEW_PORT
            fi 
        done
    fi
fi

if [ "$SUPERVISOR_PORTS" != "" ] ; then
    echo "Setting up supervisor with ports $SUPERVISOR_PORTS"
    config=/opt/storm/conf/storm.yaml
    echo "supervisor.slots.ports:" >> $config
    for p in `echo $SUPERVISOR_PORTS | sed "s/,/ /g"` ; do
        echo "    - $p" >> $config
    done
    echo "" >> $config
fi

# This should really be something in /etc/init.d, but hey this is for development
init_status Storm-Supervisor
nohup /opt/storm/bin/storm supervisor &

