#! /bin/sh
# Template for bootstrapping an AWS instance.
# See bootstrap-prep.sh for usage details

export EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
export AWS_ACCESS_KEY=__AWS_ACCESS_KEY__
export AWS_SECRET_KEY=__AWS_SECRET_KEY__

export EC2_HOME=/opt/aws/apitools/ec2
export JAVA_HOME=/usr/lib/jvm/jre
export PATH=$PATH:$EC2_HOME/bin:$JAVA_HOME/bin

for TAG in __TAG_LIST__ ; do
    ec2addtag $EC2_INSTANCE_ID -tag $TAG
done

if [ "" != "__YUM_LIST__" ] ; then
    yum -y install __YUM_LIST__
fi


