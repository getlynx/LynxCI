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
# Don't remove this final line.
##################################################################################################################
echo "update.service: Cleanup the current Update script." | systemd-cat -p info
rm -rf /usr/local/bin/config/update.*
##################################################################################################################