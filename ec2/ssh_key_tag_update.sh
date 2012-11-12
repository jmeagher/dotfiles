export EC2_HOME=/opt/aws/apitools/ec2
export JAVA_HOME=/usr/lib/jvm/jre
export PATH=$PATH:/opt/aws/bin:$EC2_HOME/bin:$JAVA_HOME/bin

FINGERPRINT=`ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub | awk '{print $2}'`
OLD_FILE=~/.ssh_key_info
touch $OLD_FILE
OLD_FP=`cat $OLD_FILE`
if [ "$OLD_FP" != "$FINGERPRINT" ] ; then
    source ~/.bash_profile
    EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
    ec2addtag $EC2_INSTANCE_ID -tag ssh_FP=$FINGERPRINT >> ~/.ssh_log
    echo -n "$FINGERPRINT" > $OLD_FILE
fi


