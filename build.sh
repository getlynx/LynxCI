#!/bin/bash

BLUE='\033[94m'
GREEN='\033[32;1m'
YELLOW='\033[33;1m'
RED='\033[91;1m'
RESET='\033[0m'

print_info () {

	printf "$BLUE$1$RESET\n"
	sleep 1

}

print_success () {

	printf "$GREEN$1$RESET\n"
	sleep 1

}

print_warning () {

	printf "$YELLOW$1$RESET\n"
	sleep 1

}

print_error () {

	printf "$RED$1$RESET\n"
	sleep 1

}

detect_os () {

	OS=`cat /etc/os-release | egrep '^ID=' | cut -d= -f2`
	print_success "The local OS is a flavor of '$OS'."

}

detect_ec2() {

	IsEC2="N"

    # This first, simple check will work for many older instance types.

    if [ -f /sys/hypervisor/uuid ]; then

		# File should be readable by non-root users.

		if [ `head -c 3 /sys/hypervisor/uuid` == "ec2" ]; then
			IsEC2="Y"
		fi

    # This check will work on newer m5/c5 instances, but only if you have root!

    elif [ -r /sys/devices/virtual/dmi/id/product_uuid ]; then

		# If the file exists AND is readable by us, we can rely on it.

		if [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "EC2" ]; then
			IsEC2="Y"
		fi

    else

		# Fallback check of http://169.254.169.254/. If we wanted to be REALLY
		# authoritative, we could follow Amazon's suggestions for cryptographically
		# verifying their signature, see here:
		# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-identity-documents.html
		# but this is almost certainly overkill for this purpose (and the above
		# checks of "EC2" prefixes have a higher false positive potential, anyway).

		if $(curl -s -m 5 http://169.254.169.254/latest/dynamic/instance-identity/document | grep -q availabilityZone) ; then
			IsEC2="Y"
		fi
    fi

}

detect_vps () {

	detect_ec2
}

compile_query () {

	# Since this script is currently written to support Raspian and Ubuntu, we will only display
	# the configuration prompts on Raspian (for the Raspberry Pi users).

	if [ "$OS" != "ubuntu" ]; then

		# Set the query timeout value (in seconds)
		time_out=15

		query1="Install the light weight Block Crawler (C) or resource intensive Block Explorer (e) (C/e):"
		query2="Do you want SSH access enabled for public access? (y/N):"
		query3="Do you want to sync with the bootstrap file (less network intensive)? (Y/n):"
		query4="Do you want the miner to run? (Y/n):"

		# This answer tells us to install the Block Crawler which is much less system intensive
		# or the Block Explorer which takes forever to index. It is recommended to stick to the 
		# Block Crawler on a Raspberry Pi device. If you are running a Linode or AMI with more power
		# then using the Block Explorer option will work nicely.

		read -t $time_out -p "$query1 " ans1

		# Accessing the device via SSH is always an option if you are on the same local network, 
		# like with an address format of 192.x.x.x or 10.x.x.x, but if you enable public access 
		# you will allow any IP to be able to authenticate and log in via terminal. For a more 
		# secure device, leave the default to No. 

		read -t $time_out -p "$query2 " ans2

		read -t $time_out -p "$query3 " ans3

		# We are currently mining to pools and solo mining. The device randomly set this for you but
		# you can override this along with your own mining address in the set_miner() function.

		read -t $time_out -p "$query4 " ans4

		# Set the flag to determine if the Explorer or Crawler is being installed. The default is
		# to install the Block Crawler.

		case "$ans1" in
			c|C) blockchainViewer=C ;;
			e|E) blockchainViewer=E ;;
			*) blockchainViewer=C ;;
		esac

		# Set the flag to determine if the firewall to allow public IP addresses to be able to log
		# into this device.

		case "$ans2" in
			y|Y) enable_ssh=Y ;;
			n|N) enable_ssh=N ;;
			*) enable_ssh=Y ;;
		esac

		#
		# Set the latest bootstrap flag
		#
		case "$ans3" in
			y|Y) useBootstrapFile=Y ;;
			n|N) useBootstrapFile=N ;;
			*) useBootstrapFile=Y ;;
		esac

		# Set the mining enabled flag

		case "$ans4" in
			y|Y) enable_mining=Y ;;
			n|N) enable_mining=N ;;
			*) enable_mining=Y ;;
		esac

	else

		# Becuase 'ubuntu' doesn't play well with our query, we go with the defaults.
		blockchainViewer=E
		enable_ssh=N
		useBootstrapFile=Y
		enable_mining=Y

	fi

}

update_os () {

	print_success "The local OS, '$OS', will be updated."

	if [ "$OS" = "debian" ]; then
		apt-get -o Acquire::ForceIPv4=true update -y
		DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
		apt-get -o Acquire::ForceIPv4=true upgrade -y
	elif [ "$OS" = "ubuntu" ]; then
		apt-get -o Acquire::ForceIPv4=true update -y
		DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
		apt-get -o Acquire::ForceIPv4=true upgrade -y
	else
		truncate -s 0 /etc/motd && cat /root/LynxNodeBuilder/logo.txt >> /etc/motd

		echo "
 | To set up wifi, edit the /etc/wpa_supplicant/wpa_supplicant.conf file.      |
 '-----------------------------------------------------------------------------'" >> /etc/motd

		# 'raspbian' would evaluate here.
		print_success "Raspbian was detected. You are using a Raspberry Pi. We love you."

		touch /boot/ssh
		print_success "SSH access was enabled by creating the SSH file in /boot."

		sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
		print_success "Swap will be increased to 1GB on reboot."
		
		apt-get update -y
		apt-get upgrade -y
	fi

}

set_network () {

	ipaddr=$(ip route get 1 | awk '{print $NF;exit}')
	hhostname="lynx$(shuf -i 100000000-199999999 -n 1)"
	fqdn="$hhostname.getlynx.io"
	print_success "Setting the local fully qualified domain name to '$fqdn.'"

	echo $hhostname > /etc/hostname && hostname -F /etc/hostname
	print_success "Setting the local host name to '$hhostname.'"

	if [ "$OS" = "raspbian" ]; then

		sed -i "/127.0.1.1/c\127.0.1.1       raspberrypi $fqdn $hhostname" /etc/hosts
		print_success "The IP address of this machine is $ipaddr."

	else

		echo $ipaddr $fqdn $hhostname >> /etc/hosts
		print_success "The IP address of this machine is $ipaddr."

	fi

}

set_wifi () {

	# The only time we want to set up the wifi is if the script is running on a Raspberry Pi. The
	# script should just skip over this step if we are on any OS other then Raspian. 

	if [ "$OS" = "raspbian" ]; then

		# Let's assume the files already exists, so we will delete them and start from scratch.

		rm -Rf /boot/wpa_supplicant.conf
		rm -Rf /etc/wpa_supplicant/wpa_supplicant.conf

		# Let the user know the file they need to edit AFTER the script completes and the
		# Raspberry Pi reboots for the first time.

		print_error "To set up wifi, edit the /etc/wpa_supplicant/wpa_supplicant.conf file."
		
		echo "

		ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
		update_config=1
		country=US

		network={
			ssid=\"Your network SSID\"
			psk=\"Your WPA/WPA2 security key\"
			key_mgmt=WPA-PSK
		}

		" >> /boot/wpa_supplicant.conf

	fi

}

set_accounts () {

	sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
	print_success "Direct login via the root account has been disabled. You must log in as a user."

	if [ "$OS" != "raspbian" ]; then

		ssuser="lynx"
		print_warning "The user account '$ssuser' was created."

		sspassword="lynx"
		print_warning "The default password is '$sspassword'. Be sure to change after this build is complete."

		adduser $ssuser --disabled-password --gecos "" && \
		echo "$ssuser:$sspassword" | chpasswd

		adduser $ssuser sudo
		print_success "The new user '$ssuser', has sudo access."

	fi

}

install_iquidusExplorer () {

	# At the beginning of the script we asked the user to chose if the Block Explorer should
	# be installed or not. If they opted for it, then the more resource intensive Block Explorer
	# will be installed.

	if [ "$blockchainViewer" != "E" ]; then
		return 1
	fi

	# chdir to root directory
	cd ~/

	# remove old data about npm/explorer
	rm -rf ~/LynxExplorer && rm -rf ~/.npm-global

        print_success "Installing nodejs..."
        apt-get install -y curl npm nodejs-legacy
	#curl -k -O -L https://npmjs.org/install.sh
        npm install -g n && n 8

	# change npm dir prefix 
	#mkdir ~/.npm-global
  	#npm config set prefix '~/.npm-global'
  	#export PATH=~/.npm-global/bin:$PATH
  	#source ~/.profile
	
	print_success "Installing PM2..."

	npm install pm2 -g
		
	#pm2 install pm2-logrotate
	#pm2 set pm2-logrotate:retain 7
	#pm2 set pm2-logrotate:compress true

	print_success "Installing Iquidus Explorer..."

	git clone https://github.com/doh9Xiet7weesh9va9th/LynxExplorer.git
	cd /root/LynxExplorer/ && npm install --production

	print_success "Generating Iquidus config file..."

	# We need to update the json file in the LynxExplorer node app with the lynxd RPC access
	# credentials for this device. Since they are created dynamically each time, we just do
	# find and replace in the json file.

	sed -i "s/__HOSTNAME__/x${fqdn}/g" /root/LynxExplorer/settings.json
	sed -i "s/__MONGO_USER__/x${rrpcuser}/g" /root/LynxExplorer/settings.json
	sed -i "s/__MONGO_PASS__/x${rrpcpassword}/g" /root/LynxExplorer/settings.json
	sed -i "s/__LYNXRPCUSER__/${rrpcuser}/g" /root/LynxExplorer/settings.json
	sed -i "s/__LYNXRPCPASS__/${rrpcpassword}/g" /root/LynxExplorer/settings.json

	# start IquidusExplorer process using pm2
	pm2 stop IquidusExplorer
	pm2 delete IquidusExplorer
	pm2 start npm --name IquidusExplorer -- start
	pm2 save
	pm2 startup ubuntu

	# Yeah, we are probably putting to many comments in this script, but I hope it proves
	# helpful to someone when they are having fun but don't know what a part of it does.

	print_success "Iquidus Explorer was installed"
	print_success "The local Block Explorer can be browsed at http://$hhostname.local/"
}

install_blockcrawler () {

	# At the beginning of the script we asked the user to chose if the Block Crawler should be 
	# installed or not. If they opted for it or they didn't change the default, then the less 
	# resource inntensive Block Crawler will be installed.

	if [ "$blockchainViewer" = "C" ]; then
	
		apt-get install nginx php7.0-fpm php-curl -y
		print_success "Installing Nginx..."

		mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

		echo "
		server {
			listen 80 default_server;
			listen [::]:80 default_server;
			root /var/www/html/Blockcrawler;
			index index.php;
			server_name _;
			location / { try_files \$uri \$uri/ =404; }
			location ~ \.php$ {
				include snippets/fastcgi-php.conf;
				fastcgi_pass unix:/run/php/php7.0-fpm.sock;
			}
		}
		" > /etc/nginx/sites-available/default
		print_success "Nginx is configured."

		cd /var/www/html/ && wget http://cdn.getlynx.io/BlockCrawler.tar.gz
		tar -xvf BlockCrawler.tar.gz
		chmod 755 -R /var/www/html/Blockcrawler/
		chown www-data:www-data -R /var/www/html/Blockcrawler/
		
		sed -i -e 's/'"8332"'/'"9332"'/g' /var/www/html/Blockcrawler/bc_daemon.php
		sed -i -e 's/'"username"'/'"$rrpcuser"'/g' /var/www/html/Blockcrawler/bc_daemon.php
		sed -i -e 's/'"password"'/'"$rrpcpassword"'/g' /var/www/html/Blockcrawler/bc_daemon.php
		print_success "Block Crawler code is secured for this Lynxd node."

		systemctl restart nginx && systemctl enable nginx && systemctl restart php7.0-fpm
		print_success "Nginx is set to auto start on boot."

		iptables -I INPUT 3 -p tcp --dport 80 -j ACCEPT
		print_success "The Block Crawler can be browsed at http://$ipaddr/"

	fi

}

install_extras () {

	apt-get install cpulimit htop curl fail2ban -y
	print_success "The package 'cpulimit' was installed."

	apt-get install automake autoconf pkg-config libcurl4-openssl-dev libjansson-dev libssl-dev libgmp-dev make g++ libminiupnpc-dev -y
	print_success "Extra packages for CPUminer were installed."

}

install_miniupnpc () {

	if [ "$OS" = "raspbian" ]; then

		print_info "Installing miniupnpc."
		apt-get install libminiupnpc-dev -y

	fi

}

install_lynx () {

	apt-get install git-core build-essential autoconf libtool libssl-dev libboost-all-dev libminiupnpc-dev libevent-dev libncurses5-dev pkg-config -y

	rrpcuser="$(shuf -i 200000000-299999999 -n 1)"
	print_warning "The lynxd RPC user account is '$rrpcuser'."
	rrpcpassword="$(shuf -i 300000000-399999999 -n 1)"
	print_warning "The lynxd RPC user account is '$rrpcpassword'."

	print_success "Pulling the latest source of Lynx from Github."
	rm -rf /root/lynx/
	git clone https://github.com/doh9Xiet7weesh9va9th/lynx.git /root/lynx/
	cd /root/lynx/ && ./autogen.sh

	if [ "$OS" = "raspbian" ]; then
		./configure --without-gui --disable-wallet --disable-tests --with-miniupnpc --enable-upnp-default
	else
		./configure --without-gui --disable-wallet --disable-tests
	fi

	print_success "The latest state of Lynx is being compiled now."
	make

	if [[ "$useBootstrapFile" == "Y" ]]; then

		cd ~/ && rm -rf .lynx && mkdir .lynx
		print_success "Created the '.lynx' directory."

		wget http://cdn.getlynx.io/node-bootstrap.tar.gz
		tar -xvf node-bootstrap.tar.gz .lynx
		rm -rf node-bootstrap.tar.gz
		print_success "The node-bootstrap file was downloaded and will be used after reboot."
	else
		print_error "The node-bootstrap file was not downloaded."
	fi

	echo "
	listen=1
	daemon=1
	rpcuser=$rrpcuser
	rpcpassword=$rrpcpassword
	rpcport=9332
	port=22566
	rpcbind=127.0.0.1
	rpcallowip=127.0.0.1
	listenonion=0
	upnp=1
	txindex=1
	" > /root/.lynx/lynx.conf

	print_success "Default '/root/.lynx/lynx.conf' file was created."

	chown -R root:root /root/.lynx/*

}

install_cpuminer () {

	apt-get install automake autoconf pkg-config libcurl4-openssl-dev libjansson-dev libssl-dev libgmp-dev make g++ -y

	rm -rf /root/cpuminer
	git clone https://github.com/tpruvot/cpuminer-multi.git /root/cpuminer
	print_success "Mining package was downloaded."
	cd /root/cpuminer
	./autogen.sh

	if [ "$OS" = "debian" ]; then
		# compile on Debian 9 fails. Seems to be a missing lib. Dropping support for Debian 9 for now.
		./configure CFLAGS="-march=native" --with-crypto --with-curl
	elif [ "$OS" = "ubuntu" ]; then
		./configure CFLAGS="-march=native" --with-crypto --with-curl
	else
		# raspbian
		./configure --disable-assembly CFLAGS="-Ofast -march=native" --with-crypto --with-curl
	fi

	make

	print_success "CPUminer Multi was compiled."

}

install_mongo () {

	if [ "$blockchainViewer" = "E" ]; then

	    apt-get install mongodb-server -y
	    print_success "Installing mongodb..."

	    service mongodb start
	    if pgrep -x "mongod" > /dev/null
	    then
	    	print_success "MongoDB was installed, and is running!"
	    else
	    	mongodbstart
	        echo "Stopped"
	    fi

	    sleep 10 # fix connection error issue

	    account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"   
	    echo "${account}"

	    if [ $(mongo --version | grep -w '2.4' | wc -l) -eq 1 ]; then
			echo "db.addUser( ${account} )"
			mongo lynx --eval "db.addUser( ${account} )"
	    elif [ $(mongo --version | grep -w '2.6' | wc -l) -eq 1  ]; then
			echo "warning"
			echo "db.addUser( { ${account} )"
			mongo lynx --eval "db.addUser( ${account} )"
	    else
			echo "db.addUser( { ${account} )"
			mongo lynx --eval "db.createUser( ${account} )"
	    fi

    fi
}

set_firewall () {

	# To make sure we don't create any problems, let's truly make sure the firewall instructions
	# we are about to create haven't already been created. So we delete the file we are going to
	# create in the next step. This is just a step to insure stability and reduce risk in the 
	# execution of this build script.

	rm -rf /root/firewall.sh

	echo "

	#!/bin/bash

	IsSSH=$enable_ssh

	# Let's flush any pre existing iptables rules that might exist and start with a clean slate.

	/sbin/iptables -F

	# We always shold allow loopback traffic.

	/sbin/iptables -I INPUT 1 -i lo -j ACCEPT

	# This line of the script tells iptables that if we are already authenticated, then to ACCEPT
	# further traffic from that IP address. No need to recheck every packet if we are sure they
	# aren't a bad guy.

	/sbin/iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

	# The following 2 line are a very simple iptables access throttle technique. We assume anyone
	# who visits the local website on port 80 will behave, but if they are accessing the site too
	# often, then they might be a bad guy or a bot. So, these rules enforce that any IP address
	# that accesses the site in a 60 second period can't get more then 15 clicks complete. If the
	# bad guy submits a 16th page view in a 60 second period, the request is simply dropped and
	# and ignored. It's not super advanced but it's one extra layer of security to keep this
	# device stable and secure.

	/sbin/iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --set
	/sbin/iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP

	# If the script has 'IsSSH' set to 'Y', then let's open up port 22 for any IP address. But if
	# the script has 'IsSSH' set to 'N', let's only open up port 22 for local LAN access. This means
	# you have to be physically connected (or via Wifi) to SSH to this computer. It isn't perfectly
	# secure, but it removes the possibility for an SSH attack from a public IP address. If you
	# wanted to completely remove the possibility of an SSH attack and will only ever work on this
	# computer with your own physically attached KVM (keyboard, video & mouse), then you can comment
	# the following 6 lines. Be careful, if you don't understand what you are doing here, you might
	# lock yourself from being able to access this computer. If so, just go through the build
	# process again and start over.

	if [ \"\$IsSSH\" = \"Y\" ]; then
		/sbin/iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	else
		/sbin/iptables -A INPUT -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT
		/sbin/iptables -A INPUT -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT
	fi

	# Becuase the Block Explorer or Block Crawler are available via port 80 (standard website port)
	# we must open up port 80 for that traffic.

	/sbin/iptables -A INPUT -p tcp --dport 80 -j ACCEPT

	# This Lynx node listens for other Lynx nodes on port 22566, so we need to open that port. The
	# whole Lynx network listens on that port so we always want to make sure this port is available.

	/sbin/iptables -A INPUT -p tcp --dport 22566 -j ACCEPT

	# We add this last line to drop any other traffic that comes to this computer that doesn't
	# comply with the earlier rules. If previous iptables rules don't match, then drop'em!

	/sbin/iptables -A INPUT -j DROP

	#
	#trumpisamoron
	#" > /root/firewall.sh

	print_success "Firewall rules are set in /root/firewall.sh"

	chmod 700 /root/firewall.sh
	print_success "File permissions on /root/firewall.sh were reset."

}

set_miner () {

	rm -rf /root/miner.sh

	echo "

	#!/bin/bash

	IsMiner=$enable_mining

	if [ \"\$IsMiner\" = \"Y\" ]; then
		if ! pgrep -x \"cpuminer\" > /dev/null; then

			# Randomly select a pool number from 1-6.
			# Random selection occurs after each reboot, when this script is run.
			# Add or remove pools to customize.
			# Be sure to increase the number 6 to the new total.

			minernmb=\"\$(shuf -i 1-6 -n1)\"

			case \"\$minernmb\" in
				1) pool=\"/root/cpuminer/cpuminer -o stratum+tcp://eu.multipool.us:3348 -u benjamin.seednode -p x -R 15 -B -S\" ;;
				2) pool=\"/root/cpuminer/cpuminer -o stratum+tcp://us.multipool.us:3348 -u benjamin.seednode -p x -R 15 -B -S\" ;;
				3) pool=\"/root/cpuminer/cpuminer -o http://127.0.0.1:9332 -u $rrpcuser -p $rrpcpassword --coinbase-addr=KShRcznENXJt61PWAEFYPQRBDSPdWmckmg -R 15 -B -S\" ;;
				4) pool=\"/root/cpuminer/cpuminer -o http://127.0.0.1:9332 -u $rrpcuser -p $rrpcpassword --coinbase-addr=KShRcznENXJt61PWAEFYPQRBDSPdWmckmg -R 15 -B -S\" ;;
				5) pool=\"/root/cpuminer/cpuminer -o http://127.0.0.1:9332 -u $rrpcuser -p $rrpcpassword --coinbase-addr=KShRcznENXJt61PWAEFYPQRBDSPdWmckmg -R 15 -B -S\" ;;
				6) pool=\"/root/cpuminer/cpuminer -o http://127.0.0.1:9332 -u $rrpcuser -p $rrpcpassword --coinbase-addr=KShRcznENXJt61PWAEFYPQRBDSPdWmckmg -R 15 -B -S\" ;;
			esac

			\$pool
		fi

	fi

	if [ \"\$IsMiner\" = \"Y\" ]; then
		if ! pgrep -x \"cpulimit\" > /dev/null; then
			cpulimit -e cpuminer -l 10 -b
		fi
	fi

	#
	#trumpisamoron
	#" > /root/miner.sh

	print_success "File /root/miner.sh was created."

	chmod 700 /root/miner.sh
	print_success "File permissions on /root/miner.sh were reset."

}

secure_iptables () {

	iptables -F
	iptables -I INPUT 1 -i lo -j ACCEPT
	iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	iptables -A INPUT -j DROP

}

config_fail2ban () {
	#
	# Configure fail2ban defaults function
	#

	#
	# The default ban time for abusers on port 22 (SSH) is 10 minutes. Lets make this a full 24 hours
	# that we will ban the IP address of the attacker. This is the tuning of the fail2ban jail that
	# was documented earlier in this file. The number 86400 is the number of seconds in a 24 hour term.
	# Set the bantime for lynxd on port 22566 banned regex matches to 24 hours as well.

	echo "

	[sshd]
	enabled = true
	bantime = 86400


	[lynxd]
	enabled = false
	bantime = 86400

	" > /etc/fail2ban/jail.d/defaults-debian.conf

	#
	#
	# Configure the fail2ban jail for lynxd and set the frequency to 20 min and 3 polls.

	echo "

	#
	# SSH
	#

	[sshd]
	port		= ssh
	logpath		= %(sshd_log)s

	#
	# LYNX
	#

	[lynxd]
	port		= 22566
	logpath		= /root/.lynx/debug.log
	findtime	= 1200
	maxretry	= 3

	" > /etc/fail2ban/jail.local

	# Define the regex pattern for lynxd failed connections

	echo "

	#
	# Fail2Ban lynxd regex filter for at attempted exploit or inappropriate connection
	#
	# The regex matches banned and dropped connections
	# Processes the following logfile /root/.lynx/debug.log
	#

	[INCLUDES]

	# Read common prefixes. If any customizations available -- read them from
	# common.local
	before = common.conf

	[Definition]

	#_daemon = lynxd

	failregex = ^.* connection from <HOST>.*dropped \(banned\)$

	ignoreregex =

	# Author: The Lynx Core Development Team

	" > /etc/fail2ban/filter.d/lynxd.conf

	#
	#
	# With the extra jails added for monitoring lynxd, we need to touch the debug.log file for fail2ban to start without error.
	mkdir /root/.lynx/
	chmod 755 /root/.lynx/
	touch /root/.lynx/debug.log

	service fail2ban start

}

set_crontab () {
	
	# In the event that any other crontabs exist, let's purge them all.
	crontab -r

	crontab -l | { cat; echo "*/15 * * * *		/root/poll.sh"; } | crontab -
	print_success "A crontab for the '/root/poll.sh' has been set up. It will run every 15 minutes."

	crontab -l | { cat; echo "@reboot			/root/firewall.sh"; } | crontab -
	print_success "A crontab for the '/root/firewall.sh' has been set up. It will run on boot."

	crontab -l | { cat; echo "*/60 * * * *		/root/firewall.sh"; } | crontab -
	print_success "A crontab for the '/root/firewall.sh' has been set up. It will reset every hour."

	crontab -l | { cat; echo "*/5 * * * *		cd /root/lynx/src/ && ./lynxd"; } | crontab -
	print_success "A crontab for '/root/lynx/src/lynxd' has been set up. It will start automatically every 2 minutes."

	crontab -l | { cat; echo "*/10 * * * *		/root/miner.sh"; } | crontab -
	print_success "A crontab for the '/root/miner.sh' has been set up. It will execute every 15 minutes."

	# We found that after a few weeks, the debug log would grow rather large. It's now really needed
	# after a certain size, so let's truncate that log down to a reasonable size every 7 days.

	crontab -l | { cat; echo "0 0 */7 * *		truncate -s 1000 /root/.lynx/debug.log"; } | crontab -
	print_success "A crontab to truncate the Lynx debug log has been set up. It will execute every 7 days."

	# Evey 15 days we will reboot the device. This is for a few reasons. Since the device is often
	# not actively managed by it's owner, we can't assume it is always running perfectly so an
	# occasional reboot won't cause harm. It also forces the miner script to select a new pool so
	# this kickstarts a bit of entropy in the pool selection AND ultimately the address to use for
	# solo mining. This crontab means to reboot EVERY 15 days, NOT on the 15th day of the month. An
	# important distinction.

	crontab -l | { cat; echo "0 0 */15 * *		/sbin/shutdown -r now"; } | crontab -
	print_success "A crontab for the server has been set up. It will reboot automatically every 15 days."

	if [ "$blockchainViewer" = "E" ]; then
		crontab -l | { cat; echo "*/2 * * * *		cd /root/LynxExplorer && scripts/check_server_status.sh"; } | crontab -
		crontab -l | { cat; echo "*/3 * * * *		cd /root/LynxExplorer && /usr/bin/nodejs scripts/sync.js index update >> /tmp/explorer.sync 2>&1"; } | crontab -
		crontab -l | { cat; echo "*/4 * * * *		cd /root/LynxExplorer && /usr/bin/nodejs scripts/sync.js market > /dev/null 2>&1"; } | crontab -
		crontab -l | { cat; echo "*/10 * * * *		cd /root/LynxExplorer && /usr/bin/nodejs scripts/peers.js > /dev/null 2>&1"; } | crontab -
		print_success "A crontab for Iquidus Explorer has been set up."
	fi

}

restart () {

	print_success "This Lynx node is built. A reboot and autostart will occur 20 seconds."

	if [ "$OS" = "raspbian" ]; then

		print_success "Please change the default password for the 'pi' user after reboot!"
		sleep 30

	else

		print_success "Please change the default password for the '$ssuser' user after reboot!"
		sleep 30

	fi

	# We now write this empty file to the /boot dir. This file will persist after reboot so if
	# this script were to run again, it would abort because it would know it already ran sometime
	# in the past. This is another way to prevent a loop if something bad happens during the install
	# process. At least it will fail and the machine won't be looping a reboot/install over and 
	# over. This helps if we have ot debug a problem in the future.

	touch /boot/lynxci

	# Now we truly reboot the OS.

	reboot

}

# First thing, we check to see if this script already ran in the past. If the file "/boot/lynxci"
# exists, we know it did. So we assume all went well, remove the build instructions in 
# "/root/getstarted.sh" and then the script is done running. 

if [ -f /boot/lynxci ]; then

	print_error "Previous LynxCI detected. Install aborted."
	rm -Rf /root/getstarted.sh

# Since the file "/boot/lynxci", was NOT found, we know this is the first time this script has run
# so we let it do it's thing.

else

	print_error "Starting installation of LynxCI. This will be a cpu and memory intensive process that will last hours, depending on your hardware."

	detect_os
	detect_vps
	compile_query
	update_os
	set_network
	set_wifi
	set_accounts
	install_extras
	install_miniupnpc
	install_lynx
	install_blockcrawler
	install_mongo
	install_iquidusExplorer
	install_cpuminer
	set_firewall
	set_miner
	secure_iptables
	config_fail2ban
	set_crontab
	restart

fi