# This is a good template for launching a set of servers that need information about each other 
# for proper configuration.

# Get this from the EC2 console under "Security Groups", this is the group id
SECURITY_GROUP=sg-f58bc39d
# Get this from the EC2 console under "Key Pairs"
KEYPAIR=JohnMeagher
# Get this from the IAM dashboard, this is the Instance Profile ARN for the desired role for the server
IAM_PROFILE=arn:aws:iam::543259464462:instance-profile/TagManager

# How many nodes and types to launch of each type and a little other extra info

# See http://aws.amazon.com/amazon-linux-ami/ for AMI options
AMI=ami-e8249881
INSTANCE_TYPE=m1.large

#AMI=ami-1624987f
#INSTANCE_TYPE=t1.micro

CASSANDRA_NODES=3

 
# Prepare a user-data script for a storm master node with zookeeper, nimbus, and the storm ui
./bootstrap-prep.sh bootstrap.template.sh .cassandra.sh \
-t Name=JPM-Cassandra \
-t user=$USER \
-t type=Cassandra \
-p CASSANDRA_NODE_TAG=Name=JPM-Cassandra \
-p CASSANDRA_CLUSTER_NAME=JPM-Cassandra \
-e setup/yum_update.sh \
-e setup/ssh_key_info.sh \
-e setup/devtools.sh \
-e setup/cassandra.sh


ec2-run-instances $AMI -n $CASSANDRA_NODES -g $SECURITY_GROUP -f .cassandra.sh --instance-type $INSTANCE_TYPE \
  -k $KEYPAIR -p $IAM_PROFILE
