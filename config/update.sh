#!/bin/bash
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
# Pull down the lastest node list and replace the current nodes with the new ones.
##################################################################################################################
file="https://raw.githubusercontent.com/getlynx/LynxCI/master/config/node.sh"
wget -O - $file > /tmp/node.sh
chmod 744 /tmp/node.sh
chown root:root /tmp/node.sh
/tmp/node.sh
rm -rf /tmp/node.sh
##################################################################################################################
# Don't remove this final line. If anything goes wrong, this will purge prior scripts for the next attempt.
##################################################################################################################
echo "update.service: Cleanup the current LynxCI update scripts." | systemd-cat -p info
rm -rf /usr/local/bin/config/update.*
##################################################################################################################