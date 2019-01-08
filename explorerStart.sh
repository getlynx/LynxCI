#!/bin/bash

systemctl start nginx && systemctl enable nginx

systemctl start php7.2-fpm && systemctl enable php7.2-fpm

# The following line is a search and replace for the string in the firewall script that enabled (or
# disables) access to the node via port 80. If the Block Explorer isn't running, we might as well
# close port 80 and remove that as a possible attack vector.

sed -i 's/80 -j DROP/80 -j ACCEPT/' /root/firewall.sh

# If the crawler is running, it needs the disablewallet param of lynxd to be enabled. 

sed -i 's/disablewallet=1/disablewallet=0/' /root/.lynx/lynx.conf

/root/firewall.sh # Clear and reset the firewall state to the default state with recent changes.

crontab -r # In the event that any other crontabs exist, let's purge them all.

crontab -l | { cat; echo "0 */3 * * *		/root/LynxCI/explorerStart.sh"; } | crontab -

crontab -l | { cat; echo "*/5 * * * *		MALLOC_ARENA_MAX=1 /root/lynx/src/lynxd"; } | crontab -

# The update script totally reinstalls the Block Explorer code. It's pretty intensive for the
# host device. So instead of running it daily like we used to, we only run it once a month. This
# day of the month is randomly selected on build.

#crontab -l | { cat; echo "0 0 $(shuf -i 1-15 -n 1) * *		/root/LynxCI/update.sh"; } | crontab -

# We found that after a few weeks, the debug log would grow rather large. It's not really needed
# after a certain size, so let's truncate that log down to a reasonable size every day.

crontab -l | { cat; echo "*/30 * * * *		truncate -s 10KB /root/.lynx/debug.log"; } | crontab -

# Evey 15 days we will reboot the device. This is for a few reasons. Since the device is often
# not actively managed by it's owner, we can't assume it is always running perfectly so an
# occasional reboot won't cause harm. This crontab means to reboot EVERY 15 days, NOT on the
# 15th day of the month. An important distinction.

#crontab -l | { cat; echo "0 0 $(shuf -i 16-28 -n 1) * *		/sbin/shutdown -r now"; } | crontab -
