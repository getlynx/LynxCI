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
mainnetBootstrap="https://github.com/getlynx/LynxBootstrap/releases/download/v3.0-mainnet/bootstrap.tar.gz"
testnetBootstrap="https://github.com/getlynx/LynxBootstrap/releases/download/v1.0-testnet/bootstrap.tar.gz"
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
# Create the default lynx.conf file
#
lynxConfigurationFile="/root/.lynx/lynx.conf"
while [ ! -O $lynxConfigurationFile ] && [ grep -q host $lynxConfigurationFile ]; do
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
	" > $lynxConfigurationFile

	[ "$networkEnvironment" = "mainnet" ] && for i in $(shuf -i 10-50 -n 40); do echo "addnode=node$i.getlynx.io" >> $lynxConfigurationFile; done
	[ "$networkEnvironment" = "testnet" ] && for j in $(shuf -j 1-9 -n 9); do echo "addnode=test0$j.getlynx.io" >> $lynxConfigurationFile; done

	echo "
	# The following addresses are known to pass the validation requirements for HPoW. If you would
	# like to earn your own mining rewards, you can add/edit/delete this list with your own
	# addresses (more is better). You must have a balance of between 1,000 and 100,000,000 Lynx in
	# each of the Lynx addresses in order to win the block reward. Alternatively, you can enable
	# wallet functions on this node (above), deposit Lynx to the local wallet (again, between 1,000
	# and 100,000,000 Lynx) and the miner will ignore the following miner address values.
	" >> $lynxConfigurationFile

	[ "$networkEnvironment" = "mainnet" ] && for address in $(cat /root/LynxCI/address-mainnet.txt); do echo "mineraddress=$address" >> $lynxConfigurationFile; done
	[ "$networkEnvironment" = "testnet" ] && for address in $(cat /root/LynxCI/address-testnet.txt); do echo "mineraddress=$address" >> $lynxConfigurationFile; done

	echo "
	listen=1                      # It is highly unlikely you need to change any of the following values unless you are tinkering with the node. If you decide to
	daemon=1                      # tinker, know that a backup of this file already exists as /root/.lynx/.lynx.conf.
	port=$port
	rpcworkqueue=64               # Our exchange and SPV wallet partners might want to disable the built in miner. This can be easily done with the 'disablebuiltinminer'
	listenonion=0                 # parameter below. As for our miners who are looking to tune their devices, we recommend the default 0.25 (25%), but if you insist on
	upnp=1                        # increasing the 'cpulimitforbuiltinminer' amount, we recommend you not tune it past using 50% of your CPU load. Remember, with HPoW
	dbcache=450                   # increasing the mining speed does not mean you will win more blocks. You are just generating heat, not blocks. Also, if you are using
	txindex=1                     # a VPS, increasing 'cpulimitforbuiltinminer' too high might get you banned from the the VPS vendors platform. You've been warned.
	host=$name
	maxmempool=100
	testnet=0
	disablebuiltinminer=0
	cpulimitforbuiltinminer=0.25
	" >> $lynxConfigurationFile
done
sleep 2 && sed -i 's/^[\t]*//' $lynxConfigurationFile # Remove the pesky tabs inserted by the 'echo' outputs.
echo "LynxCI: Lynx default configuration file, '$lynxConfigurationFile' was created."

[ "$networkEnvironment" = "testnet" ] && { sed -i 's|testnet=0|testnet=1|g' $lynxConfigurationFile; echo "LynxCI: This node is operating on the testnet environment and it's now set in the lynx.conf file."; }
[ "$networkEnvironment" = "mainnet" ] && { sed -i 's|testnet=1|testnet=0|g' $lynxConfigurationFile; echo "LynxCI: This node is operating on the mainnet environment and it's now set in the lynx.conf file."; }
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
/bin/rm -rf /root/LynxCI/address-mainnet.txt
/bin/rm -rf /root/LynxCI/address-testnet.txt
sleep 2 && reboot
