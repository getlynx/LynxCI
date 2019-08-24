	#!/bin/bash
#
#
# wget -qO - https://getlynx.io/setup.sh | bash
#		OR to overide defaults...
# wget -qO - https://getlynx.io/setup.sh | bash -s "[mainnet|testnet]" "[master|0.16.3.9]"
#		OR ...
# wget -O - https://getlynx.io/install.sh | bash -s "[mainnet|testnet]" "[master|0.16.3.9]"
#
#
# The latest links for the boostrap files used by both environments.
#
mainnetBootstrap="https://github.com/getlynx/LynxBootstrap/releases/download/v2.0-mainnet/bootstrap.tar.gz" # 2b55dc14c562b862ab20aa8793666215cb6f56e63e73617f6764e442af275fb2
testnetBootstrap="https://github.com/getlynx/LynxBootstrap/releases/download/v1.0-testnet/bootstrap.tar.gz" # f0a3212f23a399de460a5dfa3d2d8fb207c3b1cbda17e5f10fa591bb97f0d35c
touchSSHInstallCompleteFile="/boot/ssh"
touchLynxCIInstallCompleteFile="/boot/lynxci"
#
# Many conditions in the script act on these params. They are needed to ensure
# the correct version is dynamically installed or compiled.
#
operatingSystem="$(cat /etc/os-release | grep 'PRETTY_NAME')"
systemArchitecture="$(dpkg --print-architecture)"
#
# Default to 0. If the value is 1, then we know the target device is a Pi.
#
isPi="0"
if [ "$(cat /proc/cpuinfo | grep 'Revision')" != "" ]; then
	isPi="1"
	echo "LynxCI: The target device is a Raspberry Pi."
fi
#
# A junk file is stored to dtermine if the script has already run. It's created
# at the end of this script, so if it's discovered, we know this script already
# ran.
#
if [ -f $touchLynxCIInstallCompleteFile ]; then
	echo "LynxCI: Previous LynxCI detected. An update will occur."
	exit
else
	echo "LynxCI: Thanks for starting the Lynx Cryptocurrency Installer (LynxCI)."
fi
#
# There are only two options allowed, mainnet or testnet. Mainnet is default. 
#
networkEnvironment="$1"
[ -z "$1" ] && networkEnvironment="mainnet"
if [ "$networkEnvironment" = "mainnet" -o "$networkEnvironment" = "testnet" ]; then
	echo "LynxCI: Supplied environment parameter ($networkEnvironment) accepted."
else 
	echo "LynxCI: Failed to meet required network environment param. The only two accepted values are 'mainnet' and 'testnet'."
	exit
fi
#
[ "$networkEnvironment" = "mainnet" ] && { port="22566"; echo "LynxCI: The mainnet port is 22566."; }
[ "$networkEnvironment" = "mainnet" ] && { rpcport="9332"; echo "LynxCI: The mainnet rpcport is 9332."; }
[ "$networkEnvironment" = "testnet" ] && { port="44566"; echo "LynxCI: The testnet port is 44566."; }
[ "$networkEnvironment" = "testnet" ] && { rpcport="19335"; echo "LynxCI: The testnet rpcport is 19335."; }
#
# There are only two options allowed, master or 0.16.3.9. 0.16.3.9 is default. 
#
projectBranch="$2"
[ -z "$2" ] && projectBranch="0.16.3.9"
if [ "$projectBranch" = "master" -o "$projectBranch" = "0.16.3.9" ]; then
	echo "LynxCI: Supplied branch parameter ($projectBranch) accepted."
else
	echo "LynxCI: Failed to meet required repository branch name param."
	exit
fi
#
# We can't support every OS and architecture but we will try to update the
# script to support more as time passes.
#
if [ "$systemArchitecture" = "amd64" ]; then
	echo "LynxCI: Architecture amd64 detected."
elif [ "$systemArchitecture" = "arm64" ]; then
	echo "LynxCI: Architecture arm64 detected."
elif [ "$isPi" = "1" ]; then
	echo "LynxCI: Architecture for Raspberry Pi detected."
else
	echo "LynxCI: Unsupporteed system architecture detected. Build script quit."
	exit 69;
fi
if [ "$operatingSystem" = "PRETTY_NAME=\"Ubuntu 19.04\"" ]; then
	echo "LynxCI: This script does not support Ubuntu 19.04. Build script quit."
	exit 73;
fi
if [ "$operatingSystem" = "PRETTY_NAME=\"Ubuntu 18.10\"" ]; then
	echo "LynxCI: This script does not support Ubuntu 18.10. Build script quit."
	exit 77;
fi
if [ "$operatingSystem" = "PRETTY_NAME=\"Ubuntu 18.04.2 LTS\"" ]; then
	echo "LynxCI: This script does not support Ubuntu 18.04 LTS. Build script quit."
	exit 81;
fi
if [ "$operatingSystem" = "PRETTY_NAME=\"Debian GNU/Linux 10 (buster)\"" ]; then
	echo "LynxCI: This script does not support Debian 10. Build script quit."
	exit 85;
fi
#
# By default, all installations that occur with this script will compile Lynx.
# Also if the script is set to build from master, it will compile.
#
installationMethod="compile"
if [ "$projectBranch" != "master" ]; then
	#
	# The idea here is to have at least one installer that can be used to build a
	# Lynx node very quickly. The current installer supports only Debian 9. If any
	# other target OS is detected, then the script will compile from source.
	#
	if [ "$operatingSystem" = "PRETTY_NAME=\"Debian GNU/Linux 9 (stretch)\"" -a "$systemArchitecture" = "amd64" ]; then
		installationMethod="install"
		installationSource="https://github.com/getlynx/Lynx/releases/download/v0.16.3.9/lynxd_0.16.3.9-2_amd64.deb"
		installationFile="${installationSource##*/}"
	fi
	if [ "$operatingSystem" = "PRETTY_NAME=\"Raspbian GNU/Linux 9 (stretch)\"" -a "$isPi" = "1" ]; then
		installationMethod="install"
		installationSource="https://github.com/getlynx/Lynx/releases/download/v0.16.3.9/lynxd_0.16.3.9-1_armhf.deb"
		installationFile="${installationSource##*/}"
	fi
fi
#
[ "$networkEnvironment" = "testnet" ] && installationMethod="compile" # Testnet build are always compiled then installed. No installer exists for testnet.
echo "LynxCI: Updating the installed package list."
#
# In case the install is taking place again, due to a failed previous install.
#
systemctl disable lynxd
systemctl stop lynxd
systemctl daemon-reload
#
apt-get update -y # Before we begin, we need to update the local repo. For now, the update is all we need and the device will still function properly.
apt-get remove -y apache2 pi-bluetooth postfix
#apt-get upgrade -y # Sometimes the upgrade generates an interactive prompt. This is best handled manually depending on the VPS vendor.
apt-get install -y apt-transport-https autoconf automake build-essential bzip2 ca-certificates curl fail2ban g++ gcc git git-core htop jq libboost-all-dev libcurl4-openssl-dev libevent-dev libgmp-dev libjansson-dev libminiupnpc-dev libncurses5-dev libssl-dev libtool libz-dev logrotate lsb-release make nano pkg-config software-properties-common sudo unzip
#apt-get install -y checkinstall
echo "LynxCI: Required system packages have been installed."
apt-get autoremove -y # Time for some cleanup work.
rpcuser="$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)" # Lets generate some RPC credentials for this node.
rpcpass="$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)" # Lets generate some RPC credentials for this node.
[ "$networkEnvironment" = "mainnet" -a "$isPi" = "1" ] && name="lynxpi$(shuf -i 200000000-999999999 -n 1)" # If the device is a Pi, the name is appended.
[ "$networkEnvironment" = "mainnet" -a "$isPi" = "0" ] && name="lynx$(shuf -i 200000000-999999999 -n 1)" # If the device is running mainnet then the node id starts with 2-9.
[ "$networkEnvironment" = "testnet" -a "$isPi" = "1" ] && name="lynxpi$(shuf -i 100000000-199999999 -n 1)" # If the device is a Pi, the name is appended.
[ "$networkEnvironment" = "testnet" -a "$isPi" = "0" ] && name="lynx$(shuf -i 100000000-199999999 -n 1)" # If the device is running testnet then the node id starts with 1.
[ "$isPi" = "1" ] && sed -i '/pi3-disable-bt/d' /boot/config.txt # Lets not assume that an entry already exists on the Pi, so purge any preexisting bluetooth variables.
[ "$isPi" = "1" ] && echo "dtoverlay=pi3-disable-bt" >> /boot/config.txt # Now, append the variable and value to the end of the file for the Pi.
#
# Only create the file if it doesn't already exist.
#
firewallCheck="/root/LynxCI/firewall.sh"
while [ ! -O $firewallCheck ]; do
	echo "#!/bin/bash
	#
	# Determines if port 22 will accept a connection from any IP address or a
	# restricted IP address. By default, the node is NOT restricted and will
	# accept a connection from ANY IP. This is good, it allows you to log into
	# the node easily for post build tuning. But after about a a week of
	# consistent lynxd process uptime, the node will automatically set this
	# param value to 'Y'. Be sure to set the
	#
	IsRestricted=\"N\"
	#
	# And what single IP will we use to allow SSH and Block Crawler traffic?
	#
	WhitelistIP=\"162.210.250.170\"
	#
	# If you want to use the built in Block Crawler, change this value to 'Y'.
	#
	IsBlockCrawlerEnabled=\"N\"
	#
	# Let's flush any existing iptables rules that might exist and start with a
	# clean slate. We should always allow loopback traffic. If we are already
	# authenticated, then ACCEPT further traffic from that IP address.
	#
	/sbin/iptables -F
	/sbin/iptables -I INPUT 1 -i lo -j ACCEPT
	/sbin/iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	#
	# If the Block Crawler is enabled, then open port 80, otherwise drop that
	# traffic.
	#
	if [ \"\$IsBlockCrawlerEnabled\" = \"Y\" ]; then
		/sbin/iptables -I INPUT 3 -p tcp -s \$WhitelistIP --dport 80 -j ACCEPT
	else
		/sbin/iptables -I INPUT 3 -p tcp --dport 80 -j DROP
	fi
	#
	# Always allow local LAN access.
	#
	/sbin/iptables -I INPUT 4 -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT
	/sbin/iptables -I INPUT 5 -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT
	#
	# This node listens for other Lynx nodes on port $port, so we need to open
	# that port. By default, the RPC port $rpcport is opened to the public.
	#
	/sbin/iptables -I INPUT 6 -p tcp --dport $port -j ACCEPT
	/sbin/iptables -I INPUT 7 -p tcp --dport $rpcport -j ACCEPT
	#
	# Secure access from your home/office IP. Customize as you like.
	# [VPN 10 N-West] This is NOT a backdoor into your LynxCI node for the Lynx
	# Developers. You still control the access credentials for your LynxCI node.
	# The only account available is the _lynx_ user account and you control the
	# password for it. The root user account is locked (don't trust us, verify
	# yourself). This firewall entry is for convenience of the Lynx dev team,
	# but also a convenient example of how you can customize the firewall for
	# your own direct access from you home or office IP. Save your change and be
	# sure to execute /root/firewall.sh when done.
	#
	if [ \"\$IsRestricted\" = \"Y\" ]; then
		/sbin/iptables -I INPUT 8 -p tcp -s \$WhitelistIP --dport 22 -j ACCEPT
	else
		/sbin/iptables -I INPUT 8 -p tcp --dport 22 -j ACCEPT
	fi
	#
	# We add this last line to drop any other traffic that comes to this computer.
	#
	/sbin/iptables -I INPUT 9 -j DROP
	#
	# Lets delete some install process leftovers if they still exists on the drive.
	#
	[ -f /root/.lynx/bootstrap.dat.old ] && /bin/rm -rf /root/.lynx/bootstrap.dat.old
	[ -f /root/*.deb ] && /bin/rm -rf /root/*.deb
	#
	if [ \"\$IsBlockCrawlerEnabled\" = \"Y\" ]; then
		cp --remove-destination /root/.lynx/lynx.conf /var/www/crawler.conf
		chmod 644 /var/www/crawler.conf
		sed -i '10,$ d' /var/www/crawler.conf
		systemctl enable php7.2-fpm
		systemctl start php7.2-fpm
		systemctl enable nginx
		systemctl start nginx
	fi
	#
	# Lock the firewall after 1 week of consistent lynxd process uptime.
	#
	[ \"\$(/usr/local/bin/lynx-cli uptime)\" -gt \"604900\" ] && /bin/sed -i 's/IsRestricted=N/IsRestricted=Y/' /root/LynxCI/firewall.sh
	#" > $firewallCheck
	sleep 1 && sed -i 's/^[\t]*//' $firewallCheck # Remove the pesky tabs inserted by the 'echo' outputs.
	#
	# Remove the lynx user from the sudo group, except if the host is a Pi. This is for security reasons.
	#
	if [ "$isPi" = "0" ]; then
		echo "/usr/sbin/deluser lynx sudo >/dev/null 2>&1" >> $firewallCheck;
	fi
	#
	# Need to make sure crontab can run the file.
	#
	sleep 1 && chmod 700 $firewallCheck
	#
	echo "LynxCI: The default iptables was created."
done
crontab -r # Purge and set the firewall crontab
crontab -l | { cat; echo "MAILTO=\"\""; } | crontab -
crontab -l | { cat; echo "@daily		/root/LynxCI/firewall.sh"; } | crontab - # Purge and set the firewall crontab
echo "LynxCI: Firewall is built and scheduled to run daily."
echo "$name" > /etc/hostname
[ "$isPi" = "1" ] && { sed -i '/gpu_mem/d' /boot/config.txt; echo "gpu_mem=16" >> /boot/config.txt; echo "LynxCI: Pi GPU memory was reduced to 16MB on reboot."; }
#
# We are using Nginx for run the built-in block crawler. Nginx is disabled on
# start by default. Since it's inefficient and isn't always used, seesm odd to
# turn it on by default.
#
echo "LynxCI: Preparing to install Nginx."
curl -ssL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg # To prep the install of Nginx, get the keys installed.
sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' # Add Nginx to the source list.
apt-get -y update && apt-get -y install nginx php7.2 php7.2-common php7.2-bcmath php7.2-cli php7.2-fpm php7.2-opcache php7.2-xml php7.2-curl php7.2-mbstring php7.2-zip # Install the needed Nginx packages.
echo "LynxCI: Nginx install is complete."
#
# To make the installation go a little faster and reduce Lynx network chatter,
# let's prep the install with the latest copy of the chain. On first start, the
# lynxd will index the bootstrap.dat fle and import it.
#
echo "LynxCI: Downloading the Lynx $networkEnvironment bootstrap file."
[ "$networkEnvironment" = "mainnet" ] && { bootstrapFile="/root/.lynx/bootstrap.dat"; }
[ "$networkEnvironment" = "testnet" ] && { bootstrapFile="/root/.lynx/testnet4/bootstrap.dat"; }
while [ ! -O $bootstrapFile ] ; do # Only create the file if it doesn't already exist.
	[ "$networkEnvironment" = "mainnet" ] && { mkdir -p /root/.lynx/; wget $mainnetBootstrap -O - | tar -xz -C /root/.lynx/; }
	[ "$networkEnvironment" = "testnet" ] && { mkdir -p /root/.lynx/testnet4/; wget $testnetBootstrap -O - | tar -xz -C /root/.lynx/testnet4/; }
	sleep 1
	chmod 600 $bootstrapFile
	sleep 1
	echo "LynxCI: Lynx $networkEnvironment bootstrap tarball is downloaded and decompressed."
done
#
# The listener is for data collection, but only on activated nodes. This is
# done via DNS. For almost all users this service is unused. 
#
listenerService="/etc/systemd/system/listener.service"
while [ ! -O $listenerService ] ; do # Only create the file if it doesn't already exist.
	echo "#!/bin/bash
	[Unit]
	Description=listener
	After=network.target
	[Service]
	Type=simple
	User=root
	Group=root
	WorkingDirectory=/root/LynxCI/installers
	ExecStart=/root/LynxCI/installers/listener.py
	Restart=always
	RestartSec=10
	[Install]
	WantedBy=multi-user.target" > $listenerService
	sleep 1 && sed -i 's/^[\t]*//' $listenerService # Remove the pesky tabs inserted by the 'echo' outputs.
	echo "LynxCI: Service 'listener' is installed."
done
#
# If lynxd daemon is found to not be running, this service resolves that. Only
# create the file if it doesn't already exist.
#
lynxService="/etc/systemd/system/lynxd.service"
while [ ! -O $lynxService ] ; do
	echo "#!/bin/bash
	[Unit]
	Description=lynxd
	After=network.target
	[Service]
	Type=simple
	User=root
	Group=root
	#WorkingDirectory=/root/lynx
	ExecStart=/root/lynx/src/lynxd -daemon=0
	ExecStop=/root/lynx/src/lynx-cli stop
	Restart=always
	RestartSec=10
	[Install]
	WantedBy=multi-user.target" > $lynxService
	sleep 1 && sed -i 's/^[\t]*//' $lynxService # Remove the pesky tabs inserted by the 'echo' outputs.
	echo "LynxCI: Service 'lynxd' is installed."
done
#
# On a Raspberry Pi, the default swap is 100MB. This is a little restrictive, so
# we are expanding it to a full 2GB of swap.
#
[ "$isPi" = "1" ] && { sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile; /etc/init.d/dphys-swapfile restart; } 
#
# We don't ever want a user to login directly to the root account, even if they
# know the correct password. So the root account is locked. Create the user
# account 'lynx' and skip the prompts for additional information. Set the
# default 'lynx' password as 'lynx'. Force the user to change the password after
# the first login. We don't always know the root password of the target device,
# be if a Pi, VPS or something else. Let's add the user to the sudo group so
# they can gain access to the root account with 'sudo su'. When the firewall
# resets automatically, the user will be removed from the sudo group, for
# security reasons so it's important that the user reset BOTH the lynx and root
# user account passwords.
#
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' /etc/ssh/sshd_config
adduser lynx --disabled-password --gecos ""
echo "lynx:lynx" | chpasswd
chage -d 0 lynx
adduser lynx sudo
echo "LynxCI: The user account 'lynx' was given sudo rights."
#
# If the target device is a Raspberry Pi, then let's assume the Pi account
# exists. Look for it and lock it if we find one. Otherwise skip this step if
# the Pi account is not found.
#
if [ "$isPi" = "1" ]; then
	usermod -L -e 1 pi
	echo "LynxCI: For security purposes, the 'pi' account was locked and is no longer accessible."
fi
#
#
#
rm -rf /etc/profile.d/portcheck.sh
rm -rf /etc/profile.d/logo.txt
cp -rf /root/LynxCI/logo.txt /etc/profile.d/logo.txt
echo "#!/bin/bash

# When the build script runs, we know the lynxd port, but we don't know if after the node is
# built. So we are hardcoding the value here, so it can be checked in the future.

echo \"\"
echo \"\"
echo \"\"

# This file really should not be downloaded over and over again. Instead, just copy the local
# file in root to a dir in /home/lynx/ for self indexing.

cat /etc/profile.d/logo.txt

echo \"
 | To set up wifi, edit the '/etc/wpa_supplicant/wpa_supplicant.conf' file.    |
 '-----------------------------------------------------------------------------'
 | For local tools to play and learn, type 'sudo lynx-cli help'.               |
 '-----------------------------------------------------------------------------'
 | For LYNX RPC credentials, type 'sudo nano /root/.lynx/lynx.conf'.           |
 '-----------------------------------------------------------------------------'\"

if [ \"\$(id -u)\" = \"0\" ]; then
if [ ! -z \"\$(lynx-cli getblockcount)\" ]; then

echo \" | The current block height on this LynxCI node is \$(lynx-cli getblockcount).                    |
 '-----------------------------------------------------------------------------'\"

echo \" | Local version is \$(lynx-cli -version).          |
 '-----------------------------------------------------------------------------'\"

fi
fi

echo \" | The unique identifier for this LynxCI node is $name.                |
 '-----------------------------------------------------------------------------'\"

port=\"$port\"

if [ \"\$port\" = \"44566\" ]; then

echo \" | This is a non-production 'testnet' environment of Lynx.                     |
 '-----------------------------------------------------------------------------'\"

fi

echo \" | Visit https://getlynx.io/ for more information.                             |
 '-----------------------------------------------------------------------------'\"

" > /etc/profile.d/portcheck.sh
chmod 755 /etc/profile.d/portcheck.sh
chmod 755 /etc/profile.d/logo.txt
chown root:root /etc/profile.d/portcheck.sh
chown root:root /etc/profile.d/logo.txt
#
#
#
rm -rf /etc/nginx/sites-enabled/default
rm -rf /etc/nginx/sites-available/default
echo "server {

	listen 80 default_server;
	listen [::]:80 default_server;
	server_name _;
	root /var/www/html;
	index index.php;

	location = /favicon.ico { access_log off; log_not_found off; }
	location = /robots.txt  { access_log off; log_not_found off; }

	location / {
		try_files \$uri \$uri/ =404;
	}
	# TEST ME - does this \$ need to be escaped?
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.2-fpm.sock;
	}

	location /tx {
		rewrite ^/tx/([^/]+)/?\$ /?txid=\$1;
	}

	location /height {
		rewrite ^/height/([^/]+)/?\$ /?height=\$1;
	}

	location /block {
		rewrite ^/block/([^/]+)/?\$ /?hash=\$1;
	}

	location /address {
		rewrite ^/address/([^/]+)/?\$ /?address=\$1;
	}

}" > /etc/nginx/sites-available/default
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/           # Manually creating the site profile link in Nginx.
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.2/fpm/php.ini  # Normal cgi pathinfo fix.
#
#
#
systemctl stop nginx && systemctl disable nginx && echo "LynxCI: Nginx service was gracefully stopped and also disabled on boot."
systemctl stop php7.2-fpm && systemctl disable php7.2-fpm && echo "LynxCI: PHP-FPM service was gracefully stopped and also disabled on boot."
echo "LynxCI: Nginx is installed, but it's disabled on boot."
#
# If the Block Crawler is already installed, we are purging those directories
# first. Then we clone the repo and set permissions. It's best to do this since
# the site profile hasn't been activated yet and Nginx is still disabled.
#
rm -rf /var/www/html/
git clone https://github.com/getlynx/LynxBlockCrawler.git /var/www/html/
chmod 755 -R /var/www/html/
chown www-data:www-data -R /var/www/html/
echo "LynxCI: Block Crawler is installed."
#
# If this is the first time the install script runs, let's prep Berkeley DB and
# the lynx target dir. Then we are compilging and installing Berkeley DB in
# advance.
#
if [ ! -f $touchLynxCIInstallCompleteFile -a "$installationMethod" = "compile" ]; then
	rm -rf /root/lynx/
	git clone -b "$projectBranch" https://github.com/getlynx/Lynx.git /root/lynx/
	rm -rf /root/lynx/db4 && mkdir -p /root/lynx/db4
	cd /root/lynx/ && wget http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz
	tar -xzf db-4.8.30.NC.tar.gz && cd db-4.8.30.NC/build_unix/
	../dist/configure --enable-cxx --disable-shared --with-pic --prefix=/root/lynx/db4
	make --quiet install
fi
#
# Regardless of whether this is the first time we are installing or doing a
# update, this will install from the DEB installer if we have it.
#
if [ "$installationMethod" = "install" ]; then
	while [ ! -O "/root/$installationFile" ] ; do
		echo "LynxCI: Downloading and installing the Lynx installer package for the target OS."
		wget -P /root $installationSource && dpkg -i /root/$installationFile
	done
fi
#
# Only create the file if it doesn't already exist.
#
lynxConfigurationFile="/root/.lynx/lynx.conf"
while [ ! -O $lynxConfigurationFile ] ; do
	echo "# The following RPC credentials are created at build time and are unique to this host. If you
	# like, you can change them, but you are encouraged to keep very complex strings for each. If an
	# attacker gains RPC access to this host they will steal your Lynx. Understanding that, the
	# wallet is disabled by default so the risk of loss is lowest with the default configuration.

	rpcuser=$rpcuser
	rpcpassword=$rpcpass
	rpcport=$rpcport

	# The following settings will allow a connection from ANY external host. The two entries
	# define that any IPv4 or IPv6 address will be allowed to connect. The default firewall settings
	# also allow the traffic because the RPC port is open by default. If you are setting up a remote
	# connection, all you will need is the above RPC credentials. No further network configuration
	# is needed. To secure the node from repeated connection attempts or to restrict connections to
	# your IP's only, change the following values as needed. The following example will work 
	# locally, on this machine. You can try this curl example from another computer, just change the
	# '$name' value to the IP of this node.

	rpcallowip=0.0.0.0/24
	rpcallowip=::/0

	# The debug log (/root/.lynx/debug.log) is capable of outputing a massive amount of data. If you
	# are chasing a bug, set the argument to 'debug=1'. It isn't recommended to leave that log level
	# intact though. The default state of this build is to output the BuiltinMiner info, so if you
	# don't want to see it, you can change the argument to 'debug=0'. We think the BuiltinMiner info
	# is fun though, but on a Pi, to reduce SD card writes, it might be most efficient to go with
	# the least amount of debug info, so change it to 'debug=0'.

	#debug=1
	debug=miner
	#debug=mempool
	#debug=rpc
	#debug=0

	# By default, wallet functions in LynxCI are disabled. This is for security reasons. If you
	# would like to enable your wallet functions, change the value from '1' to '0' in the
	# 'disablewallet' parameter. Then restart lynxd to enact the change. You can gracefully stop lynxd
	# witht he command '$ systemctl stop lynxd', and start again with '$ systemctl start lynxd'. Of
	# course, you can do the reverse action to disable wallet functions on this node. You can always
	# check to see if wallet functions are enabled with '$ lynx-cli help', looking for the
	# '== Wallet ==' section at the bottom of the help file.
	#
	# If you change this value to '0' and someone knows your RPC username and password, all your 
	# Lynx coins in this wallet will probably be stolen. The Lynx development team can not get your
	# stolen coins back. You are responsible for your coins. If the wallet is empty, it's not a
	# risk, but make sure you know what you are doing.

	disablewallet=1

	addnode=node01.getlynx.io # The following list of peers are maintained by the Lynx
	addnode=node02.getlynx.io # Core Development team for faster discovery on mainnet.
	addnode=node03.getlynx.io ##################
	addnode=node04.getlynx.io #################
	addnode=node05.getlynx.io ################
	addnode=node06.getlynx.io ###############
	addnode=node07.getlynx.io ##############
	addnode=node08.getlynx.io #############
	addnode=node09.getlynx.io ############
	addnode=node10.getlynx.io ###########
	addnode=node11.getlynx.io ##########
	addnode=node12.getlynx.io #########
	addnode=node13.getlynx.io ########
	addnode=node14.getlynx.io #######
	addnode=node15.getlynx.io ######
	addnode=node16.getlynx.io #####
	addnode=node17.getlynx.io ####
	addnode=node18.getlynx.io ###
	addnode=node19.getlynx.io ##
	addnode=node20.getlynx.io #
	addnode=test01.getlynx.io # The following list of peers are maintained by the Lynx
	addnode=test02.getlynx.io # Core Development team for faster discovery on testnet.
	addnode=test03.getlynx.io ########
	addnode=test04.getlynx.io #######
	addnode=test05.getlynx.io ######
	addnode=test06.getlynx.io #####
	addnode=test07.getlynx.io ####
	addnode=test08.getlynx.io ###
	addnode=test09.getlynx.io ##
	addnode=test10.getlynx.io #

	mineraddress=KG2ofEGEXA3muf4Nx6LErAUSspvDaNhke4 # The following addresses are known to pass the validation requirements for HPoW. If you would
	mineraddress=KNLxnxsqXf7qWp8ByUU4szkCfFcMsmaUog # like to earn your own mining rewards, you can add/edit/delete this list with your own
	mineraddress=KH5hqUZoCwcivm4ySd73cxh3sBLTzaxgX5 # addresses (more is better). You must have a balance of between 1,000 and 100,000,000 Lynx in
	mineraddress=KJmkvtZVs5qRwbC5AxyVkoNrBtAwo9frXY # each of the Lynx addresses in order to win the block reward. Alternatively, you can enable
	mineraddress=KMipCoG9WW2872f9PjtnSuKu3JeXj3Xcoy # wallet functions on this node (above), deposit Lynx to the local wallet (again, between 1,000
	mineraddress=KLHWyYdCFLkuYiKK1LXW4tAv3HuMaMBLrV # and 100,000,000 Lynx) and the miner will ignore the following miner address values.
	mineraddress=KLkcUUXgsXDpykt5yU1LBokkUu7ByLDsYS
	mineraddress=KTgeUCq4jRy3faYAiDarEoANAkKLdCzuJc
	mineraddress=KRf4wtXAjEWzGasZKcRQM8SAjJbBH3HH9s
	mineraddress=KPuBXnNffwPS2eQoCG75r9JyFgQhy5jy5o
	mineraddress=KPZ2WU5aStAsGkyDaNCDpnuwd9PNQd6pmp
	mineraddress=KRJf4FQB6GAk2E6dXeJ5osbd1GsHjW6mWf
	mineraddress=KDjfv9bUfyfFfuVgyhTazreESRfHpYnMi3
	mineraddress=KBywa5qcAZTB3CC7vCzxVeU8eYW6PBdSfJ
	mineraddress=KU7tLLoa1geou57GWoEY7MXUpQNetRbuNy
	mineraddress=K7XNmz2h2PgyGC8aYhXHJ8W58WnjZgrU85
	mineraddress=KT4nWz8PEAyAiBQTXu6T9z7TZCe5h2pUep
	mineraddress=KG5unFERmH6Qsvt3muci4ZeKgtmUaw7TdQ
	mineraddress=KSX55i4ef1y1kYtHu6E7EUt7Fx4GAg9yzm
	mineraddress=K8QGUNxc86Ahr9CSW1NyT2LGDC8BAUk6iM
	mineraddress=KRgVAxFgfjkYKovizRG1DfkLKd59rpEHxe
	mineraddress=KMoRtp69iMVVSWUPVwdota6HSCkP2yChFH
	mineraddress=KNcAXmZY9CKUesky2dRbKWJM5PZwQmUNYk
	mineraddress=KB1bRSQM2AnfmmotqdtL9SxBxEbxHeJBj1
	mineraddress=KJevkjENSeBzVp5MnSvyNqnemF9rn6unYo
	mineraddress=K8A1q6ztqgwMUgvDXtagyd7y7aDCxrGThz
	mineraddress=KVrG89hVRcFmcoPiuAV2d4GiKSuwpS4iG3
	mineraddress=KAWWaMxf89oQ2zk9XuNjUavuLyunczajpv
	mineraddress=KPUx5mXz8QzNKb9ZFtEBnFmkdz9p2NTCw7
	mineraddress=KNxgwt5DRNoj5YeKQjDFXSQpv4gX165GAz
	mineraddress=KEVs6Zitko4p2nRVnpWQmpBrUjY7BmnAdu
	mineraddress=KBFcw1sTb353j8mm7GmKhrCDg4B14GcsWk
	mineraddress=KToHC8eSeFAPgeLSsjxJEHEGZkYMw1g4Ui
	mineraddress=KAL6CXqYEf9ir1cD1MSrJxVkjdaAGuzekr
	mineraddress=KGrvzGaZ9K6T8ES1U7jaMBNGQb7xpvrDYR
	mineraddress=KSvwjHV3f5XdsjpnkCcWtdULXDS7P2fmJK
	mineraddress=KGDya5ywb6R7ngEnyKYe43eVA4wXeRpSqb
	mineraddress=K8RJg8Th8t7LB9QYwksKmKJ82TGaT6qF21
	mineraddress=KQHFp6C4egbM8ekxpVSAjU27XHrEVXuUtc
	mineraddress=KHQ1S8xjSKGYhy8JdQXUqmU5QfjNBFKQHt
	mineraddress=KHM4giaQz1tSjw2nB3qNagqXqygLJ5PgWv
	mineraddress=KQVgWNsE8RvoCusiEmHbvRVD1Pp494TCo3
	mineraddress=KD1mmbM39oJGRVXQ4zXqpMt3tyv7tYnSVN
	mineraddress=KKAYDA2XR9gJTsgDT4XNNqRdibqDVtN4YN
	mineraddress=KDjThi2BGU7YTXaUV2QXxtFNBV8Aj3bHMK
	mineraddress=KM6yeD6CgAmtt9NpPnvexYVnQR7GmN8XYs
	mineraddress=KTSSYdLUzKRAuebZoWWm6unLb6HYNa5k8z
	mineraddress=KD4HSV5aY3EMy4yyZHpM4CFqzNo78aVAd6
	mineraddress=KFyJ8omd9ekxtMd7x65XCaDN8a93d5NKZi
	mineraddress=KK5ywBJXMaA2H1UfnkX2VH4awg7HMAkAPk
	mineraddress=KR99fzAsCj5PybQEf4C4kRDtXz76AnH2Rt
	mineraddress=KKhbEqkJWJYAfi8PdJKR5yyoLEE5dcB876
	mineraddress=KDkeBiDtHiWApgTxCBXn4HPL4wibHNZmtC
	mineraddress=KTS8aLqMtcGMn7T34viR3bj9ZJ1zZGoGJG
	mineraddress=KMmLUaRXmtBbxTFC4HHVbM4HhFUJWET9oB
	mineraddress=KD6rYRkyevp34zKykNrK9gwBAEUbv2cNFV
	mineraddress=K89ccyMVZXzRzUXWq1RfuY9PCvUZDqgoik
	mineraddress=KSJvNWgrPSMFbCY94j3kNsAZg1FWhrm5t8
	mineraddress=KUtN69HpY5GUnkCrqnbAxf7mFWun8kQhq2
	mineraddress=KA2TYbdm4hWCk8DqUo2LAQqJTSm5mWAwzC
	mineraddress=K88VygQjnVfsMS16hCHkjfK7GkA42qqJjg
	mineraddress=KDKykmrGJiQUxiK2aE75xxo1krqUreuUAM
	mineraddress=KGyh6t7eoXnf7P3GGRF1enfxpAGcdYPt89
	mineraddress=KKgt23EhjwKLM2D1A42vgSpjcnnAPQgMvn
	mineraddress=KFno7q6cKU2V8t6Y3oDMsXrm1Qnh42X8dQ
	mineraddress=KQnReh3XBkr5ATyHi5NfX7x98jGqPUC56m
	mineraddress=KQ5dTLSpnrNgHJMbdmWFoTrVJJ7FHcPe4a
	mineraddress=KAHVEkbLMMjYbbGnSKp19G7b8KtAVQQVpn
	mineraddress=K8mEAGxz3S28iBKTJ1DkpamaA87vAYFa7w
	mineraddress=KSvTeEMK4LiQQ6XGHyzRyAcbbywtGfMwK7
	mineraddress=KKgcn8PbKeFNWMNUUdYgR4PhUGjEMA7YsZ
	mineraddress=KAjmGxrFjSS5FyNR6eeRGddzGQfpKtDBFm
	mineraddress=K8pRb6spT88mEPH7m4RPUpBJoVjTSywgxD
	mineraddress=KM6gViox4G9DxhGy45HfJSbJj5wpTZPyYa
	mineraddress=KGif3PDPHas53jWY4V8XFKEWJvW8LrkNSF
	mineraddress=KFjzxA9F7ShGE5KQRa199eqHc8ruBf582Q
	mineraddress=KM5XRg276NcSrJVyxqAKPsPgc77p4FGvwD
	mineraddress=KUdqcraqpJwtkxtzQ67adHhFoNNY7ShePU
	mineraddress=KUFmGQsv2mYt9Dfgh2wfo88NwsyThkTZPu
	mineraddress=KMNeHWHtUa54NKJ1WmGSNrb1Gw5FNBeZbV
	mineraddress=KEag3pWyuyNv3ykX8PJ4SLrVGU7wd4qUD9
	mineraddress=KL8bG3BfRwvbG68h7rSntohTowGfv7gRdF
	mineraddress=K8yUTWqqaHxrRbqRhYCTGytWZZH7kCmMDQ
	mineraddress=KEbvuZFQEhfsK7URgKqC5MiAwMHdyKSmeA
	mineraddress=KDR8kSTHY2fcQNgKNzmCrav5h3STnYYi5H
	mineraddress=K7rADXJTtKdUKAQSJJgA8mSseBorqh2Njd
	mineraddress=KRn36kX4JrMRBwC8c3mH1gA6P5o3hHedgW
	mineraddress=KCxZYLds8SsGRf77tpy9hfRsv72fuy4Fv3
	mineraddress=KUt129J5RHjBfSSEUh7bB4PgWo7HrKdSFa
	mineraddress=KVrUAE2c4nezo7LGyxV4nQxzTFUHExer6L
	mineraddress=KFWnE9kJCarSj665ptkR2RP8Emf2CeeBZL
	mineraddress=KS7pFonJdAjhw5XfNge3Z374S7tNbNmVbJ
	mineraddress=KW6iBcDBJR5FDHZbid1cGVLv9VKZUMLQ47
	mineraddress=KKTYH3fznPBcw6rGQmkmJ15ZoCHcjBU1r6
	mineraddress=KNvcKwbwtdjSzNJDG4KkfW3ND392yvqZ3T
	mineraddress=KFu97mQX5ayKD6pUYMEnLLwK9hdyLGtccG
	mineraddress=K9wn3Kd8GxubmVWfNqsf8yDvA6NiAhgftQ
	mineraddress=KENTd6NxSStcWrh2NC3Rtqq4GDcDSdsDUK
	mineraddress=KVBWFVzGMkVqZM1tjBgv7wu2rdHGP61uUc
	mineraddress=KSTjT3x3xKL8TUMKCMr9VEaSsYfXAtoJmo
	mineraddress=KCw1zJd2hFixtSpPCakmxwNhxkcDTw4iFh
	mineraddress=KRxuSE3Bpgv2RG5otdM7zrRwm2fusywPbt
	mineraddress=KQ4gZ16JTwWpAF8Fue54xqJ7JfFV3iBKih
	mineraddress=KEELjLwyhHv2fPJTEwfbLURoFrcGv4Ursx
	mineraddress=KE5qRzFFnYghujhtuSs1ccKartyr6Uu6GD
	mineraddress=KEsyQkFWGLA8fxjjogEuAfjgymwocpwWCU
	mineraddress=KPgoGJrYD8cNogTjo1ZLFhCzNkegCcekKM
	mineraddress=KChFEg95jkxevxaunGCdNrpQHJHpVgETUL
	mineraddress=KPVzCf733JLS5S81wwsfodgjQLPwP9nUew
	mineraddress=K7Gignm6JW4TJH1vnN21f9LA3gyzEVcBvS
	mineraddress=KT3KTvdZdcL58Zdj9tGMXQBJj18Vq2xxyT
	mineraddress=KTHp1ks6H19wAcMHi1Lbtsusva4eSmG433
	mineraddress=KM72k3AtL3U3TrcmepWDJVyqxbF2q2GX3B
	mineraddress=KB5itZ8EauWSDn7XcakUywj1Uq97Z3RNGC
	mineraddress=KDBCJbnGxGhaB4wok31N5JE41QZBPdx2BA
	mineraddress=KRfwHBL4A1nyMHjBLSbX5SLuVp6FgjBiWw
	mineraddress=KCrBjpQV5qioXVW7PpfbpbMjWCo88gyNi3
	mineraddress=KW2VEsTgSbSsv5DXpMupqoYKpLyoQrtcpm
	mineraddress=KG168WUnYeUExbTUJ8AjLH3T5xSYSnbqmq
	mineraddress=KGizkmStn2P86YR9hWKDSFyocGWJSdxHPc
	mineraddress=KM9Vb3mS3NbHkxSK9teL1pynPSHkY4NohS
	mineraddress=KFsgQqcCGMPPuC72QqUzrsFNLUhUozHLhJ
	mineraddress=KAFxBVH6hdZDxMAmyKdkygdKWSJmbBv4Xi
	mineraddress=K9Pu4mokyREUEnKNT7cwinTkjHPtrzxpyg
	mineraddress=K9XYJGQenr7pBfYS35NPEGtPC5JHePv213	
	mineraddress=K8bBNy1fsA4HKRk7pWqFUAogs37nrGzvxG
	mineraddress=KTgZLgbvGLAZdSkzM2oVhyDcWx3dKKpkrX
	mineraddress=KGt6qUHLcNN4eUYstoACc8UyMAdNm7muqW
	mineraddress=KEsTQLmSBTLkuUzMgiwPkV3h1k3JrRsety
	mineraddress=K9erq5SRXoP1GVGZUkvoBcP21E7XBUmUCC
	mineraddress=KEgf7H3yJUAcucAiXbKRYB3PdRRHCWWdFB
	mineraddress=KJeTy4YpEB4vfACi8hTDhha8XREkNwfCo5
	mineraddress=KVe8M69xcaciUx2stEYPXCvfEBouJPLVCa
	mineraddress=K7h1XerggVEGXLSMMxfmHPgL7FbHH2rq3V
	mineraddress=KPTaCQ42qSrMRFh8YVVf8cFLpU5tFbVE5M
	mineraddress=KQkcW2vQFqpYJ2WeP2mKRJFE9deRUoh6ZL
	mineraddress=KGsXZ9f2oPaw2ijN9d3hLqawDAT4Ymj83M
	mineraddress=KEnnvXuz63FBtSaf6ugHJ3KJ1vqYExJMvr
	mineraddress=KREsateb18vgKzPvfqCkXetKdTEdhCZpQL
	mineraddress=KQf9V3AMF8hjYaxNEwxR7vfgDERLajWm56
	mineraddress=KAMx31Z7SjW3gZmtGA1Rma5WHv7ZVkZrdu
	mineraddress=KA33R8toK25omLrg4TJ4qE5YZQZH9w7icv
	mineraddress=KNuWFu2oj9q15C3y2NhjAufdFLhpiyHR7W
	mineraddress=KBxpSv3tDPEq2NdiayWu6mLKaJCLR3bESu
	mineraddress=KM1VcC7ppY7fmHD8BGoyoyLeR9bTiuQXsY
	mineraddress=KVm5auwacM2BRKmtftgPu4wqQyiG56Gsmx
	mineraddress=KQwEGMTE8hxubAxwih3U7oykW186y8eijX
	mineraddress=KUXn3vFAZhYe2jjpQFVDUTuEbS5WhhR4f1
	mineraddress=K8rYuPyAQ7jzKHYNyFeMQpu7fFFbw5pjZR
	mineraddress=KEhEeLfxffCXA7aLj45W7zpVPdMncytZQ9
	mineraddress=KCSzsxDA48uMf4ULofJu2RZuR12X9erHpi
	mineraddress=K9MwMzSGVbhR2ewjA6s4r558BccToogeSM
	mineraddress=KUH3G3oPUVK3vs6LLVygB1eXreewcSAcgf
	mineraddress=KDekJvk6M9nmN4VX69nYPP6DDrdWimQ5MA
	mineraddress=KWQYg24werdqs6SYeYv5V4Pm169kSQopar
	mineraddress=KTuEfaeefRiK8ANRErd4oEMX1hZ61KrZdr
	mineraddress=KPfLtLwwvu5c2Fb3WyUGVqrsy63joMYmi1
	mineraddress=KSt8zsD7gGnkBi3VfauVf7zcio3wnmes44
	mineraddress=KGYU9FjX8M4MqheuQHPjQBh5R35iJW4bGU
	mineraddress=KAZBiAoL3oqdcMudR9pYtaVkq7Gx7g6F3E
	mineraddress=K8A1q6ztqgwMUgvDXtagyd7y7aDCxrGThz
	mineraddress=KVrG89hVRcFmcoPiuAV2d4GiKSuwpS4iG3
	mineraddress=KBp7DvcmhonVqy3Es73dQFTtjCPGrNkPDk
	mineraddress=KKuxb5KQCF13D7kDL6rMPx5hNTtDGvqiTV
	mineraddress=KC4GBFAbsgRGvdrY9aQgU4XNX85mAFmHHU
	mineraddress=KGC3UkcLS2Yq5ZojhuHu5T7XBpf3DJKJKp
	mineraddress=KEM9dV7pP1YZkTA3gYpfydSqQUyFzfmwrm
	mineraddress=K9JgSJZW6koYKQ4rPmZ7FwRH6dpy7SHVUD
	mineraddress=KS9n6R6K9BsNn3Mz3P2QxpNNdPJhDPvLnB
	mineraddress=KSK7RkAez3h4myywCiBWANdqsYrRtzdRrb
	mineraddress=KEUNaT5m2Qi1kiDBwTG5rVgJQtaRzYpYhD
	mineraddress=KEAgADFYmy5tVggXx8kcHBD1WiLcEnQvXs
	mineraddress=KK2ZLgKFuv8k8ZtohjHbXTBXutsSoieVfN
	mineraddress=KCeHBX64PT1WvuV4mrSnS7DoyLvpmZ5XXK
	mineraddress=KCEtXtUd3H8bG7Jn7FCLuEhNdVvD5AbDVf
	mineraddress=K9aVTZzPRwuVD7k3oELGh2aDKcF95kjEN1
	mineraddress=KAaaYX5rXaSJstmszDEJgxAYjx655CctoE
	mineraddress=KQVjEoCtKfB2KRQCrpL91NxokdmosJAWSH
	mineraddress=mvAqk6Q9ABF91TaAKsDhauym1MNuaj6ZzL # Private key: cUYQ4bvyzUy2gAzSf79hUPqEasuziKYzSpRaifAXM2zb5Y6X5gQD
	mineraddress=mzKEf2fzK5WYTUM3ZffQQKtGXbuBSyQbXL # Private key: cUNsqZjzywvZPLcUvso8d1FixiJZc7aX1iLfEB9BHqVxRGdz7tuz
	mineraddress=mo5Nvd6GJHN696NJ1NmXj4b6RHoig1NEV9 # Private key: cMppJ2yBU918qiwYo9aEhgqKiDK45TLSoEid8s7XBdajE8ZrZwmS
	mineraddress=mh6KV4wKbm5pmG6Y6LTT1A9DeXziUafsP4 # Private key: cVGvDcvdm6gmRDqR5BQwbhdcj6eNMLJNkjwaKEq3YNkj9sv5Q3Lr
	mineraddress=mgX7cXxob5DNAJgu1UrpAgLGfa4FnfSCVj # Private key: cTGFEfAbu7Q8fr7hvkWWzRxPANWT76quFCazris5V7ojkQggUCTp
	mineraddress=mgriF5mgsuyvnh3f9QNwFHR9qDwgYfEjZP # Private key: cNuUkW32HkYqenNV5FV51PRKejCPYK3PZ2YpkqndaMDvJEpwTZ2G
	mineraddress=n3wKyoCcpcE4x8oo3hvJU1drgi7QTVEcrf # Private key: cW8Nt4N7QcK1K1g6igrYRR4QBzagujFSNJ7dDcMpUkGWEyaGTJL8
	mineraddress=myJwCi7nBLv5wUyXz3ZFq15hnGVtHa7tun # Private key: cU8wXQWXbAbfrhGSM6raX2wWhxisHC5oiwWQyzr2mRdKvzdKQ643
	mineraddress=n1j2L3tncm8Prc3oQmtgKKjERUEr1x3uDK # Private key: cR97VSALAiZPLL9GwcQajP45crGajfxrcPyucZgnrvPZD4Zfu5UP
	mineraddress=mhuwHPSWKBaHSaWMjuU7m5TbzG3j75amTw # Private key: cTKf8NYhWksuWsHmNxfcHUN2TCkv6YNkk8ekpAGyqhLvtuV6Kfmc
	mineraddress=mtp2CyLf7kBfBjEfBjnsdt3x6kv7CWkWTe # Private key: cQD2PkGkjrCGywyMU5331xxvHbNWgcvByK4X8gU1bST5dMfGzpaB
	mineraddress=mmQxpEVVp7bBXfkF2dVkGCWxaX5dxt2vR5 # Private key: cRMyr2RHhbF1FKARiwoDWBh8pQLC2KrRRRSLztLioT97XU1cegYA
	mineraddress=mgDHQbZHUU2YCx3wpF6gjvND7UPSmYUEgc # Private key: cVB7cPJiWUCP72J39EZjJ6k1T4FSH5u8LrMKfk5YqyrbxiZwChcb
	mineraddress=mfmXw6tnWuMPPAPEqFeakodw3nwJoyYw71 # Private key: cN9JnwhNDiTY1f3UaY5F7jeiEfnv3tWCVBp6GfZq43HnT2NH5R7e
	mineraddress=mhuP1zXXsBb5AbGgX5H4veTYM8RgkpshJv # Private key: cVXzDVfw4mW3tVWepek35ENXNnp1X6NiNgnm2pJpvQA3tPY3pwiL
	mineraddress=mnRyuThfF2YF4kbtVXWFXgX9knhfFQzBoB # Private key: cQBVDLHgSyxbvxWApQXHDTaLwApsNx4NLCofWGjSrFCPq96Qyfec
	mineraddress=mmfspxuCpe5getSthHFrorK4YJE9MoxHFE # Private key: cVwrj2tnSLLaMvF2r5UPtq53DnXkhPmZhjUn8yXZX3WyNv9Z3Z5p
	mineraddress=n4CkrFFcYSRtazYSw1MYJ1dYUQSN2jpe3P # Private key: cSNJbVb2LdspWQVWB6H1VpMwHLDv7DzWx7bfb9uQPAWnXD712tCH
	mineraddress=mphs8iML38DhsbB1qx4D8kxLgQvjYubKvc # Private key: cQSzmvtszC8hratBG1Wdyv2QUd9xXPALEkpqU7g7xu66YAcr1QQD
	mineraddress=mindpMbbrNEE6Ap15G7PSAQaJsaFsydvEt # Private key: cVXHFRAw8qEYvxzU4trU8tWWqVo93E2T287mJou6nUhbHBB1C28k
	mineraddress=mkUh7tjREvdL9zK9SeLs4mVhhTLcffk82k # Private key: cW3otbFXUy7dCwGsA1wsM2yTnJsEo4djXDFXiVab6Tk2Zv4dxfMX
	mineraddress=msfDHvn2L5TSqFZYCq3EerxzHtbFZ4cBpE # Private key: cSRMwRnrtXjee1SewUNuwD468WfP8kUvj8iruerRpnBQNzoynS4f
	mineraddress=miMWN96feXFA4a4fktA68xscZPeXBqvHsc # Private key: cR8ZQpFF9yq2BXRCN7xxL3EYYsGczS51tpRBkvFNjRdPe3d1jWuk
	mineraddress=mvrMeLhELTCaXkmo7r8XccEMGa6ppKqiUb # Private key: cU1farVJJ56mYv8RJzVuwqFuFPwPwKSMtpstaujBYrBDWNisJ62u
	mineraddress=mu3fpDNWjCTMaAGtnoJVKpwbZtoRkasphJ # Private key: cScYkvYV8m9Xbr8nYpb6F4n6D15HLzVTR9ZUeKazk9oW4NoJpism
	mineraddress=ms6W9vmqT5NDw6vdmT31yLEo7TwCm3cgVh # Private key: cNzX2wv65SxE5c1VeRc7FYAxXY6qnwgsyv3fcMZvwiGkdhKeDNTX
	mineraddress=mxJC8oiLbsSRhmSCgcBWpahC2eyZU1W7qs # Private key: cSf99ZpsiQNP2WMm5zo6WefBnRX1V1Kxaguco3jsdx3U1kzLgqXi
	mineraddress=mpniFaj9a8L6332TpjoWArcso5cTRFgJHd # Private key: cN3LdHXGZy2ANNP221Tbm7uoG7AGBgvz6doPuERVsg6W5DwxZZ6p
	mineraddress=mydYEwnf6s2BRWLVA7dYPmVLvK2PcdTkDt # Private key: cScdbYMYAD8zYFfX9VxVbmkg61oDV64vUTxAL9zvSGLpRwduVWmC
	mineraddress=mhZtewGZTJw2ewWHufFa7ZCkrz4jeWVmD9 # Private key: cQQNxD6CZ8CrinW4Eq3wrXuCuX6Ccaws6LTDD1c64YXYngyyp86f
	mineraddress=mqVPvnrkCvSkKnR3KPeVk3LcnWf6rvRAPe # Private key: cMyyArq6kzXBb4L9jKWLkANqfaMmchjobyMGdYANdu935Hv7RBMu
	mineraddress=mvfi4LZxMDdPzT9PnDuxyKsK63a1ybSZUf # Private key: cRyYu5mHXrDzGqQpbeW2ksTPJcwdodqJyej3KsqxFvFQhsqCQTHx
	mineraddress=muzoQBrL1T4tyCALtsapWJY76ertjZhuow # Private key: cVMinxvyGjv943184JcNbY1zzjkuTScLYfm6k4QG2f4wVeArN4HT
	mineraddress=mjucNa4ZS5QD5TD8WzZv7CHze3wLLneK84 # Private key: cTMdGYJ8Wm8f8cfhAxSERecTt8wj4KcNvqk88G9uihmufyZaiVRR
	mineraddress=mg4oSdwnD2MNJ4JW5a2qYWrk7FHQUypHJf # Private key: cV1YnJrcM8gUg2g81HMgbZXCLdPUBSyWK3ZQXpsmNpiZo5DeJLT5
	mineraddress=mqkMYkskQ7DiFf57FmfvWJoiSNUG5uBfUJ # Private key: cURgVN4gUfBHVd9eFsnqWyqRWJrQep6SRg8AsBjv9F8mUUgNLNQL
	mineraddress=mgMs2dY1Tx1wYJTEsUhJwja9n8xcyoNUbv # Private key: cTLxyQq95fPWV7q3NpAg25nCcuo9acmg25PK9Cc6WDHcfbqrj9mU
	mineraddress=mv4m5GWongwdX43sjN9HTQwcpuPq9gfmKM # Private key: cQVCzmtp9qF4aQChoJkjrsVZn1bM4NgPezQeQLP1PQ3FQt8JxjW8
	mineraddress=mqwyDHhvDb3nNWYdRrT7JJxK3uf2ciMWyy # Private key: cT6TKiBpwWC191damceRu31NjyqA9KhVUSBEPZtjRkN6ntDbCqoK
	mineraddress=mtfxpRruFQxC958vScDrW34WnAao7g45Nc # Private key: cNefKgDW18N3aeondGVaRMEjfEyZvzejFAD7KCnthECMtSeNtZb9
	mineraddress=mj84VsKaDCf1bXJkSVLNoM68mMPzg59dQW # Private key: cRXzXq3on3gKmZgGcftbj7JZeGSfpjR38abdgKBi1hyiucsKaXVs
	mineraddress=mhUhvRLRmbFvsBsA2Eo7r2wa779YoxRFbj # Private key: cQyUrfhCiU8rp1mcv4eQfAdTwZVXvj7N21kZEX52TcELS5FDAL2p
	mineraddress=mzdykDkMfSdeidP7acpUbhcVfFtVTMg5DB # Private key: cSLtUJZYZ5aPCNNvTTuXBPy94Mr49iBgzfXqiRcZb6BPTJycMM1g
	mineraddress=n1gS6tDmcMuWoTeCbRFdQzfAhKYjaxnTHj # Private key: cP3z7fvNG3yoeiYpBeoqDWa1qzYHsDPZ2eDRjLzMf7wcFGDNtu1P
	mineraddress=mmYxH7a3qtrQyhCyK1nBqctSLgiSyfd9vt # Private key: cT14ZwS1Zsfz19CBAxPKk4dfNM1shtC2jHcepUTYcj3qRqeoNbsD
	mineraddress=mizWLQTrBcAhp8fmYp9qwepLWEx7MfRLyv # Private key: cNCf7DECtWD7ysj4kqARUobvqjE1FBvzN8Hfq3bgoHjvPyVVEr93
	mineraddress=mzwp37KxEDfKZfQm6LxRS7nkxrZAcgUrqS # Private key: cPBSQabsG33RS9AL8j6VAgF7veYtUVbySFKXen3qoh7bbpsYVEEs
	mineraddress=mt7zphoNE3U1NsQEcN1miwpCVqrppDEoib # Private key: cPM7st6TpGFKxJkb7xmvMjuv2HYpLs8FbDeGW7KtswpM1RK4FF5k
	mineraddress=mg9WCFUUB7uVTEzJVfD3fi3kUnzZdUFMqU # Private key: cS9cxEjPkjYAhEBrYcmxRiVJQYFJ2sDc6s2JYrYwrkmi1LYeY15D
	mineraddress=mxqG7ioQGjowKoTUKy7ndoH2RKU8cv8JYt # Private key: cURaQQjK8ZDjhEmYKpRy2jani6cjCd2JtUynDehKd1btnXG1znTE
	mineraddress=mrkoa8hEXKfWiWmYgJAzStQCUjxgUvhQQW # Private key: cVcJpgFFXcM99xq6BWxWozsg5vz7fm1GgcXvoYuwCybArrMQxsHk
	mineraddress=mh4hFG8Bt6iWkiZP8mBmZxCNSKd4AZLJDE # Private key: cQYGrYDG1GRxyNtdK54rDquf2YojLwTr67Pxa9AreUYq6v5cAMxt
	mineraddress=mkcEyefPiV2LXmiAsJxtnCw4ZEhLWsnwN1 # Private key: cRJMKmRwaJn6z4EPqamFgqWoWLp6rcgsyB8xKNe1juAsLi3zsE91
	mineraddress=mwEPbNRxsaNfgQmPHYcfU9CHo2Ux5QRc1x # Private key: cS8LE8NkY4FCcDUKgX2frNApVaqKP3KJJpLnioAANkYWb4NR9LLe
	mineraddress=mr9JzWDH6s7cJuAdZHhoKrH9aWo5dmYLW3 # Private key: cUkvh4sDUXHrXmfmZYY2oUJmfPc1rRhF8Btb9tfWt3FT47KxBokY
	mineraddress=mh3ReeQk5XhF6cpw2TexQVZbtND1mFBU5Q # Private key: cPwq3wr1x2mQD5NzkTXkhNVz6SkMdxss3AiVy3NWiC3u7isbpnav
	mineraddress=mvbRLcu2xX31pGPbfL8yV6t4JNUf4sQHgc # Private key: cVhhRkAGHFpvH2yxLjtzeJpGEp7tB8SmXiYxV7MazAp8zKi7xsj1
	mineraddress=mmnwg2spU3DQVhVuBpTCsKd2jC4tAFk2xg # Private key: cSE4c2zoa8XCTXjLDcrRWWPEHehM6qoS5v5647jiVkQboyCqKdtn
	mineraddress=mtiReGFHm1i6LpUZ54eQAY1jojGPBuQBwP # Private key: cTcBgsx9g4oVZSKTgsmCT4TmCKz5Y2Kat4LDnrGxLkxWju67L6Ws
	mineraddress=mtHtim5hxsCPq6vkytVtFJzYiTYRDFVXwT # Private key: cNd2yuK5T246doYKwdtCTbnAqdZg4sx69vKgcBZ4gNWdZYg6GERM
	mineraddress=mq6dunoC4sPPJnBgoUyZEz3ihHNe5wGmkq # Private key: cPDCDc9bp88jitpZNA3Va7geEqatmRbDsAa86DQNPwB9woVHjuVA
	mineraddress=mnPb788WQyQRK8Qp83URpS2bD2noVGJEQz # Private key: cMtkabnJKiN7T4ma1Moq4mxdGaBKKB5wiJ8JsMfgE5VUsntGwFKW
	mineraddress=mrZcAGQdffwtuBkjUSyzK7wzqMfrgrF4BC # Private key: cSHDivWZwoa3jiQDFBF5EWwfYXtpsQVfJtNEaKLeRRi3z16rQjWJ
	mineraddress=mo9hxMnMQUcqAEXTqovMeEdJ4wmvswkH6t
	mineraddress=miVEdh1sWTM2TQr24hHhjW1Q77QQQHUAGH # Inevitably someone is gonna think themselves a smarty pants and sweep all the above addresses,
	mineraddress=mzVR6YdZRUhaB872BH5SR8rPXsYtCrRqRV # thus possibly forcing the above addresses to fail HPoW Rule 2. This means the testnet network
	mineraddress=mwFFHvixYABGVQ6G2csVqwzfMYd6VQcvWe # could run the risk of getting stuck, since it's not widely supported with lots of installs.
	mineraddress=myKe9zSDqLWGJZufjXEfjBuWo61Ks4Lg3v # Here are some addresses with privkey keys destroyed. The coins the following addresses receive
	mineraddress=mxV4B4niYHmkxBBmawtHBnUQyHJG11g9Gk # therefor get burned as they become unspendable UTXO, but their existence supports HPoW on testnet.
	mineraddress=mmQ7HjBLideqDKP5fqpY2oiRPC2pBYjnxt
	mineraddress=myCqSH8dfZ9EXBQPZgHnK9VF43nvpWkcyw # All testnet coin public addresses start with am M or a N. Mainnet coins, the one's that
	mineraddress=mxqyFrJ6DYQ5CPjptdX9jXLMP4npa6SyCx # are publicly traded and used always start with a K. If you would like to take coins from any
	mineraddress=mnYqYpN6gKMzhG2rrfFp6UYZZzazujc6Bu # of these addresses, be sure to send at least 1 coin back the original address so it will
	mineraddress=mnenfD8DYmHwxaQ2mnZQR2XfcP8YzfTfM2 # still meet HPoW Rule 2 with it's minimum balance requirement.
	mineraddress=mpMyprNfY5Kz9E175bnQN85B1pMq3ATroc
	mineraddress=mvxVyK2LJ41Cv4vm8yHZ8Xw534oRGaiH2Z
	mineraddress=mstUwkrcdTAChLymymgFB4h4ibyBTkKMWD
	mineraddress=mtN9c9TeazxLw5uPSR6mW6zwABPbmaEHpL
	mineraddress=mxMAArTr3hHYfbV2YUoxFdVTkMTNoUadWF
	mineraddress=miuWJcdonyEryZUmuFHKrpnsEhc8VTvstS
	mineraddress=mmbtJrLVv76EvJ8hQiMMoeLD3r1USf2vWN
	mineraddress=mrFXqummwGAi7w6saCEGixr3v1RSbzSgrj
	mineraddress=msNfqB4G4r9iV4jBQZmaQBbkbPcVELBdTs
	mineraddress=mmhAk3VqPJqrsv1utCZGWKNnXWE52pgAxt
	mineraddress=mxfdwQjFsBmTFC2RP5CeqQLNfP3rA9R7Cj

	listen=1                      # It is highly unlikely you need to change any of the following values unless you are tinkering with the node. If you decide to
	daemon=1                      # tinker, know that a backup of this file already exists as /root/.lynx/.lynx.conf.
	port=$port
	rpcworkqueue=64               # Our exchange and SPV wallet partners might want to disable the built in miner. This can be easily done with the 'disablebuiltinminer'
	listenonion=0                 # parameter below. As for our miners who are looking to tune their devices, we recommend the default 0.25 (25%), but if you insist on
	upnp=1                        # increasing the 'cpulimitforbuiltinminer' amount, we recommend you not tune it past using 50% of your CPU load. Remember, with HPoW
	dbcache=450                   # increasing the mining speed does not mean you will win more blocks. You are are just generating heat, not blocks. Also, if you are 
	txindex=1                     # using a VPS, increasing 'cpulimitforbuiltinminer' too high might get you banned from the the VPS vendors platform. You've been warned.
	host=$name
	maxmempool=100
	testnet=0
	disablebuiltinminer=0
	cpulimitforbuiltinminer=0.25
	" > $lynxConfigurationFile
	sleep 2 && sed -i 's/^[\t]*//' $lynxConfigurationFile # Remove the pesky tabs inserted by the 'echo' outputs.
	echo "LynxCI: Lynx default configuration file, '$lynxConfigurationFile' was created."
done
[ "$networkEnvironment" = "testnet" ] && { sed -i 's|testnet=0|testnet=1|g' $lynxConfigurationFile; echo "LynxCI: This node is operating on the testnet environment and it's now set in the lynx.conf file."; }
[ "$networkEnvironment" = "mainnet" ] && { sed -i 's|testnet=1|testnet=0|g' $lynxConfigurationFile; echo "LynxCI: This node is operating on the mainnet environment and it's now set in the lynx.conf file."; }
[ "$networkEnvironment" = "mainnet" ] && { sed -i '/mineraddress=m/d' $lynxConfigurationFile; echo "LynxCI: Removed default testnet mining addresses (M) from the lynx.conf file."; }
[ "$networkEnvironment" = "mainnet" ] && { sed -i '/mineraddress=n/d' $lynxConfigurationFile; echo "LynxCI: Removed default testnet mining addresses (N) from the lynx.conf file."; }
[ "$networkEnvironment" = "testnet" ] && { sed -i '/mineraddress=K/d' $lynxConfigurationFile; echo "LynxCI: Removed default mainnet mining addresses (K) from the lynx.conf file."; }
[ "$networkEnvironment" = "mainnet" ] && { sed -i '/addnode=test/d' $lynxConfigurationFile; echo "LynxCI: Removed default testnet nodes from the addnode list in the lynx.conf file."; }
[ "$networkEnvironment" = "testnet" ] && { sed -i '/addnode=node/d' $lynxConfigurationFile; echo "LynxCI: Removed default mainnet nodes from the addnode list in the lynx.conf file."; }
[ "$isPi" = "1" ] && sed -i "s|maxmempool=100|maxmempool=10|g" $lynxConfigurationFile
[ "$isPi" = "1" ] && sed -i "s|dbcache=450|dbcache=100|g" $lynxConfigurationFile # Default is 450MB. Changed to 100MB on the Pi.
cp --remove-destination $lynxConfigurationFile /root/.lynx/.lynx.conf && chmod 600 /root/.lynx/.lynx.conf # We are gonna create a backup of the initially created lynx.conf file.
if [ "$installationMethod" = "compile" ]; then
	cd /root/lynx/ && ./autogen.sh # And finish the configure statement WITH the Berkeley DB parameters included.
	[ "$isPi" = "1" ] && ./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --enable-cxx --without-gui --disable-shared --with-miniupnpc --enable-upnp-default --disable-tests --disable-bench
	[ "$isPi" = "0" ] && ./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --enable-cxx --without-gui --disable-shared --disable-tests --disable-bench
	make
	make install
	#checkinstall -D --install=yes --pkgname=lynxd --pkgversion=0.16.3.9 --include=/root/.lynx/lynx.conf --requires=libboost-all-dev,libevent-dev,libminiupnpc-dev
fi
if [ "$installationMethod" = "install" ]; then
	sed -i "s|/root/lynx/src/lynxd -daemon=0|/usr/local/bin/lynxd -daemon=0|g" /etc/systemd/system/lynxd.service
	sed -i "s|/root/lynx/src/lynx-cli|/usr/local/bin/lynx-cli|g" /etc/systemd/system/lynxd.service
fi
systemctl daemon-reload
systemctl disable listener
systemctl enable lynxd # lynxd will start automatically after reboot.
chown -R root:root /root/.lynx/* # Be sure to reset the ownership of all files in the .lynx dir to root in case any process run
chmod 600 /root/.lynx/*.conf # previously changed the default ownership setting. More of a precautionary measure.
#
# Since the lynxd debug log can be rather sizable over time, we are doing a
# weekly rotate. Since the script fails gracefully for both environments we are
# setting bother up to run.
#
lynxLogrotateConfiguration="/etc/logrotate.d/lynxd.conf"
while [ ! -O $lynxLogrotateConfiguration ] ; do 	
	echo "/root/.lynx/debug.log {
		daily
		rotate 7
		size 10M
		copytruncate
		compress
		notifempty
		missingok
	}
	/root/.lynx/testnet4/debug.log {
		daily
		rotate 7
		size 10M
		copytruncate
		compress
		notifempty
		missingok
	}" > $lynxLogrotateConfiguration
	# Wait a second before we remove the pesky tabs inserted by the 'echo' outputs.
	sleep 1 && sed -i 's/^[\t]*//' $lynxLogrotateConfiguration
done
#
echo "LynxCI: Lynx was installed."
#
# We now write this empty file to the /boot dir. This file will persist after
# reboot so if this script were to run again, it would abort because it would
# know it already ran sometime in the past. This is another way to prevent a
# loop if something bad happens during the install process. At least it will
# fail and the machine won't be looping a reboot/install over and over. This
# helps if we have to debug a problem in the future.
#
while [ ! -O $touchSSHInstallCompleteFile ] ; do
	/usr/bin/touch $touchSSHInstallCompleteFile
	echo "LynxCI: Post install 'ssh' file is installed."
done
#
#
#
while [ ! -O $touchLynxCIInstallCompleteFile ] ; do 
	/usr/bin/touch $touchLynxCIInstallCompleteFile
	echo "LynxCI: Post install tasks are complete."
done
#
#
#
echo "LynxCI: LynxCI was installed. A reboot will occur 2 seconds."
/bin/rm -rf /root/setup.sh
/bin/rm -rf /root/LynxCI/setup.sh
/bin/rm -rf /root/LynxCI/init.sh
/bin/rm -rf /root/LynxCI/README.md
/bin/rm -rf /root/LynxCI/install.sh
sleep 2 && reboot
