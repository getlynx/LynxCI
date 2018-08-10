#!/bin/bash

# Primarily, this loop is intended for our Pi users. Testing has shown a few use cases where the
# excited user plugged in the ETH cable after booting the Pi and this caused a problem forcing the
# Pi user to re-flash the micro-sd card. We can do better, and this loop check should help. We are
# pining a Google NS server so the IP should be stable.

until ping -qc 1 8.8.8.8
	do echo \*\*\* Please Connect Network Cable \*\*\*; sleep 15
done

# Before we begin, we need to update the local repo's. Notice we aren't doing an upgrade. In some 
# cases this bring ups prompts that need a human to make a decision and after a good bit of testing,
# it was determined that trying to automate that portion was unneeded. For now, the update is all
# we need and the device will still function properly.

apt-get update -y &> /dev/null

# We need to ensure we have git for the following step. Let's not assume we already ahve it. Also
# added a few other tools as testing has revealed that some vendors didn't have them pre-installed.

apt-get install git curl htop nano -y &> /dev/null

# Some hosting vendors already have these installed. They aren't needed, so we are removing them 
# now. This list will probably get longer over time.

apt-get remove postfix apache2 -y &> /dev/null

# We are downloading the latest package of build instructions from github.

git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /root/LynxNodeBuilder/ &> /dev/null

# We can't assume the file permissions will be right, so let's reset them.

chmod 744 -R /root/LynxNodeBuilder/

# Let's execute the build script. If building a test environment, be sure to use the 'testnet'
# argument instead of 'mainnet'. The argument is required.

/root/LynxNodeBuilder/install.sh mainnet