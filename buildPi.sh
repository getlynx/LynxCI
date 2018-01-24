#!/bin/bash

#
#
# This script will build a fully functioning Lynx node with micro-miner for a Raspberry Pi 3. It is 
# based on Raspian Lite. This script will build a fully functional node on a Pi. Any ISO images
# that are distributed are created from the result of this build. For the most secure and up-to-date
# build, use this script. For a quick build that syncs quickly and starts mining quickly, use the 
# ISO. Not a bad idea to get the latest ISO for your Pi every 90 days, so you have the latest 
# updatesa and bug patches.
#
# You must start by flashing a 8GB or larger micro SD card with the latest version of Raspian Lite.
# You can acquire it here: https://www.raspberrypi.org/downloads/raspbian/
# Once the SD card is working and you Pi is turned on, gain access to the root account. Then execute 
# the following command as root. This script must be run as root, not at the Pi user. It will fail
# if you run it as the Pi user.
#
# $ apt-get update -y
# $ apt-get install curl -y
# $ curl 'https://raw.githubusercontent.com/doh9Xiet7weesh9va9th/LynxNodeBuilder/master/buildPi.sh' > /tmp/buildPi.sh && bash /tmp/buildPi.sh && rm /tmp/buildPi.sh
#
# The above script will pull the lastest version of this script, execute it, and then delete it. 
# Once complete, you will have a functioning Lynx node with micro-miner running on your Raspberry
# Pi 3. Please allow 15 hour for this script to run. Interrupting the power supply during the first 
# 15 hours might require you to start over.

#
#
# After first boot, update the OS.

apt-get update -y
apt-get upgrade -y

#
#
# Let's install more packages we will later need.

apt-get install htop git-core build-essential autoconf libtool libssl-dev libboost-all-dev libminiupnpc-dev libevent-dev libncurses5-dev pkg-config -y

#
#
# Let's modify the device to allow remote SSH access in the future.

cd /boot && touch ssh

#
#
# Let's pull down the latest Lynx repo from Github. This will always get the letest build so
# updates via git aren't really needed. To update to the latest version, just build a new server.

git clone https://github.com/doh9Xiet7weesh9va9th/lynx.git /root/lynx/

#
#
# Jump to the working directory to start our Lynx compile for this machine.

cd /root/lynx/

#
#
# A little prep.

./autogen.sh

#
#
# A little more prep. Notice we are configuring the make to build without the wallet functions 
# enabled. This Lynx node won't have an active wallet, but if you wanted it to, you could remove
# that flag and have fun with wallet functions.

./configure --enable-upnp-default --disable-wallet

#
#
# Finally, lets start the compile. It take about 45 minutes to complete on a single CPU 1024
# Linode. Probably a bit faster on a Rasperry Pi 3. If you add the 'j' flag and specify the number
# of processors you have, you can shorten this time significantly.

make



