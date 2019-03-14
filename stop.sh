#!/bin/bash

# The first command stops nginx and the second makes sure it doesn't start after a reboot.

systemctl stop nginx && systemctl disable nginx

# The first command stops PHP-FPM and the second makes sure it doesn't start after a reboot.

systemctl stop php7.2-fpm && systemctl disable php7.2-fpm

# The following line is a search and replace for the string in the firewall script that enabled (or
# disables) access to the node via port 80. If the Block Explorer isn't running, we might as well
# close port 80 and remove that as a possible attack vector.

sed -i 's/80 -j ACCEPT/80 -j DROP/' /root/LynxCI/installers/firewall.sh

# If the crawler is not running, it needs the disablewallet param of lynxd to be disabled.

#sed -i 's/disablewallet=0/disablewallet=1/' /root/.lynx/lynx.conf

# Since we just changed some settings in the firewall script, let's reset the firewall.

/root/LynxCI/installers/firewall.sh