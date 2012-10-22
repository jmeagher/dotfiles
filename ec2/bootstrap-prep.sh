#! /bin/sh
# Prepares the bootstrap template file for use as a user-data file when launching ec2 instances.
# Usage:
# bootstrap-prep.sh bootstrap.template.sh final-bootstrap.sh [-t tagname=tagvalue] [-i install_yum_package] [-e extra-file.sh]
# 

input=$1
output=$2

TAG_LIST=
YUM_LIST=
EXTRA_FILES=

while [ "$3" != "" ] ; do
    if [ "$3" = "-t" ] ; then
        TAG_LIST="$TAG_LIST $4"
    elif [ "$3" = "-i" ] ; then
        YUM_LIST="$TAG_LIST $4"
    elif [ "$3" = "-e" ] ; then
        EXTRA_FILES="$EXTRA_FILES $4"
    else 
        echo "Invalid option $3"
    fi
    shift; shift
done

cat $input $EXTRA_FILES | \
    sed "s/__AWS_ACCESS_KEY__/$AWS_ACCESS_KEY/" | \
    sed "s/__AWS_SECRET_KEY__/$AWS_SECRET_KEY/" | \
    sed "s/__YUM_LIST__/$YUM_LIST/" | \
    sed "s/__TAG_LIST__/$TAG_LIST/" > \
    $output

