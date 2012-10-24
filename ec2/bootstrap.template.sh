#! /bin/sh
# Template for bootstrapping an AWS instance.
# See bootstrap-prep.sh for usage details

export EC2_HOME=/opt/aws/apitools/ec2
export JAVA_HOME=/usr/lib/jvm/jre
export PATH=$PATH:/opt/aws/bin:$EC2_HOME/bin:$JAVA_HOME/bin

export EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
echo "Instance ID: $EC2_INSTANCE_ID"


function init_status() {
    ec2addtag $EC2_INSTANCE_ID -tag init=$1
}

init_status started

for TAG in __TAG_LIST__ ; do
    ec2addtag $EC2_INSTANCE_ID -tag $TAG
done

if [ "" != "__YUM_LIST__" ] ; then
    yum -y install __YUM_LIST__
fi


# Define some useful utility functions
function tag_to_host() {
    FILTER=$1
    hl=`ec2-describe-instances -F $FILTER | grep INSTANCE | grep running | awk '{print $4}'`
    HOSTS=
    for h in $hl ; do
        if [ "$HOSTS" = "" ] ; then
            HOSTS=$h
        else
            HOSTS=$HOSTS,$h
        fi
    done
    echo $HOSTS

}

init_status extra_scripts
