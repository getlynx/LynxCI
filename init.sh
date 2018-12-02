#!/bin/bash

# Let's wait 1 full minute for services to start and network card initializations to finish.

printf "\n\n\n\n\n\n\n\nLynxCI initialization will start in 60 seconds.\n\n\n\n\n\n"

sleep 60

# Ping Google NS server to test public network access

if /bin/ping -c 1 8.8.8.8 &> /dev/null
then

	# Remove the file if it already exists from a previous try.

	rm -rf /root/setup.sh

	# Grab the remote file. If it failes for any reason, reboot.

	if /usr/bin/wget -O /root/setup.sh https://getlynx.io/setup.sh; then

		# File exists and is a regular file. A regular file is neither a block or character special file nor a directory.

		if [ -f "/root/setup.sh" ]; then

			# File exists and has a size of more than 0 bytes.

			if [ -s "/root/setup.sh" ]; then

				/bin/chmod 700 /root/setup.sh

				/root/setup.sh

			else

				echo "Downloaded setup script was corrupted (-s). Rebooting and will try again."

				sleep 30

				reboot

			fi

		else

			echo "Downloaded setup script was corrupted (-f). Rebooting and will try again."

			sleep 30

			reboot

		fi

	else

		echo "Failed to download setup script. Rebooting and will try again."

		sleep 30

		reboot

	fi

else

	echo "No public network access detected. If using wifi, verify your /boot/wpa_supplicant.conf file is set up properly. Rebooting and will try again."

	sleep 60

	reboot

fi
