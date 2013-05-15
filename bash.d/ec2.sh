
# Setup EC2 according to http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/SettingUp_CommandLine.html
if [ "" != "$EC2_HOME" ] ; then
    export PATH=$PATH:$EC2_HOME/bin

    # Check ~/.ec2/credentials.csv for AWS setup info
    if [ -f ~/.ec2/credentials.csv ] ; then
        export AWS_ACCESS_KEY=`cat ~/.ec2/credentials.csv | grep -v "User Name" | awk -F, '{print $2}' | sed 's/"//g'`
        export AWS_SECRET_KEY=`cat ~/.ec2/credentials.csv | grep -v "User Name" | awk -F, '{print $3}' | sed 's/"//g'`
    fi
fi


