#!/bin/bash

# The following line is a search and replace for the string in the firewall script that enabled (or
# disables) access to the node via port 80. If the Block Explorer isn't running, we might as well
# close port 80 and remove that as a possible attack vector.

sed -i 's/80 -j DROP/80 -j ACCEPT/' /root/LynxCI/installers/firewall.sh

# If the crawler is running, it needs the disablewallet param of lynxd to be enabled.

#sed -i 's/disablewallet=1/disablewallet=0/' /root/.lynx/lynx.conf

# Time to recreate the lynx.conf file in a working dir that PHP can access. Be sure to NEVER edit
# crawler.conf, as this file is overwritten regularly. Only edit the /root/.lynx/lynx.conf version.

cp --remove-destination /root/.lynx/lynx.conf /var/www/crawler.conf && chmod 644 /var/www/crawler.conf

# For security, let's remove the rest of the file, since the PHP app doesn't need to see it. We
# don't want the PHP app to potentially see any other sensitive info in the lynx.conf file.

sed -i '11,$ d' /var/www/crawler.conf

# The first command starts nginx and the second makes sure it starts after a reboot.

systemctl start nginx && systemctl enable nginx

# The first command starts PHP-FPM and the second makes sure it starts after a reboot.

systemctl start php7.2-fpm && systemctl enable php7.2-fpm

# Some system cleanup. If the bootstrap.dat file had been used in the past, it is not flagged as
# old. It is no longer needed so let's delete it if it still exists on the drive.

rm -rf /root/.lynx/bootstrap.dat.old

# Since we just changed some settings in the firewall script, let's reset the firewall.

/root/LynxCI/installers/firewall.sh