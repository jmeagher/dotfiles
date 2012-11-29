# This is a good template for launching a set of servers that need information about each other 
# for proper configuration.

# Get this from the EC2 console under "Security Groups", this is the group id
#SECURITY_GROUP=sg-f58bc39d
# US West
SECURITY_GROUP=sg-0c0e693c

# Get this from the EC2 console under "Key Pairs"
KEYPAIR=JohnMeagher
# Get this from the IAM dashboard, this is the Instance Profile ARN for the desired role for the server
IAM_PROFILE=arn:aws:iam::543259464462:instance-profile/TagManager

# How many nodes and types to launch of each type and a little other extra info

# See http://aws.amazon.com/amazon-linux-ami/ for AMI options
# US East
#AMI=ami-e8249881
# US West
#AMI=ami-2e31bf1e
#INSTANCE_TYPE=m1.large

# US East
#AMI=ami-1624987f
# US West
AMI=ami-2a31bf1a
INSTANCE_TYPE=t1.micro

#REGION=us-east
REGION=us-west-2

CASSANDRA_NODES=1

 
# Prepare a user-data script for a storm master node with zookeeper, nimbus, and the storm ui
./bootstrap-prep.sh bootstrap.template.sh .cassandra.sh \
-t Name=JPM-Cassandra \
-t user=$USER \
-t type=Cassandra \
-p REGION=$REGION \
-p CASSANDRA_NODE_TAG=Name=JPM-Cassandra \
-p CASSANDRA_CLUSTER_NAME=JPM-Cassandra \
-e setup/yum_update.sh \
-e setup/ssh_key_info.sh \
-e setup/devtools.sh \
-e setup/cassandra.sh


ec2-run-instances $AMI --region $REGION -n $CASSANDRA_NODES -g $SECURITY_GROUP -f .cassandra.sh --instance-type $INSTANCE_TYPE \
  -k $KEYPAIR -p $IAM_PROFILE
