
init_status SSH_Key_Info
FINGERPRINT=`ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub | awk '{print $2}'`
ec2addtag $EC2_INSTANCE_ID -tag ssh_FP=$FINGERPRINT

