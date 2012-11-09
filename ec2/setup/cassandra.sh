# This needs to be passed in to ID the proper cassandra nodes
# It should not have any spaces or punctuation other than _ in it, keep it simple
# CASSANDRA_CLUSTER_NAME=TestUniqueClusterName
# CASSANDRA_NODE_TAG=Name=JPM-Cassandra

init_status Cassandra_Setup

REPO=/etc/yum.repos.d/datastax.repo
echo "[datastax]" >> $REPO
echo "name= DataStax Repo for Apache Cassandra" >> $REPO
echo "baseurl=http://rpm.datastax.com/community" >> $REPO
echo "enabled=1" >> $REPO
echo "gpgcheck=0" >> $REPO

init_status Cassandra_Install
sleep 10s
yum -y install dsc1.1

# Customize config file
CONF=/etc/cassandra/conf/cassandra.yaml
if [ ! -e ${CONF}.orig ] ; then
    cp $CONF ${CONF}.orig
fi


# Determine settings for the config file
MY_IP=`ec2-metadata | grep local-ipv4 | grep -v user-data | awk '{print $2}'`
TEMP_HOST_LIST=`ec2-describe-instances -F tag:$CASSANDRA_NODE_TAG | grep running | awk '{print $15}' | sort`
NODE_IPS=`echo $TEMP_HOST_LIST | sed "s/ /,/g"`
#NODE_COUNT=`echo $TEMP_HOST_LIST | wc | awk '{print $2}'`

TOTAL_COUNT=${#TEMP_HOST_LIST}
MY_COUNT=`echo $TEMP_HOST_LIST | sed -r "s/$MY_IP.*$//" | wc | awk '{print $3}'`
# Might not be right, but close enough
MAX_TOKEN=170141183460469231731687303715884105728
INITIAL_TOKEN=`echo "$MAX_TOKEN / $TOTAL_COUNT * ( $MY_COUNT - 1 )" | bc`


cp $CONF ${CONF}.bak
cat ${CONF}.bak | \
    sed -r "s/^cluster_name:.*$/cluster_name: '$CASSANDRA_CLUSTER_NAME'/" | \
    sed -r "s/^initial_token:.*$/initial_token: $INITIAL_TOKEN/" | \
    sed -r "s/- seeds:.*/- seeds: \"$NODE_IPS\"/" | \
    sed -r "s/^listen_address:.*$/listen_address: $MY_IP/" | \
    sed -r "s/^rpc_address:.*$/rpc_address: 0.0.0.0/" | \
    sed -r "s/^endpoint_snitch:.*$/endpoint_snitch: RackInferringSnitch/" \
    > ${CONF}


# HORRIBLE HACK ALERT!
# See https://issues.apache.org/jira/browse/CASSANDRA-2441
# It looks like the fix doesn't work with the AWS version of OpenJDK
F=/etc/cassandra/conf/cassandra-env.sh
if [ ! -e ${F}.orig ] ; then
    cp $F ${F}.orig
    cat ${F}.orig | grep -v "javaagent" > ${F}
fi



init_status Cassandra_Starting

service cassandra start

