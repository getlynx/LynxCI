#!/bin/bash

# Let's wait 1 full minute for services to start and network card initializations to finish.

printf "\n\n\n\n\n\n\n\nLynxCI initialization will start in 60 seconds.\n\n\n\n\n\n"

sleep 60

# Ping Google NS server to test public network access

if /bin/ping -c 1 8.8.8.8
then

	sleep 30

	wget -qO - https://getlynx.io/install.sh | bash

else

	echo "No public network access detected. If using wifi, verify your /boot/wpa_supplicant.conf file is set up properly. Rebooting and will try again."

	sleep 60

	reboot

fi