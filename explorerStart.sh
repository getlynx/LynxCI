#!/bin/bash

# The first command starts nginx and the second makes sure it starts after a reboot.

systemctl start nginx && systemctl enable nginx

# The first command starts PHP-FPM and the second makes sure it starts after a reboot.

systemctl start php7.2-fpm && systemctl enable php7.2-fpm

# The following line is a search and replace for the string in the firewall script that enabled (or
# disables) access to the node via port 80. If the Block Explorer isn't running, we might as well
# close port 80 and remove that as a possible attack vector.

sed -i 's/80 -j DROP/80 -j ACCEPT/' /root/LynxCI/installers/firewall.sh

# If the crawler is running, it needs the disablewallet param of lynxd to be enabled. 

sed -i 's/disablewallet=1/disablewallet=0/' /root/.lynx/lynx.conf

# For the built in Block Crawler. Since it is not being used, let's purge the lynx.conf file copy
# if it still exists.

rm -rf /var/www/crawler.conf

# Time to recreate the lynx.conf file in a working dir that PHP can access. Be sure to NEVER edit
# this file as it is overwritten regularly. Only ever edit the /root/.lynx/lynx.conf version.

cp /root/.lynx/lynx.conf /var/www/crawler.conf

/root/LynxCI/installers/firewall.sh
