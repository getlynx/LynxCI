#!/bin/bash

# This script will setup the host OS and install all dependencies. Some hosting vendors might
# require a manual reboot (i.e. HostBRZ) after the whole thing is complete. 

# "$ wget https://raw.githubusercontent.com/doh9Xiet7weesh9va9th/LynxNodeBuilder/master/loader.sh && chmod 744 load* && ./loader.sh"
# or
# "$ wget https://raw.githubusercontent.com/doh9Xiet7weesh9va9th/LynxNodeBuilder/master/loaderTest.sh && chmod 744 load* && ./loaderTest.sh"

# Alternatively, To execute a manual install, create a file in the /root dir as the root user on the new VPS. Create a file called 'loader.sh'
# or 'loaderTest.sh', depending on the environment you want ot build, mainet or testet respectively.
# After creatig the file, give it executable rights with "chmod 744 loader*". Once that is done, you
# can begin the install by executing the file ("./loader.sh" or "./loaderTest.sh"). This istallation
# will allow you to close the session widow i your termial or putty window. The script will run in
# the background without need for human interaction. Depending on the speed of your VPS or Pi2 or 
# Pi3, the process will be complete anywhere from 45 minutes to 4 hours.

# For Pi users. If you are using LynxCI, this script is already installed so simply powering on 
# your Pi is enough to start the process. No further interaction is needed after flashing your Micro
# SD card with the latest version of LynxCI, plugging it into your Pi and powering it one. This 
# script will support Pi 2 and 3 only please.

# Since this is the first time this loader.sh file has been executed, the /boot/loader file won't
# exist yet, so skip to the else portion of this conditional.

if [ -f /boot/loader ]; then

	# In the event that any other crontabs exist, let's purge them all.

	crontab -r

	# Since the /boot/loader file existed, let's purge it to keep things cleaned up.

	/bin/rm -rf /boot/loader 

	# Before we begin, we need to update the local repo's. Notice we aren't doing an upgrade. In some 
	# cases this bring ups prompts that need a human to make a decision and after a good bit of testing,
	# it was determined that trying to automate that portion was unneeded. For now, the update is all
	# we need and the device will still function properly.

	/usr/bin/apt-get update -y &> /dev/null

	#/usr/bin/apt-get upgrade -y

	# We need to ensure we have git for the following step. Let's not assume we already ahve it. Also
	# added a few other tools as testing has revealed that some vendors didn't have them pre-installed.

	/usr/bin/apt-get install git curl htop nano -y &> /dev/null

	# Some hosting vendors already have these installed. They aren't needed, so we are removing them 
	# now. This list will probably get longer over time.

	/usr/bin/apt-get remove postfix apache2 -y &> /dev/null

	# We are downloading the latest package of build instructions from github.

	/usr/bin/git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /root/LynxNodeBuilder/

	# We can't assume the file permissions will be right, so let's reset them.

	/bin/chmod 744 -R /root/LynxNodeBuilder/

	# Let's execute the build script. If building a test environment, be sure to use the 'testnet'
	# argument instead of 'mainnet'. The argument is required.

	/root/LynxNodeBuilder/installTest.sh testnet

# This is the first time the script has been executed.

else

	# In the event that any other crontabs exist, let's purge them all.

	crontab -r

	crontab -l | { cat; echo "*/15 * * * *		PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' /bin/sh /root/loaderTest.sh >> /var/log/syslog"; } | crontab -

	# Create the /boot/loader file so we don't get stuck in a loop.

	/usr/bin/touch /boot/loader

fi
