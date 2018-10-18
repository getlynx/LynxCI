#!/bin/bash

# In order to ensure the PM2 commands work right, jump into the app directory.

cd /root/LynxBlockExplorer/

# If it's already running, stop it. Just to make sure.

pm2 stop LynxBlockExplorer

pm2 delete LynxBlockExplorer

pm2 start

pm2 save

pm2 startup ubuntu

version_id=`cat /etc/os-release | egrep '^VERSION_ID=' | cut -d= -f2 -d'"'`

checkForRaspbian=$(cat /proc/cpuinfo | grep 'Revision')

if [ "$version_id" = "9" ]; then

	if [ -z "$checkForRaspbian" ]; then

		systemctl start mongod

	else

		service mongodb start

	fi

elif [ "$version_id" = "8" ]; then

	systemctl start mongod

elif [ "$version_id" = "16.04" ]; then

	systemctl daemon-reload && systemctl start mongod

elif [ "$version_id" = "18.04" ]; then

	systemctl start mongod

fi

# The following line is a search and replace for the string in the firewall script that enabled (or
# disables) access to the node via port 80. If the Block Explorer isn't running, we might as well
# close port 80 and remove that as a possible attack vector.

sed -i 's/80 -j DROP/80 -j ACCEPT/' /root/firewall.sh

# In the event that any other crontabs exist, let's purge them all.

crontab -r

crontab -l | { cat; echo "0 */3 * * *		/root/LynxCI/explorerStart.sh"; } | crontab -

# Every 15 minutes we reset the firewall to it's default state.
# The lynx daemon needs to be checked too, so we restart it if it crashes (which has been been
# known to happen on low RAM devices during blockchain indexing.)

crontab -l | { cat; echo "0 */18 * * *		/root/firewall.sh"; } | crontab -

crontab -l | { cat; echo "*/5 * * * *		/root/lynx/src/lynxd"; } | crontab -

# The update script totally reinstalls the Block Explorer code. It's pretty intensive for the
# host device. So instead of running it daily like we used to, we only run it once a month. This
# day of the month is randomly selected on build.

crontab -l | { cat; echo "0 0 $(shuf -i 1-15 -n 1) * *		/root/LynxCI/update.sh"; } | crontab -

# We found that after a few weeks, the debug log would grow rather large. It's not really needed
# after a certain size, so let's truncate that log down to a reasonable size every day.

crontab -l | { cat; echo "*/30 * * * *		truncate -s 1KB /root/.lynx/debug.log"; } | crontab -

# Evey 15 days we will reboot the device. This is for a few reasons. Since the device is often
# not actively managed by it's owner, we can't assume it is always running perfectly so an
# occasional reboot won't cause harm. This crontab means to reboot EVERY 15 days, NOT on the
# 15th day of the month. An important distinction.

crontab -l | { cat; echo "0 0 $(shuf -i 16-28 -n 1) * *		/sbin/shutdown -r now"; } | crontab -

crontab -l | { cat; echo "*/3 * * * *		cd /root/LynxBlockExplorer && /usr/bin/nodejs scripts/sync.js index update >> /tmp/explorer.sync 2>&1"; } | crontab -

crontab -l | { cat; echo "*/10 * * * *		cd /root/LynxBlockExplorer && /usr/bin/nodejs scripts/peers.js > /dev/null 2>&1"; } | crontab -
