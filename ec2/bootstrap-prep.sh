#! /bin/sh
# Prepares the bootstrap template file for use as a user-data file when launching ec2 instances.
# Usage:
# bootstrap-prep.sh bootstrap.template.sh final-bootstrap.sh [-t tagname=tagvalue] [-i install_yum_package] [-e extra-file.sh] [-p envVarName=envVarValue]
# 

input=$1
output=$2

TAG_LIST=
YUM_LIST=
EXTRA_FILES=
ENV_VARS=

while [ "$3" != "" ] ; do
    if [ "$3" = "-t" ] ; then
        TAG_LIST="$TAG_LIST $4"
    elif [ "$3" = "-i" ] ; then
        YUM_LIST="$TAG_LIST $4"
    elif [ "$3" = "-e" ] ; then
        EXTRA_FILES="$EXTRA_FILES $4"
    elif [ "$3" = "-p" ] ; then
        ENV_VARS="$ENV_VARS $4"
    else 
        echo "Invalid option $3"
    fi
    shift; shift
done

echo "#! /bin/bash" > $output
echo "" >> $output

# Declare the environment variables
if [ "$ENV_VARS" != "" ] ; then
    echo "# Setup environment variables" >> $output
    for V in $ENV_VARS ; do
        echo "$V" >> $output
    done
    echo "" >> $output
    echo "# Start the real scripts" >> $output
fi

cat $input $EXTRA_FILES | \
    sed "s/__YUM_LIST__/$YUM_LIST/" | \
    sed "s/__TAG_LIST__/$TAG_LIST/" >> \
    $output

echo "" >> $output
echo "ec2addtag $EC2_INSTANCE_ID -tag init=extra_scripts" >> $output


