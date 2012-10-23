wget http://archive.cloudera.com/redhat/6/x86_64/cdh/cdh3-repository-1.0-1.noarch.rpm
yum -y --nogpgcheck localinstall ./cdh3-repository-1.0-1.noarch.rpm
rpm --import http://archive.cloudera.com/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera

