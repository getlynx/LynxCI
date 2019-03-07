#!/bin/bash

# We don't always know the condition of the host OS, so let's look for several possibilities. 
# This will disable the ability to log in directly as root. We don't ever want a user to login
# directly to the root account, even if they know the correct password.

sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Create the user account 'lynx' and skip the prompts for additional information.

adduser lynx --disabled-password --gecos ""

# Set the default password

echo "lynx:lynx" | chpasswd

# Force the user to change the password after the first login.

chage -d 0 lynx

# We don't always know the root password of the target device, be it a Pi, VPS or something 
# else. Let's add the user to the sudo group so they can gain access to thw root account. When
# the firewall resets automatically, the user will be removed from the sudo group, for security
# reasons.

adduser lynx sudo

echo "The user account 'lynx' was given sudo rights."

# If the target device is a Raspberry Pi, then let's assume the Pi account exists. Look for it
# and lock it if we find one. Otherwise skip this step if the Pi account is not found.

cat /etc/passwd | grep pi >/dev/null 2>&1

if [ $? -eq 0 ] ; then

	usermod -L -e 1 pi

	echo "For security purposes, the 'pi' account was locked and is no longer accessible."

fi
