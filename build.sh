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

compile_query () {

	if [ "$OS" != "ubuntu" ]; then

		#
		# Set the query timeout value (in seconds)
		#
		time_out=30
		query1="Install the latest stable Lynx release? (faster build time) (Y/n):"
		query2="Do you want ssh access enabled (more secure)? (y/N):" 
		query3="Do you want to sync with the bootstrap file (less network intensive)? (Y/n):" 
		query4="Do you want the miners to run (supports the Lynx network)? (Y/n):"

		#
		# Get all the user inputs
		#
		read -t $time_out -p "$query1 " ans1
		read -t $time_out -p "$query2 " ans2
		read -t $time_out -p "$query3 " ans3
		read -t $time_out -p "$query4 " ans4

		#
		# Set the compile lynx flag 
		#
		if [[ -z "$ans1" ]]; then
			compile_lynx=N
		elif [[ "$ans1" == "n" ]]; then
			compile_lynx=Y
		else
			compile_lynx=N
		fi

		#
		# Set the ssh enabled flag
		#
		case "$ans2" in
		         y) enable_ssh=Y ;;
		         n) enable_ssh=N ;;
		         *) enable_ssh=N ;;
		esac

		#
		# Set the latest bootstrap flag
		#
		case "$ans3" in
		         y) latest_bs=Y ;;
		         n) latest_bs=N ;;
		         *) latest_bs=Y ;;
		esac

		#
		# Set the mining enabled flag
		#
		case "$ans4" in
		         y) enable_mining=Y ;;
		         n) enable_mining=N ;;
		         *) enable_mining=Y ;;
		esac

	else

		# Becuase 'ubuntu' doesn't play well with our query, we go with the defaults.
		compile_lynx=Y 
		enable_ssh=N
		latest_bs=Y
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
		truncate -s 0 /etc/motd && cat /tmp/LynxNodeBuilder/logo.txt >> /etc/motd

		# 'raspbian' would evaluate here.
		print_success "Raspian was detected. You are using a Raspberry Pi. We love you."
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

	echo $ipaddr $fqdn $hhostname >> /etc/hosts
	print_success "The IP address of this machine is $ipaddr."

}

set_accounts () {

	sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
	print_success "Direct login via the root account has been disabled. You must log in as a user."

	ssuser="lynx"
	print_warning "The user account '$ssuser' was created."

	sspassword="lynx"
	print_warning "The default password is '$sspassword'. Be sure to change after this build is complete."

	adduser $ssuser --disabled-password --gecos "" && \
	echo "$ssuser:$sspassword" | chpasswd

	adduser $ssuser sudo
	print_success "The new user '$ssuser', has sudo access."

}

install_blockcrawler () {

	apt-get install nginx php7.0-fpm php-curl -y
	print_success "Installing Nginx..."

	mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

	echo "
	server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www/html/BlockCrawler;
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
	print_success "Nginx is configured."

	cd /var/www/html/ && wget http://cdn.getlynx.io/BlockCrawler.tar.gz
	tar -xvf BlockCrawler.tar.gz
	chmod 744 -R /var/www/html/Blockcrawler/
	chown root:root -R /var/www/html/Blockcrawler/

	sed -i -e 's/'"127.0.0.1"'/'"$ipaddr"'/g' /var/www/html/Blockcrawler/bc_daemon.php
	sed -i -e 's/'"8332"'/'"9332"'/g' /var/www/html/Blockcrawler/bc_daemon.php
	sed -i -e 's/'"username"'/'"$rrpcuser"'/g' /var/www/html/Blockcrawler/bc_daemon.php
	sed -i -e 's/'"password"'/'"$rrpcpassword"'/g' /var/www/html/Blockcrawler/bc_daemon.php
	print_success "Block Crawler code is secured for this Lynxd node."

	systemctl restart nginx && systemctl enable nginx && systemctl restart php7.0-fpm
	print_success "Nginx is set to auto start on boot."

	iptables -I INPUT 3 -p tcp --dport 80 -j ACCEPT
	print_success "The Block Crawler can be browsed at http://$ipaddr/"

}

install_extras () {

	apt-get install cpulimit htop curl fail2ban -y
	print_success "The package 'curl' was installed as a dependency of the 'cpuminer-multi' package."
	print_success
	print_success "The package 'cpulimit' was installed to throttle the 'cpuminer-multi' package."
	print_success

	apt-get install automake autoconf pkg-config libcurl4-openssl-dev libjansson-dev libssl-dev libgmp-dev make g++ -y
	print_success "Extra optional packages for CPUminer were installed."
} 

install_lynx () {

	apt-get install git-core build-essential autoconf libtool libssl-dev libboost-all-dev libminiupnpc-dev libevent-dev libncurses5-dev pkg-config -y

	rrpcuser="$(shuf -i 200000000-299999999 -n 1)"
	print_warning "The lynxd RPC user account is '$rrpcuser'."
	rrpcpassword="$(shuf -i 300000000-399999999 -n 1)"
	print_warning "The lynxd RPC user account is '$rrpcpassword'."

	if [ "$compile_lynx" = "Y" ]; then

		print_success "Pulling the latest source of Lynx from Github."
		git clone https://github.com/doh9Xiet7weesh9va9th/lynx.git /root/lynx/
		cd /root/lynx/ && ./autogen.sh
		./configure --disable-wallet
		print_success "The latest state of Lynx is being compiled now."
		make

	else

		print_success "The latest stable release of Lynx is being installed now."

		wget http://cdn.getlynx.io/lynxd-1.0.deb
		dpkg -i lynxd-1.0.deb 

		if [ ! -d /root/lynx ]; then
   		   mkdir /root/lynx
		fi

		ln -s /usr/share/lynx-cli /root/lynx/lynx-cli
		ln -s /usr/share/lynx-tx /root/lynx/lynx-tx
		ln -s /usr/share/lynxd /root/lynx/lynxd

	fi

	mkdir -p /root/.lynx && cd /root/.lynx
	print_success "Created the '.lynx' directory."

	if [[ "$latest_bs" == "Y" ]]; then
		wget http://cdn.getlynx.io/bootstrap.tar.gz
		tar -xvf bootstrap.tar.gz bootstrap.dat
		print_success "The bootstrap.dat file was downloaded and will be used after reboot."
	else
		print_error "The bootstrap.dat file was not downloaded."
	fi

	echo "
	listen=1
	daemon=1
	rpcuser=$rrpcuser
	rpcpassword=$rrpcpassword
	rpcport=9332
	port=22566
	rpcbind=$ipaddr
	rpcallowip=$ipaddr
	listenonion=0
	" > /root/.lynx/lynx.conf
	print_success "Default '/root/.lynx/lynx.conf' file was created."

	chown -R root:root /root/.lynx/*

} 

install_cpuminer () {

	git clone https://github.com/tpruvot/cpuminer-multi.git /root/cpuminer
	print_success "Mining package was downloaded."
	cd /root/cpuminer
	./autogen.sh
	./configure --disable-assembly CFLAGS="-Ofast -march=native" --with-crypto --with-curl
	make
	print_success "CPUminer Multi was compiled."

}

set_rclocal () {

	echo "

#!/bin/sh -e

IsSSH=$enable_ssh
IsMiner=$enable_mining

if ! pgrep -x \"lynxd\" > /dev/null; then

	iptables -F
	iptables -I INPUT 1 -i lo -j ACCEPT
	iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --set
	iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP
	
	if [ \$IsSSH = \"Y\" ]; then
		iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	fi

	# iptables -A INPUT -p tcp --dport 9332 -j ACCEPT

	iptables -A INPUT -p tcp --dport 80 -j ACCEPT
	iptables -A INPUT -p tcp --dport 22566 -j ACCEPT
	iptables -A INPUT -j DROP

fi

if [ \$IsMiner = \"Y\" ]; then
	if pgrep -x \"lynxd\" > /dev/null; then
		if ! pgrep -x \"cpuminer\" > /dev/null; then

			minernmb=\"\$shuf -i 1-3 -n1\"

			case "\$minernmb" in
				1) pool=\" stratum+tcp://eu.multipool.us:3348 -u benjamin.seednode -p x -R 15 -B -S\" ;;
				2) pool=\" stratum+tcp://us.multipool.us:3348 -u benjamin.seednode -p x -R 15 -B -S\" ;;
				3) pool=\" stratum+tcp://stratum.803mine.com:3459 -u KShRcznENXJt61PWAEFYPQRBDSPdWmckmg -p x -R 15 -B -S\" ;;
				4) pool=\" XXXX\" ;;
			esac

			/root/cpuminer/cpuminer -o\$pool

		fi
	fi
fi

if [ \$IsMiner = \"Y\" ]; then
	if ! pgrep -x \"cpulimit\" > /dev/null; then
		cpulimit -e cpuminer -l 60 -b
	fi
fi

exit 0

#
#trumpisamoron
#

	" > /root/init.sh
	print_success "File /root/init.sh was created."

	chmod 700 /root/init.sh
	print_success "File permissions on /root/init.sh were reset."

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
	enabled = true
	bantime = 86400

	" > /etc/fail2ban/jail.d/defaults-debian.conf

	#
	#
	# Configure the fail2ban jail for lynxd and set the frequency to 20 min and 3 polls 

	echo "

	#
	# SSH
	#

	[sshd]
	port		= ssh
	logpath 	= %(sshd_log)s

	#
	# LYNX
	#

	[lynxd]
	port		= 22566
	logpath		= /root/.lynx/debug.log
	findtime 	= 1200
	maxretry 	= 3

	" > /etc/fail2ban/jail.local

	#
	#
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

	touch /root/.lynx/debug.log

	service fail2ban start

}
 
set_crontab () {

	crontab -l | { cat; echo "*/5 * * * *		cd /root/lynx/src/ && ./lynxd -daemon"; } | crontab -
	print_success "A crontab for '/root/lynx/src/lynxd' has been set up. It will start automatically every 5 minutes."

	crontab -l | { cat; echo "*/15 * * * *		/root/init.sh"; } | crontab -
	print_success "A crontab for the '/root/init.sh' has been set up. It will execute every 15 minutes."

	crontab -l | { cat; echo "0 0 */15 * *		reboot"; } | crontab -
	print_success "A crontab for the server has been set up. It will reboot automatically every 15 days."

}

restart () {

	print_success "This Lynx node is built. A reboot and autostart will occur 10 seconds."
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1

	reboot

}

detect_os
compile_query
update_os
set_network
set_accounts
install_extras
install_lynx
install_blockcrawler
install_cpuminer
set_rclocal
secure_iptables
config_fail2ban
set_crontab
restart
