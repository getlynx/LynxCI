#!/bin/bash

# This script will setup the host OS, install all dependencies for Lynx and then execute the install
# script after a short wait time of 15 minutes. Some hosting vendors might require a manual reboot
# (i.e. HostBRZ) after the whole installation is complete.

# To get started, log into your VPS or Pi, and as root copy and paste the following line.

# wget -qO - https://test-explorer.getlynx.io/setup.sh | bash

# This will start the intallation. You can now close the session window in your termial or putty
# window. The script will run in the background without need for human interaction. Depending on the
# speed of your VPS or Pi2 or Pi3, the process will be complete anywhere from 45 minutes to 4 hours.

# For Pi users. If you are using LynxCI, this script is already installed so simply powering on
# your Pi is enough to start the process. No further interaction is needed after flashing your Micro
# SD card with the latest version of LynxCI, plugging it into your Pi and powering it one. This
# script will support Pi 2 and 3 only please.

IsProduction=N

# Since this is the first time this loader.sh file has been executed, the /boot/loader file won't
# exist yet, so skip to the else portion of this conditional.

if [ -f /boot/loader ]; then

	# In the event that any other crontabs exist, let's purge them all.

	crontab -r &> /dev/null

	# Since the /boot/loader file existed, let's purge it to keep things cleaned up.

	/bin/rm -rf /boot/loader

	# Before we begin, we need to update the local repo's. Notice we aren't doing an upgrade. In some
	# cases this bring ups prompts that need a human to make a decision and after a good bit of testing,
	# it was determined that trying to automate that portion was unneeded. For now, the update is all
	# we need and the device will still function properly.

	/usr/bin/apt-get update -y

	#/usr/bin/apt-get upgrade -y

	# We need to ensure we have git for the following step. Let's not assume we already ahve it. Also
	# added a few other tools as testing has revealed that some vendors didn't have them pre-installed.

	/usr/bin/apt-get install git curl htop nano -y

	# Some hosting vendors already have these installed. They aren't needed, so we are removing them
	# now. This list will probably get longer over time.

	/usr/bin/apt-get remove postfix apache2 -y

	# We are downloading the latest package of build instructions from github.

	/usr/bin/git clone https://github.com/doh9Xiet7weesh9va9th/LynxCI.git /root/LynxCI/

	# We can't assume the file permissions will be right, so let's reset them.

	/bin/chmod 744 -R /root/LynxCI/

	# Let's execute the build script.

	if [ "$IsProduction" = "Y" ]; then

		/root/LynxCI/install.sh mainnet

	else

		/root/LynxCI/installTest.sh testnet

	fi

# This is the first time the script has been executed.

else

	# In the event that any other crontabs exist, let's purge them all.

	crontab -r &> /dev/null

	# Since this is the first time the script is run, we will create a crontab to run it again
	# in a few minute, when a quarter of the hour rolls around.

	crontab -l &> /dev/null | { cat; echo "*/15 * * * *		PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' /bin/sh /root/setup.sh >> /var/log/syslog"; } | crontab -

	# The setup script is then downloaded to the root dir and permissions are set. So when the
	# crontab runs, the script is there and has the correct execute permissions.

	if [ "$IsProduction" = "Y" ]; then

		wget -qO /root/setup.sh https://explorer.getlynx.io/setup.sh

	else

		wget -qO /root/setup.sh https://test-explorer.getlynx.io/setup.sh

	fi

	chmod 744 /root/setup.sh

	# Create the /boot/loader file so we don't get stuck in a loop.

	/usr/bin/touch /boot/loader

	echo "

                        000000000   111111111   000000000
                 111111111111111111111000000000000111111111111
              000000000000000000000000000111111111111000000000000
           111111111111.........111111111111000000000000111111111111
         0000000000.................0000000000..1111111111..0000000000
       11111111............L............11111111....00000000....11111111
     0000000..............YYY..............0000000.....1111111.....0000000
    1111111..............NNNNNNNN...........1111111.....0000000.....1111111
   0000000..............XXXXXXXXXXXX..........000000......111111......000000
  1111111.............LLLLLLLLLLLLLLLLL........111111......000000......111111
  000000.............YYYYYYYYYYYYYYYYYYYY.......000000......111111......000000
  111111............NNNNNNNNNNNNNNNNNNNN........111111......000000......111111
  000000........XX..XXXXXXXXXXXXXXXXX...........000000......111111......000000
  111111.......LLL..LLLLLLLLLL..................111111......000000......111111
  000000.......YYY...YYYYYYYYYY....YY...........000000......111111......000000
  1111111......NNNNN...NNNNNNNNN...NN..........1111111.....0000000.....1111111
   0000000......XXXXXX....XXXXXX...XXXXX.......000000......111111......000000
    111111........LLLLLLLL....LL..............111111......000000......111111
     0000000........YYYYYYYY...Y............0000000.....1111111.....0000000
      1111111...........NNNN...............1111111.....0000000.....1111111
        0000000............X.............0000000.....1111111.....0000000
          111111111..................111111111...000000000...111111111
            000000000000........000000000000.11111111111.00000000000
              111111111111111111111111111000000000000111111111111
                  0000000000000000000111111111111000000000000
                        11111111   000000000   111111111

  .------------------------------------------------------.dCCCCCb.  IIIIIIIIII-.
 | LLLLL    YYYYYY   YYYY NNNNN      NNN XXXXXXX  XXXXX dCCCCCCCCCC IIIIIIIIII |
 | \`LLL'     \`YYY.   .Y'  \`NNNN.     \`N'  \`XXXX    XX'  CCC'   'CCC    IIII    |
 |  LLL       \`YYY. .Y'    N \`NNN.    N     XXXX..XX    CCC            IIII    |
 |  LLL        \`YYY.Y'     N   \`NNN.  N      \`XXXX'     CCC            IIII    |
 |  LLL         \`YYY'      N     \`NNN.N     .XXXXXX.    CCb.   .dCC    IIII    |
 |  LLL      ,L  YYY      ,N.      \`NNN    XX'  \`XXXX   CCCCCCCCCCC IIIIIIIIII |
 | LLLLLLLLLLLL YYYYY     NNN        \`N  XXXXX  XXXXXXX  'CCCCCCC'  IIIIIIIIII |
 '-----------------------------------------------------------------------------'
 | https://getlynx.io                            Lynx Cryptocurrency Installer |
 '-----------------------------------------------------------------------------'
 | https://explorer.getlynx.io                             Twitter: @getlynxio |
 '-----------------------------------------------------------------------------'

   The installer will start itself in 15 minutes.
   You can log out now or review the log at /var/log/syslog.

   "

fi
