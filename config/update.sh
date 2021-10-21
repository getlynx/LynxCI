#!/bin/bash
##################################################################################################################
# wget -O - https://raw.githubusercontent.com/getlynx/LynxCI/master/config/update.sh | bash
[ $EUID -ne 0 ] && echo "This script must be run from the root account. Exiting." && exit
##################################################################################################################
# Update the systemd timer unit file
##################################################################################################################
file="https://raw.githubusercontent.com/getlynx/LynxCI/master/config/timer.sh"
local=$(md5sum /usr/local/bin/config/timer.sh | head -c 32)
remote=$(wget -O - $file | md5sum | head -c 32)

if [ "$local" != "$remote" ]; then 
	wget -O - $file > /usr/local/bin/config/timer.sh
	chmod 744 /usr/local/bin/config/timer.sh
	/usr/local/bin/config/timer.sh
fi
##################################################################################################################
# Update the message of the day content
##################################################################################################################
file="https://raw.githubusercontent.com/getlynx/LynxCI/master/config/motd.sh"
local=$(md5sum /etc/profile.d/motd.sh | head -c 32)
remote=$(wget -O - $file | md5sum | head -c 32)

if [ "$local" != "$remote" ]; then 
	wget -O - $file > /etc/profile.d/motd.sh
fi
##################################################################################################################
