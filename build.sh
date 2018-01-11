#!/bin/bash -x

# - To learn about the cryptocurrency Lynx, visit https://getlynx.io
# - This script will create a full Lynx node with visual RPC viewer (Block Crawler) AND act as a 
# 	lightweight micro-miner.
# - This build now includes a light weight block crawler. In your browser, just visit the IP 
#	address or FQDN value you entered when done (be sure to set up your 
#	DNS properly). ie. http://seed11.getlynx.io
# - If SSH (port 22) is disabled. You must use Lish or KVM to login. 
# - Pool mining is enabled with this script, by default. 'cpuminer' is used and self 
#	tuned. ~5 khash/s on a Linode 2048 is normal. Random pool selection will occur from 
#	2 multipool.us pools, for redundancy when one is down for service.
# - Per Linode Support restrictions, this build averages 65% cpu usage, so mining is slowed.
# - Remote RPC mining functions are restricted, but can be adjusted in /etc/rc.local.
# - Be patient, it will take about 15 hours for this script to complete. 
# - The wallet is configured to be disabled, so no funds are stored on this node.
# - Root login is denied. Your user account has sudo. 

# Submit ideas to make this script better @ https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder

# When this script is complete, you will have a fully functioning Lynx node that will confirm
# transactions on the Lynx network. The script processes include directly downloading the bulk of 
# the blockchain, unpacking it and forcing the node to reconfirm the chain faster. This script will 
# run for about 15 hours before it completes. I will reboot and . start lynxd on it's own. The
# server can be rebooted anytime after the first 15 hours and the Lynx daemon will restart
# automatically. If mining functions are part of this script, they will automatically start after
# a reboot too.

# *** If you are running a Linode with a version of this script that is not current, then shut it
# down and rebuild based on this script. The old Stackscript is out of date and probably not
# working with the new code updates.

# Management advice: Deploy this script once and never log into the server. Your work is done. If
# you are worried about security, new updates and new versions, just 'REBUILD' a new (2048) Linode
# and select this script again. It will always build an up-to-date Lynx node. Only the latest
# version of this Stackscript exists. Upgrades to the scripts happen all the time. Try to be sure
# you are running the latest version.

# THIS SCRIPT WILL RESTRICT YOUR ABILITY TO LOG IN AS ROOT. You MUST use the user account you 
# entered when deploying the script. The newly created user will have `sudo`. The ssh is monitored
# by fail2ban with it's default settings and the root user is disabled from SSH login.

#
#
# These are used by the Linode Stackscript implementation. If you want to run this script on your 
# Raspberry pi or an another VPS vendor, just replace the following 5 lines with named variables
# and values for the script.

#<UDF name="hostname" label="The name for this node?" default="seed002" example="seed002" />
#<UDF name="fqdn" label="The new Linode's Fully Qualified Domain Name" default="seed002.getlynx.io" example="seed002.getlynx.io" />
#<UDF name="ssuser" Label="User account for Lynx." example="username" />
#<UDF name="sspassword" Label="Password for Lynx account." example="Passw0rd" />
#<UDF name="isssh" Label="Allow SSH access?" oneOf="true,false" default="false" example="Unless you intend to mess with it, disable access." />
#<UDF name="isminer" Label="Enable the miner?" oneOf="true,false" default="true" example="Supports the network with spare idle CPU." />

#
#
# This sets the variable $IPADDR to the IP address the new Linode receives. We use this later
# in the script when setting up the hosts file

IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')

#
#
# This section sets the hostname. Basic stuff. Just automating it to save time later. We want
# this working for reverse dns and to make the terminal prompt tell us what machine we on. If
# you run this script 50 times like we do. it can get kind of confusing.

echo $HOSTNAME > /etc/hostname && hostname -F /etc/hostname

#
#
# This section sets the Fully Qualified Domain Name (FQDN) in the hosts file. To finish this,
# you should set up your DNS and reverse DNS too.

echo $IPADDR $FQDN $HOSTNAME >> /etc/hosts

#
#
# Add a user. We will be isntalling the Lynx node code under root as well as the miner if you
# chose to run it, but you must log into the server with the user account you created. This is
# an additional security feature of the server. Lets not make any classic mistakes.

adduser $SSUSER --disabled-password --gecos "" && \
echo "$SSUSER:$SSPASSWORD" | chpasswd

#
#
# Give the new user sudo.

adduser $SSUSER sudo

#
#
# Disable login from root. The owner of this device can no longer log in directly to root. This
# also staves off a lof of probes that troll port 22. No need for it. Fail2ban will pick up on
# that chatter later and ban those bothersome probe ip addresses.

sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

#
#
# We will install htop for easier viewing of system processes. This is more for debug purposes.
# The use of fail2ban is important if the SSH port (22) is going to be used. We will be 
# updating the default SSH jail later in this script with a longer ban time if an attacker
# pushes enough buttons.

apt-get install htop fail2ban -y

#
#
# This package cpulimit (http://cpulimit.sourceforge.net) is used if the miner package is 
# installed. We install this package regardless of whether we will use it or not later.

apt-get install cpulimit -y

#
#
# Here we install needed packages for the included lightweight local block explorer.

apt-get install nginx php7.0-fpm php-curl -y

#
#
# We need to modify the defaul Nginx build to accept the use of PHP-FPM. Let's backup the old
# and create a new default config for this site.

mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
echo "

server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /var/www/html;

        index index.php;

        server_name _;

        location / {
                try_files \$uri \$uri/ =404;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        }

}

" > /etc/nginx/sites-available/default


#
#
# Pull down the latest BlockCrawler code and place it in the needed directory. Then move it 
# properly and do some cleanup.

cd /var/www/html/ && wget http://cdn.getlynx.io/BlockCrawler.tar.gz
tar -xvf BlockCrawler.tar.gz
cd BlockCrawler && mv * .. && cd .. && rm -R BlockCrawler

#
#
# The configuration of the block explorer with the local credentials to access the local 
# RPC server. Notice those special variables are escaped in sed. sed is a very sensitive artist.

sed -i -e 's/'"127.0.0.1"'/'"$IPADDR"'/g' /var/www/html/bc_daemon.php
sed -i -e 's/'"8332"'/'"9332"'/g' /var/www/html/bc_daemon.php
sed -i -e 's/'"username"'/'"$HOSTNAME"'/g' /var/www/html/bc_daemon.php
sed -i -e 's/'"password"'/'"$SSPASSWORD"'/g' /var/www/html/bc_daemon.php

#
#
# Now that the set up is complete, let's start the Nginx and FPM services and set them to
# start on reboot.

systemctl restart nginx && systemctl enable nginx && systemctl restart php7.0-fpm

#
#
# Prep the OS with some bitcoin library dependencies

add-apt-repository -y ppa:bitcoin/bitcoin

#
#
# Update the OS and force prompts, again. This batch of code pushes past the grub updater 
# prompt and other prompts for system updates.

apt-get -o Acquire::ForceIPv4=true update -y
DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
apt-get -o Acquire::ForceIPv4=true upgrade -y

#
#
# Let's install more packages we will need.

apt-get install git-core build-essential autoconf libtool libssl-dev libboost-all-dev libminiupnpc-dev libevent-dev libncurses5-dev pkg-config -y

#
#
# Let's pull down the latest Lynx repo from Github. This will always get the letest build so
# updates via git aren't really needed. To update to the latest version, just build a new server.

git clone https://github.com/doh9Xiet7weesh9va9th/lynx.git /root/lynx/

#
#
# Go to that dir and then specify the branch we are interested in. We need to make sure we place
# the code in the right dir and checkout the right branch (lynx) - at the time of this writing.

cd /root/lynx

#
#
# Create the config dir for the user to store files in after the node starts. Then jump to it
# for the next step. It's important we be in the .lynx dir for the next step.

mkdir -p /root/.lynx && cd /root/.lynx

#
#
# Pull down and unpack the blockchain history so we don't have to wait so long and burden the
# network. This file contains all blockchain transactions from 2013 to the end of 2017.

wget http://cdn.getlynx.io/bootstrap.tar.gz

#
#
# Remember, we need to place the boostrap inside of the .lynx directory. This file is
# automatically deleted after Lynx imports it and rebuilds it's chainstate. If you notice this
# file is gone after a few reboots, it is okay. Clean up scripts later will purge the
# original tarball.

tar -xvf bootstrap.tar.gz bootstrap.dat

#
#
# Make sure the bootstrap has correct ownership.

chown -R root:root /root/.lynx/*

#
#
# Pull down a version of the cpuminer code to the home dir. We do cleanup in the rc.local file
# later. We will use this if we turned on mining functions. It's okay to install this if mining
# won't be done locally. It consume little space on the drive.
#
# https://sourceforge.net/projects/cpuminer/files/pooler-cpuminer-2.5.0-linux-x86_64.tar.gz

cd && wget http://cdn.getlynx.io/pooler-cpuminer-2.5.0-linux-x86_64.tar.gz

#
#
# For the sake of being thorough, here is the 32 bit version for Linux.
# https://sourceforge.net/projects/cpuminer/files/pooler-cpuminer-2.5.0-linux-x86.tar.gz

# cd && wget pooler-cpuminer-2.5.0-linux-x86.tar.gz

#
#
# Unpack it in the root home dir. This will leave the file 'minerd' in the root home dir. If we
# opted to do mining in this build, we will start it, otherwise it will just sit.

tar -xvf pooler-cpuminer-2.5.0-linux-x86_64.tar.gz

#
#
# Lets change the ownership of the lynx dirs and associated .lynx dir to the new user account.
# This was partially done earlier but sometimes, it misses a file. Doing, just be be sure.

chown -R root:root /root/lynx && chown -R root:root /root/.lynx

#
#
# Delete the rc.local file so we can recreate it with our firewall rules and follow-up scripts.

rm -R /etc/rc.local

#
#
# We will be recreating the rc.local file with a custom set of instructions below. This file is 
# only executed when the server reboots. It is (arguably) less tempermental then using a crontab
# and since this server probably won't be rebooted that often, it's a fine place to insert these 
# instructions. Also it's a very convenient script to run manually if needed, so rock on.

echo "
#!/bin/sh -e
#
#
# inits

#
#
# Becuase we are setting the values of 2 variables in this, rc.local file, we need to escape the
# expressions below where the variables are referenced. So we set the values here, and they can be
# changed in the future easily (followed by a reboot). But you will see the variables escaped
# in this script so they will work later when the rc.local file is created. It may look odd here
# but after this script runs, you will see a legit variable name below. Not to be confused with
# the variables name references we see for the variables at this top of this script. Those are
# used when the script is run for the very first time and are not subject to the particularities
# of the rc.local file. Instead of a reboot, you can always execute the rc.local as root and it
# will reset like a reboot. I prefer a reboot as a it shuts down orphaned processes that might 
# still be running.

IsSSH=$ISSSH
IsMiner=$ISMINER


#
#
# If the 'lynxd' process is NOT running, then run the contents of this conditional. So the first
# time the script runs, like after a reboot the firewall will get set up. We are going to set up
# a crontab and run this file regularly.

if ! pgrep -x "lynxd" > /dev/null; then

	#
	#
	# The following iptables rules work well for running a tight server. Depending on the build
	# you executed with your Stackscript, your rules might be slightly different. The three basic
	# rules we care about are SSH (22), the Lynx Node RPC port used for mining (9332) and the
	# Lynx Nodenetwork port to listen from other Lynx nodes (22566).

	iptables -F
	iptables -I INPUT 1 -i lo -j ACCEPT
	iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

	#
	#
	# What fun would this be if someone didn't try to DDOS the block explorer? Lets assume they are 
	# gonna go at it old school and reuse the same addresses.

	iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --set
	iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP

	#
	#
	# If you opt to run this server without SSH (22) access, you won't be able to log in unless you
	# have a keyboard physically attached to the node. Or you can use Lish if you are using Linode,
	# which is basically the same thing.

	if [ \$IsSSH = true ]; then
		iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	fi

	#
	# We only need to open port 9332 if we intend to allow outside miners to send their work
	# to this node. By default, this is disbled, but you can enable it be uncommenting this line
	# and re-executing this file to load it. The Lynx node will start up listening to port 9332,
	# but you will have to add the IP address of the miner so it can connect.

	# iptables -A INPUT -p tcp --dport 9332 -j ACCEPT

	#
	#
	iptables -A INPUT -p tcp --dport 80 -j ACCEPT
	iptables -A INPUT -p tcp --dport 22566 -j ACCEPT
	iptables -A INPUT -j DROP

	#
	#
	# Let's look for and clean up some left over build files that were used when this node was
	# first built. This will look after each reboot and silently remove these files if found.
	# Since this build is intended to be hands off, this script shouldn't be run very often. If
	# you want to update this node, it is best to just build a new server from this whole script
	# again.

	rm -Rf /root/.lynx/bootstrap.tar.gz
	rm -Rf /root/.lynx/bootstrap.dat.old
	rm -Rf /root/pooler-cpuminer-2.5.0-linux-x86_64.tar.gz
	rm -Rf /etc/update-motd.d/10-help-text

	#
	#
	# Start the Lynx Node. This is the bread and butter of the node. In all cases this should 
	# always be running. A crontab will also be run @hourly with the same command in case Lynx
	# ever quits. We found after extensive testing that this command would not fire correctly as
	# part of the /rc.local file after boot. So, instead a @hourly & @reboot crontab was
	# created with this instead.

	#
	# Removed this because the start process isn't working properly in the rc.local file. Instead
	# starting as a separate crontab.

	# cd /root/lynx/src/ && ./lynxd -daemon

#
#
# The end of the initial conditional interstitial

fi


#
#
# Of course after each reboot, we want the local miner to start, if it is set to turn on in
# this configuration. Notice we didn't open port 9332 on the firewall. This restricts outside
# miners from connecting to this node. This miner is only doing pool mining. It will get a few
# shares at the mining pool, but it will provide redundancy on the network in case big pools
# go down.

if [ \$IsMiner = true ]; then
	if pgrep -x "lynxd" > /dev/null; then
		if ! pgrep -x "minerd" > /dev/null; then

			#
			#
			# For solo mining, this configuration will work. But it's not very efficient and will
			# rarely ever score you a block. The reward for the work is so low, it's no worth wasting
			# the CPU on it. Might as well toss it towards a mining pool.

			# cd /root/ && ./minerd -o $IPADDR:9332 -u $HOSTNAME -p $SSPASSWORD --coinbase-addr=KShRcznENXJt61PWAEFYPQRBDSPdWmckmg -R 15 -B -S

			#
			#
			# Using a random outcome, the mining pool selected with be up to fate. If the miner is 
			# being started, we will select a pool at random and go with that one. This way, if one
			# pool ever goes down, we will ahve coverage from other pools, ensuring that blocks
			# are alwasys being generated.

			if [ \$(shuf -i 1-2 -n 1) -eq 1 ]; then

				#
				#
				# Here, we connect to our friends at EU Multipool.us. If you want credit for the
				# mining work, create an account at https://www.multipool.us and update the worker name.
				# Otherwise leave this setting, and donate any rewards to the Lynx Development Team.

				cd /root/ && ./minerd -o stratum+tcp://eu.multipool.us:3348 -u benjamin.seednode -p x -R 15 -B -S

			else

				#
				#
				# Here, we connect to our friends at US Multipool.us. If you want credit for the
				# mining work, create an account at https://www.multipool.us and update the worker name.
				# Otherwise leave this setting, and donate any rewards to the Lynx Development Team.

				cd /root/ && ./minerd -o stratum+tcp://us.multipool.us:3348 -u benjamin.seednode -p x -R 15 -B -S

			fi
		fi
	fi
fi

#
#
# During the initial built we installed cpulimit (http://cpulimit.sourceforge.net)
# It listens for the miner package when it runs and if detected, it will throttle 
# it to average about 80% of the processor instead of the full 100%. Linode and
# and some VPS vendors might have a problem with a node that is always using 100%
# of the processor so this is a simple tune-down of the local miner when it runs.
# If the minerd (https://github.com/pooler/cpuminer) process is not found, it will
# silently listen for it. It's fine to leave it running. Uses barely any resources.

if [ \$IsMiner = true ]; then
	if ! pgrep -x "cpulimit" > /dev/null; then
		cpulimit -e minerd -l 60 -b
	fi
fi

#
#
# You can always watch the debug log from your user account to check on the node's progress.

# $sudo tail -F /root/.lynx/debug.log

#
#
# You can also see who the firewall is blocking with fail2ban and see what ports are open

# $sudo iptables -L -vn

#
#
# The miner logs to the syslog, if it was installed in this built script.

# $sudo tail -F /var/log/syslog

#
#
# Its important this last line of the script remains here. Please dont touch it. 

exit 0

#
#trumpisamoron
#
" > /etc/rc.local

#
#
# Let's purge that first line in the rc.local file that was just created. For some reason, I
# couldn't avoid that first empty line above and I think it causes problems if I leave it there.
# No big deal. Let's just purge the first line only to keep it clean. #trumpisamoron

sed '1d' /etc/rc.local > tmpfile; mv tmpfile /etc/rc.local

#
#
# Let's not make any assumptions about the file permissions on teh rc.local file we just created. 
# We will force it to be 755.

chmod 755 /etc/rc.local

#
#
# Let's set up the /root/.lynx/lynx.conf file for the Lynx node code.

echo "

listen=1
daemon=1
rpcuser=$HOSTNAME
rpcpassword=$SSPASSWORD
rpcport=9332
port=22566
rpcbind=$IPADDR
rpcallowip=$IPADDR
listenonion=0

" > /root/.lynx/lynx.conf

#
#
# Let's tighten up the firewall to SSH only while we are going through this initial build time. We
# notices lots of port probes so let's reduce risk by only exposing port 22. Remember we already 
# locked out root from login and fail2ban is gonna start shortly to ban bad guys on 22.

iptables -F
iptables -I INPUT 1 -i lo -j ACCEPT
iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -j DROP

#
#
# The default ban time for abusers on port 22 (SSH) is 10 minutes. Lets make this a full 24 hours
# that we will ban the IP address of the attacker. This is the tuning of the fail2ban jail that
# was documented earlier in this file. THe number 86400 is the number of seconds in a 24 hour term.

sed -i '$ a bantime = 86400' /etc/fail2ban/jail.d/defaults-debian.conf

#
#
# Let's use fail2ban to prune the probe attempts on port 22. If the jail catches someone, the IP
# is locked out for 24 hours. We don't reallY want to lock them out for good. Also if SSH (22) is
# not made public in the iptables rules, this package is not needed. It consumes so little cpu
# time that I decide to leave it along. Fail2ban will always start itself so no need to add it to 
# rc.local or a crontab.

service fail2ban start

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

./configure CXXFLAGS="--param ggc-min-expand=1 --param ggc-min-heapsize=32768" --enable-cxx --disable-wallet

#
#
# Finally, lets start the compile. It take about 45 minutes to complete on a single CPU 1024
# Linode. Probably a bit faster on a Rasperry Pi 3. If you add the 'j' flag and specify the number
# of processors you have, you can shorten this time significantly.

make

#
#
# The idea to to start lynxd shortly after the server has be rebooted, for whatever reason. Then
# After a short initilization period, the rc.local file resets the firewall and starts the miner
# if it is turned on. Also the CPUlimit isset up too. After 15 days, the server is automatically
# rebooted. Sometimes the server goes into swap, of the cache in lynxd fills. We do the staggered 
# reboot to that all the servers don't reboot themselves at the same time, leaving no seed nodes
# up when needed. Also, if no big miners are working, at least one of the seed nodes will still 
# be submitting shares to the pool, if enabled.

crontab -l | { cat; echo "*/5 * * * *		cd /root/lynx/src/ && ./lynxd -daemon"; } | crontab -
crontab -l | { cat; echo "*/15 * * * *		sh /etc/rc.local"; } | crontab -
crontab -l | { cat; echo "0 0 */15 * *		reboot"; } | crontab -

#
#
# We are all done building the node and putting everything in place. Let's reboot the node and
# let rc.local take over with start jobs an then crontab will kick in occasionally with checks.

reboot

#
#