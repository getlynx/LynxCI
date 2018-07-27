#!/bin/bash

# Primarily, this loop is intended for our Pi users. Testing has show a few use cases where the 
# excited user plugged in the ETH cable after booting the Pi and this caused a problem forcing the
# Pi user to re-flash the micro-sd card. We can do better, and this loop check should help.

until ping -qc 1 https://getlynx.io
	do echo \*\*\* Please Connect Network Cable \*\*\*; sleep 15
done

# Before we begin, we need to update the local repo's

apt-get update -y &> /dev/null

# This command is a reasonable step after an update but on Ubuntu, manual control might be needed
# so please consider leaveing this command out if you are building a Stackscript or automated 
# build script. 

apt-get upgrade -y &> /dev/null

# We need to ensure we have git for the following step. Let's not assume we already ahve it.

apt-get install git -y &> /dev/null

# We are downloading the latest package of build instructions from github.

git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /root/LynxNodeBuilder/

# We can't assume the file permissions will be right, so let's reset them.

chmod 744 -R /root/LynxNodeBuilder/

# Let's execute the build script. If building a test environment, be sure to use the 'testnet'
# argument instead of 'mainnet'. The argument is required.

/root/LynxNodeBuilder/install.sh mainnet