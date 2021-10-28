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
local=$(md5sum /home/lynx/.lynx/.node.sh | head -c 32)
remote=$(wget -O - $file | md5sum | head -c 32)
if [ "$local" != "$remote" ]; then 
	config="/home/lynx/.lynx/lynx.conf"
	sed -i '/81a3e59444e4/d' $config
	sed -i '/addnode=/d' $config
	wget -O - $file > /home/lynx/.lynx/.node.sh
	cat /home/lynx/.lynx/.node.sh >> $config
	chmod 770 "$config"
	chown lynx:lynx "$config"
	cp --remove-destination "$config" /home/lynx/.lynx/sample-lynx.conf && chmod 600 /home/lynx/.lynx/sample-lynx.conf
	sed -i /^$/d $config
fi
##################################################################################################################
# Don't remove this final line. If anything goes wrong, this will purge prior scripts for the next attempt.
##################################################################################################################
echo "update.service: Cleanup the current LynxCI update scripts." | systemd-cat -p info
rm -rf /usr/local/bin/config/update.*
##################################################################################################################