# This is a good template for launching a set of servers that need information about each other 
# for proper configuration.

# Get this from the EC2 console under "Security Groups", this is the group id
# US East
#SECURITY_GROUP=sg-f58bc39d
# US West
SECURITY_GROUP=sg-0c0e693c

# Get this from the EC2 console under "Key Pairs"
KEYPAIR=JohnMeagher
# Get this from the IAM dashboard, this is the Instance Profile ARN for the desired role for the server
# This is not region specific
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

KAFKA_NODES=1
STORM_NODES=1
SUPERVISOR_PORT_COUNT=4

KAFKA_PARTITIONS_PER_HOST=10
 
# Prepare a user-data script for a storm master node with zookeeper, nimbus, and the storm ui
./bootstrap-prep.sh bootstrap.template.sh .storm-master.sh \
-t Name=JPM-Storm-Master \
-t user=$USER \
-t type=StormMaster \
-p REGION=$REGION \
-p NIMBUS_EC2_TAG=Name=JPM-Storm-Master \
-p ZK_EC2_TAG=Name=JPM-Storm-Master \
-p DPRC_EC2_TAG=Name=JPM-Storm-Master \
-e setup/yum_update.sh \
-e setup/ssh_key_info.sh \
-e setup/cdh3_repo_setup.sh \
-e setup/devtools.sh \
-e setup/zookeeper.sh \
-e setup/storm-core.sh \
-e setup/storm-nimbus.sh \
-e setup/storm-ui.sh 
 
 # Prepare a user-data script for a storm worker node with the storm supervisor
./bootstrap-prep.sh bootstrap.template.sh .storm-node.sh \
-t Name=JPM-Storm-Node \
-t user=$USER \
-t type=StormNode \
-p REGION=$REGION \
-p NIMBUS_EC2_TAG=Name=JPM-Storm-Master \
-p ZK_EC2_TAG=Name=JPM-Storm-Master \
-p DPRC_EC2_TAG=Name=JPM-Storm-Master \
-p SUPERVISOR_PORT_COUNT=$SUPERVISOR_PORT_COUNT \
-e setup/yum_update.sh \
-e setup/ssh_key_info.sh \
-e setup/devtools.sh \
-e setup/storm-core.sh \
-e setup/storm-supervisor.sh 
 
# Prepare a user-data script for a kafka message broker
./bootstrap-prep.sh bootstrap.template.sh .kafka-server.sh \
-t Name=JPM-Kafka-Server \
-t user=$USER \
-t type=KafkaServer \
-p REGION=$REGION \
-p ZK_EC2_TAG=Name=JPM-Storm-Master \
-p NUM_PARTITIONS=$KAFKA_PARTITIONS_PER_HOST \
-e setup/yum_update.sh \
-e setup/ssh_key_info.sh \
-e setup/devtools.sh \
-e setup/kafka.sh
 
 
# Here's what's going on in the commands below...
# ec2-run-instances ami-1624987f - This launches an instance using the default Amazon AMI
# -n 1 - This launches a single instance
# -g sg-f58bc39d - This specifies the Lotame "Internal Node" security group, this is the GroupId in the Security Groups section of the console
# -f storm-master.sh - This passes the file created above to the instance for initialization
# --instance-type m1.small - This defines the instance type used to launch things
# -k JohnMeagher - This defines the keypair that will have ssh access after creation
# -p arn:aws:iam::543259464462:instance-profile/TagManager - This specifies the Lotame "Tag Manager" 
#                             role so the instance can set its own tags.
#                             This is the Instance Profile ARN on the Roles tab in the IAM manager console
  
# Launch the storm master node
ec2-run-instances $AMI --region $REGION -n 1 -g $SECURITY_GROUP -f .storm-master.sh --instance-type $INSTANCE_TYPE \
  -k $KEYPAIR -p $IAM_PROFILE
 
# Wait a little for that instance to start, check that it's running manually by verifying the tags are added to the instance
sleep 120s
 
# Launch Storm worker nodes
ec2-run-instances $AMI --region $REGION -n $STORM_NODES -g $SECURITY_GROUP -f .storm-node.sh --instance-type $INSTANCE_TYPE \
  -k $KEYPAIR -p $IAM_PROFILE

# Launch Kafka message brokers
ec2-run-instances $AMI --region $REGION -n $KAFKA_NODES -g $SECURITY_GROUP -f .kafka-server.sh --instance-type $INSTANCE_TYPE \
  -k $KEYPAIR -p $IAM_PROFILE
