# Sets up all the required basics for the gmetad server
#
init_status Ganglia-gmetad-install
yum -y install ganglia-gmetad

# Probably should add some configuration options, but so far I don't need any

# This should not be needed, but ganglia won't start without it
chown nobody:nobody /var/lib/ganglia/rrds

service gmetad start

