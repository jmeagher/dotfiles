# For weird VPN issues
sudo launchctl stop com.apple.racoon
dscacheutil -flushcache
sudo killall -HUP mDNSResponder
sudo launchctl start com.apple.racoon
