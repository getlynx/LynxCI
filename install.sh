#!/bin/bash
# wget -qO - https://getlynx.io/setup.sh | bash
# OR to overide defaults...
# wget -O - https://getlynx.io/install.sh | bash -s "[mainnet|testnet]" "[master|0.16.3.9]"
[ -f /boot/lynxci ] && { echo "LynxCI: Previous LynxCI detected. Install aborted."; exit 5; } || { echo "LynxCI: Thanks for starting the Lynx Cryptocurrency Installer (LynxCI)."; }
enviro="$1" # For most rollouts, the two options are mainnet or testnet. Mainnet is the default 
branch="$2" # The master branch contains the most recent code. You can switch out an alternate branch name for testing, but beware, branches may not operate as expected.
#
# By default, all installations that occur with this script will compile Lynx.
#
installationMethod="compile"
#
# The idea here is to have at least one installer that can be used to build a
# Lynx node very quickly. The current installer supports only Debian 9. If any
# other target OS is detected, then the script will compile from source.
#
if [ "$(cat /etc/os-release | grep 'PRETTY_NAME')" = "PRETTY_NAME=\"Debian GNU/Linux 9 (stretch)\"" ]; then
	installationMethod="install"
	installationSource="https://github.com/getlynx/Lynx/releases/download/v0.16.3.9/lynxd_0.16.3.9-2_amd64.deb"
	installationFile="${installationSource##*/}"
fi
if [ "$(cat /etc/os-release | grep 'PRETTY_NAME')" = "PRETTY_NAME=\"Raspbian GNU/Linux 9 (stretch)\"" ]; then
	installationMethod="install"
	installationSource="https://github.com/getlynx/Lynx/releases/download/v0.16.3.9/lynxd_0.16.3.9-1_armhf.deb"
	installationFile="${installationSource##*/}"
fi
#
bootmai="https://github.com/getlynx/LynxBootstrap/releases/download/v2.0-mainnet/bootstrap.tar.gz"
bootdev="https://github.com/getlynx/LynxBootstrap/releases/download/v1.0-testnet/bootstrap.tar.gz"
[ -z "$1" ] && enviro="mainnet" # Default is mainnet.
[ -z "$2" ] && branch="0.16.3.9"
[ "$enviro" = "mainnet" -o "$enviro" = "testnet" ] && { echo "LynxCI: Supplied environment parameter ($enviro) accepted."; } || { echo "LynxCI: Failed to meet required params."; }
[ "$branch" = "master" -o "$branch" = "0.16.3.9" ] && { echo "LynxCI: Supplied branch parameter ($branch) accepted."; } || { echo "LynxCI: Failed to meet required params."; }
[ "$branch" = "master" ] && installationMethod="compile" # Unless master branch is specified, the profile will install from a DEB file.
[ "$enviro" = "testnet" ] && installationMethod="compile" # Testnet build are always compiled then installed. No installer exists for testnet.
[ "$enviro" = "mainnet" ] && { port="22566"; echo "LynxCI: The mainnet port is 22566."; } # The Lynx network uses this port when peers talk to each other.
[ "$enviro" = "mainnet" ] && { rpcport="9332"; echo "LynxCI: The mainnet rpcport is 9332."; } # This is the netowork port for RPC communication with clients.
[ "$enviro" = "testnet" ] && { port="44566"; echo "LynxCI: The testnet port is 44566."; } # The Lynx network uses this port when peers talk to each other.
[ "$enviro" = "testnet" ] && { rpcport="19335"; echo "LynxCI: The testnet rpcport is 19335."; } # This is the netowork port for RPC communication with clients.
echo "LynxCI: Updating the installed package list."
systemctl disable lynxd # In case the install is taking place again, due to a failed previous install.
systemctl stop lynxd # In case the install is taking place again, due to a failed previous install.
systemctl daemon-reload # In case the install is taking place again, due to a failed previous install.
apt-get update -y # Before we begin, we need to update the local repo. For now, the update is all we need and the device will still function properly.
apt-get remove -y apache2 pi-bluetooth postfix
#apt-get upgrade -y # Sometimes the upgrade generates an interactive prompt. This is best handled manually depending on the VPS vendor.
apt-get install -y apt-transport-https autoconf automake build-essential bzip2 ca-certificates curl fail2ban g++ gcc git git-core htop libboost-all-dev libcurl4-openssl-dev libevent-dev libgmp-dev libjansson-dev libminiupnpc-dev libncurses5-dev libssl-dev libtool libz-dev logrotate lsb-release make nano pkg-config software-properties-common sudo unzip
#apt-get install -y checkinstall
echo "LynxCI: Required system packages have been installed."
apt-get autoremove -y # Time for some cleanup work.
rpcuser="$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)" # Lets generate some RPC credentials for this node.
rpcpass="$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)" # Lets generate some RPC credentials for this node.
isPi="0" && [ "$(cat /proc/cpuinfo | grep 'Revision')" != "" ] && { isPi="1"; echo "LynxCI: The target device is a Raspberry Pi."; } # Default to 0. If the value is 1, then we know the target device is a Pi.
[ "$enviro" = "mainnet" -a "$isPi" = "1" ] && name="lynxpi$(shuf -i 200000000-999999999 -n 1)" # If the device is a Pi, the name is appended.
[ "$enviro" = "mainnet" -a "$isPi" = "0" ] && name="lynx$(shuf -i 200000000-999999999 -n 1)" # If the device is running mainnet then the node id starts with 2-9.
[ "$enviro" = "testnet" -a "$isPi" = "1" ] && name="lynxpi$(shuf -i 100000000-199999999 -n 1)" # If the device is a Pi, the name is appended.
[ "$enviro" = "testnet" -a "$isPi" = "0" ] && name="lynx$(shuf -i 100000000-199999999 -n 1)" # If the device is running testnet then the node id starts with 1.
[ "$isPi" = "1" ] && sed -i '/pi3-disable-bt/d' /boot/config.txt # Lets not assume that an entry already exists on the Pi, so purge any preexisting bluetooth variables.
[ "$isPi" = "1" ] && echo "dtoverlay=pi3-disable-bt" >> /boot/config.txt # Now, append the variable and value to the end of the file for the Pi.
firewallCheck="/root/LynxCI/firewall.sh"
while [ ! -O $firewallCheck ] ; do # Only create the file if it doesn't already exist.
	echo "#!/bin/bash
	IsRestricted=N # If the script has IsRestricted set to N, then let's open up port 22 for any IP address.
	/sbin/iptables -F # Let's flush any existing iptables rules that might exist and start with a clean slate.
	/sbin/iptables -I INPUT 1 -i lo -j ACCEPT # We should always allow loopback traffic.
	/sbin/iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # If we are already authenticated, then ACCEPT further traffic from that IP address.
	/sbin/iptables -I INPUT 3 -p tcp --dport 80 -j DROP # Because the Block Crawler is available via port 80 we MIGHT open up port 80 for that traffic, later.
	/sbin/iptables -I INPUT 4 -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT # Always allow local LAN access.
	/sbin/iptables -I INPUT 5 -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT # Always allow local LAN access.
	/sbin/iptables -I INPUT 6 -p tcp --dport $port -j ACCEPT # This node listens for other Lynx nodes on port $port, so we need to open that port.
	/sbin/iptables -I INPUT 7 -p tcp --dport $rpcport -j ACCEPT # By default, the RPC port $rpcport is opened to the public.
	[ \"\$IsRestricted\" = \"N\" ] && /sbin/iptables -I INPUT 8 -p tcp --dport 22 -j ACCEPT
	# Secure access from your home/office IP. Customize as you like. [VPN 10 N-West] This is NOT a backdoor into your LynxCI node for the Lynx Developers. You still
	# control the access credentials for your LynxCI node. The only account available is the _lynx_ user account and you control the password for it. The root user
	# account is locked (don't trust us, verify yourself). This firewall entry is for convenience of the Lynx dev team, but also a convenient example of how you can
	# customize the firewall for your own direct access from you home or office IP. Save your change and be sure to execute /root/firewall.sh when done.
	[ \"\$IsRestricted\" = \"Y\" ] && /sbin/iptables -I INPUT 8 -p tcp -s 162.210.250.170 --dport 22 -j ACCEPT
	/sbin/iptables -I INPUT 9 -j DROP # We add this last line to drop any other traffic that comes to this computer.
	[ -f /root/.lynx/bootstrap.dat.old ] && /bin/rm -rf /root/.lynx/bootstrap.dat.old # Lets delete it if it still exists on the drive.
	[ -f /root/*.deb ] && /bin/rm -rf /root/*.deb # Lets delete the installer if it still exists on the drive.
	[ \"\$(/usr/local/bin/lynx-cli uptime)\" -gt \"604900\" ] && /bin/sed -i 's/IsRestricted=N/IsRestricted=Y/' /root/LynxCI/firewall.sh # Lock the firewall after 1 week" > $firewallCheck
	sleep 1 && sed -i 's/^[\t]*//' $firewallCheck # Remove the pesky tabs inserted by the 'echo' outputs.
	[ "$isPi" = "0" ] && { echo "/usr/sbin/deluser lynx sudo >/dev/null 2>&1" >> $firewallCheck; } # Remove the lynx user from the sudo group, except if the host is a Pi. This is for security reasons.
	sleep 1 && chmod 700 $firewallCheck # Need to make sure crontab can run the file.
	echo "LynxCI: The default iptables was created."
done
crontab -r # Purge and set the firewall crontab
crontab -l | { cat; echo "@daily		/root/LynxCI/firewall.sh"; } | crontab - # Purge and set the firewall crontab
echo "LynxCI: Firewall is built and scheduled to run daily."
echo "$name" > /etc/hostname
[ "$isPi" = "1" ] && { sed -i '/gpu_mem/d' /boot/config.txt; echo "gpu_mem=16" >> /boot/config.txt; echo "LynxCI: Pi GPU memory was reduced to 16MB on reboot."; }
echo "LynxCI: Preparing to install Nginx."
curl -ssL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg # To prep the install of Nginx, get the keys installed.
sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' # Add Nginx to the source list.
apt-get -y update && apt-get -y install nginx php7.2 php7.2-common php7.2-bcmath php7.2-cli php7.2-fpm php7.2-opcache php7.2-xml php7.2-curl php7.2-mbstring php7.2-zip # Install the needed Nginx packages.
echo "LynxCI: Nginx install is complete."
echo "LynxCI: Downloading the Lynx $enviro bootstrap file."
[ "$enviro" = "mainnet" ] && { bootstrapCheck="/root/.lynx/bootstrap.dat"; }
[ "$enviro" = "testnet" ] && { bootstrapCheck="/root/.lynx/testnet4/bootstrap.dat"; }
while [ ! -O $bootstrapCheck ] ; do # Only create the file if it doesn't already exist.
	[ "$enviro" = "mainnet" ] && { mkdir -p /root/.lynx/; wget $bootmai -O - | tar -xz -C /root/.lynx/; }
	[ "$enviro" = "testnet" ] && { mkdir -p /root/.lynx/testnet4/; wget $bootdev -O - | tar -xz -C /root/.lynx/testnet4/; }
	sleep 1
	chmod 600 $bootstrapCheck
	sleep 1
	echo "LynxCI: Lynx $enviro bootstrap tarball is downloaded and decompressed."
done
listenerSer="/etc/systemd/system/listener.service"
while [ ! -O $listenerSer ] ; do # Only create the file if it doesn't already exist.
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
	WantedBy=multi-user.target" > $listenerSer
	sleep 1 && sed -i 's/^[\t]*//' $listenerSer # Remove the pesky tabs inserted by the 'echo' outputs.
	echo "LynxCI: Service 'listener' is installed."
done
lynxdSer="/etc/systemd/system/lynxd.service"
while [ ! -O $lynxdSer ] ; do # Only create the file if it doesn't already exist.
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
	WantedBy=multi-user.target" > $lynxdSer
	sleep 1 && sed -i 's/^[\t]*//' $lynxdSer # Remove the pesky tabs inserted by the 'echo' outputs.
	echo "LynxCI: Service 'lynxd' is installed."
done
[ "$isPi" = "1" ] && { sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile; /etc/init.d/dphys-swapfile restart; } # On a Raspberry Pi, the default swap is 100MB. This is a little restrictive, so we are expanding it to a full 2GB of swap.
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config # We don't ever want a user to login directly to the root account, even if they know the correct password.
sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' /etc/ssh/sshd_config # We don't ever want a user to login directly to the root account, even if they know the correct password.
adduser lynx --disabled-password --gecos "" # Create the user account 'lynx' and skip the prompts for additional information.
echo "lynx:lynx" | chpasswd # Set the default password
chage -d 0 lynx # Force the user to change the password after the first login.
adduser lynx sudo # We don't always know the root password of the target device, be if a Pi, VPS or something else. Let's add the user to the sudo group so they can gain access to the root
echo "LynxCI: The user account 'lynx' was given sudo rights." # account. When the firewall resets automatically, the user will be removed from the sudo group, for security reasons.
[ "$isPi" = "1" ] && usermod -L -e 1 pi # If the target device is a Raspberry Pi, then let's assume the Pi account exists. Look for it and lock it if we find one. Otherwise skip this 
[ "$isPi" = "1" ] && echo "LynxCI: For security purposes, the 'pi' account was locked and is no longer accessible." # step if the Pi account is not found.
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

echo \"  | The current block height on this LynxCI node is \$(lynx-cli getblockcount).                    |
 '-----------------------------------------------------------------------------'\"

echo \"  | Local version is \$(lynx-cli -version).          |
 '-----------------------------------------------------------------------------'\"

fi
fi

echo \"  | The unique identifier for this LynxCI node is $name.                |
 '-----------------------------------------------------------------------------'\"

port=\"$port\"

if [ \"\$port\" = \"44566\" ]; then

echo \"  | This is a non-production 'testnet' environment of Lynx.                     |
 '-----------------------------------------------------------------------------'\"

fi

echo \"  | Visit https://getlynx.io/ for more information.                             |
 '-----------------------------------------------------------------------------'\"

" > /etc/profile.d/portcheck.sh
chmod 755 /etc/profile.d/portcheck.sh
chmod 755 /etc/profile.d/logo.txt
chown root:root /etc/profile.d/portcheck.sh
chown root:root /etc/profile.d/logo.txt
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
systemctl stop nginx && systemctl disable nginx && echo "LynxCI: Nginx service was gracefully stopped and also disabled on boot."
systemctl stop php7.2-fpm && systemctl disable php7.2-fpm && echo "LynxCI: PHP-FPM service was gracefully stopped and also disabled on boot."
echo "LynxCI: Nginx is installed, but it's disabled on boot."
rm -rf /var/www/html/
git clone https://github.com/getlynx/LynxBlockCrawler.git /var/www/html/
chmod 755 -R /var/www/html/
chown www-data:www-data -R /var/www/html/
echo "LynxCI: Block Crawler is installed."
if [ "$installationMethod" = "compile" ]; then
	rm -rf /root/lynx/ # Lets assume this directory already exists, so lets purge it first.
	git clone -b "$branch" https://github.com/getlynx/Lynx.git /root/lynx/ # Pull down the specific branch version of Lynx source we arew planning to compile.
	rm -rf /root/lynx/db4 && mkdir -p /root/lynx/db4 # We will need this db4 directory soon so let's delete and create it. Just in case.
	cd /root/lynx/ && wget http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz # Pull down the Berkeley DB 4.8 source tarball.
	tar -xzf db-4.8.30.NC.tar.gz && cd db-4.8.30.NC/build_unix/ # Unpack the tarball and hop into the directory.
	../dist/configure --enable-cxx --disable-shared --with-pic --prefix=/root/lynx/db4 # Configure the make file to compile the Berkeley DB 4.8 source.
	make --quiet install # Compile the Berkeley DB 4.8 source
fi
if [ "$installationMethod" = "install" ]; then
	while [ ! -O "/root/$installationFile" ] ; do
		echo "LynxCI: Downloading and installing the Lynx installer package for the target OS."
		wget -P /root $installationSource && dpkg -i /root/$installationFile
	done
fi
lconfCheck="/root/.lynx/lynx.conf"
while [ ! -O $lconfCheck ] ; do # Only create the file if it doesn't already exist.
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
	mineraddress=KKpNgtMs8kjpxB9EHmLVyhsdfcA6tyZ2g8
	mineraddress=K7GMcJ4idxwhbusn8sTBotJbsRZ8FU22cu
	mineraddress=KFgo4RmUiFX8FAg3sk8ZRptqmTD9Nk8u2w
	mineraddress=KV3fxxtbb1gwY69tAsqkq8rBHzMczia7To
	mineraddress=KHHHfhcethqahpN7aAeJ9JiBDGtjsW89oM
	mineraddress=KVgBWE4xibFrRzN1X7Cv3nVymTg3EcnePm
	mineraddress=KPhTE61wshvyiDHFLLLvZ3rBhrGjWruWdh
	mineraddress=KLpTz6JbUEkrxNTs24gftPxsgyGG53qKsD
	mineraddress=KBw3LHq6TNDLTL35QFTfwyGvDA1YA4xwq7
	mineraddress=KDWbrVGdb9M5MuH3q8XP9SuNQweX4g1w7C
	mineraddress=KBYp6Ys468Hir2obvT1QgowqtYZ1P7txPU
	mineraddress=KGDFGZuwCnT9kcBNWPtQVuZdZ1AoiaGYUy
	mineraddress=KFaLZ37WgSXeUUpQZAXamMDfDkS96Fpp6W
	mineraddress=KSbtHFRoaj8Vb5EespmCEbtNJGG7UtM2U2
	mineraddress=KUn12PLFXUaVwneQMNp6kiZ2c9rUVPkDjp
	mineraddress=KHXGt1Pn1yVXvYQmLTuG8pYqYH29t6p8pL
	mineraddress=K85WRcMbcuWi9T3JsH7NhZp8Tb3nNmcYVS
	mineraddress=KMzbPq5YvdCpNiVtECk9VVVGbnxhP6V7ch
	mineraddress=K8fQpFnHWw2iBHycR1B1NWJBCGSojEhjst
	mineraddress=K8yBpqfkP2gg7buhNhWM7s3PqBsCA7PW9r
	mineraddress=KSGe8xZbM9NfeQnjX9fyMbqLaGQTRUS5Jh
	mineraddress=KBw2p51RrrbcceRoSbvb6ZkX437kuQM99F
	mineraddress=KDv7VKpixza5u51L5gmPNtUyRWpkaJBYg3
	mineraddress=KTHz2RJrt8SoDXbzwVJ3Znybn3mZNJwscs
	mineraddress=KB7SVrCBjKTSZSxqNhX7zfpNK68MPRG95k
	mineraddress=K95nM1gWhRMRvgLZTyi61tceYjfp5Ys71u
	mineraddress=KJevkjENSeBzVp5MnSvyNqnemF9rn6unYo
	mineraddress=KQqL8U2vD5QpZg8MJ47cVj2sRbo7gV4tu5
	mineraddress=KQpa4GDG5GcwrinjpDmUgpAaYgRbfNGUMK
	mineraddress=KGFx9JD1dFY4dtFdLqw1d3ZQnWL6ws6nLy
	mineraddress=KNoWE13FPBDUuqyK1DUT7qnJx9jVfqkeGc
	mineraddress=KMqkxAmFYpMDEyEA5QmbZZrwXtu6pwuv61
	mineraddress=KS2Gg8MvcJmLNPK7mQdoG6DJJaZxQ4neej
	mineraddress=KBmLgzVMiKbcMuaoJeoPNs5R98tAHYM515
	mineraddress=KCtFzP3fGn1ZxRiNVFeCnGuwiy7qsSvB22
	mineraddress=K9WR6ZTB5X4hoWvTUK1xR4ddWUSX9qMeS4
	mineraddress=KSXLSbsoovJepb9x1sczDRNyTvDYEfZZ2k
	mineraddress=KNv9XbCfshP4vV9GN7p6KYGEPqYFc4Ei6c
	mineraddress=KRUrR4beUxL5AsyVduL5KT7BNHsbkA9Mh2
	mineraddress=K9URJRCsL6nrYMXVA6kPBVq5Db8gW5iVEQ
	mineraddress=KNYnVkhaQehdbKSqy4a3AiZGBAYQkqemPF
	mineraddress=KExtMudoDex2bckdwhoi2jJxpPMTwpvoSd
	mineraddress=KHCqKmt8B3zgQ6z3XWGhhPLuLWvsJiwy3Q
	mineraddress=KNZLV7CcBgXR87xi7NCyhGojaJrWHg63FC
	mineraddress=K8cckpj6R5yBPNHfBpfP3mm9Joo2VgRWSd
	mineraddress=KAQuZ4eTzTQ9AR6kgHXay6DbVXBACwfJpK
	mineraddress=KQ69GDCDVcd1ar6gFqUHhLzUCa1eG6QK2u
	mineraddress=KFj36awh9AaAK3pxKW8E7RmMQf1P17VNdr
	mineraddress=K9LLEtQyw32QuhsrdQuf9sYAiMkdNnTvHh
	mineraddress=KJfbyn79urpMCaSH3LbN5THz9BFzjpbbXP
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
	mineraddress=KBp7DvcmhonVqy3Es73dQFTtjCPGrNkPDk
	mineraddress=KKuxb5KQCF13D7kDL6rMPx5hNTtDGvqiTV
	mineraddress=KC4GBFAbsgRGvdrY9aQgU4XNX85mAFmHHU
	mineraddress=KGC3UkcLS2Yq5ZojhuHu5T7XBpf3DJKJKp
	mineraddress=KEM9dV7pP1YZkTA3gYpfydSqQUyFzfmwrm
	mineraddress=K9JgSJZW6koYKQ4rPmZ7FwRH6dpy7SHVUD
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
	" > $lconfCheck
	sleep 2 && sed -i 's/^[\t]*//' $lconfCheck # Remove the pesky tabs inserted by the 'echo' outputs.
	echo "LynxCI: Lynx default configuration file, '$lconfCheck' was created."
done
[ "$enviro" = "testnet" ] && { sed -i 's|testnet=0|testnet=1|g' $lconfCheck; echo "LynxCI: This node is operating on the testnet environment and it's now set in the lynx.conf file."; }
[ "$enviro" = "mainnet" ] && { sed -i 's|testnet=1|testnet=0|g' $lconfCheck; echo "LynxCI: This node is operating on the mainnet environment and it's now set in the lynx.conf file."; }
[ "$enviro" = "mainnet" ] && { sed -i '/mineraddress=m/d' $lconfCheck; echo "LynxCI: Removed default testnet mining addresses (M) from the lynx.conf file."; }
[ "$enviro" = "mainnet" ] && { sed -i '/mineraddress=n/d' $lconfCheck; echo "LynxCI: Removed default testnet mining addresses (N) from the lynx.conf file."; }
[ "$enviro" = "testnet" ] && { sed -i '/mineraddress=K/d' $lconfCheck; echo "LynxCI: Removed default mainnet mining addresses (K) from the lynx.conf file."; }
[ "$enviro" = "mainnet" ] && { sed -i '/addnode=test/d' $lconfCheck; echo "LynxCI: Removed default testnet nodes from the addnode list in the lynx.conf file."; }
[ "$enviro" = "testnet" ] && { sed -i '/addnode=node/d' $lconfCheck; echo "LynxCI: Removed default mainnet nodes from the addnode list in the lynx.conf file."; }
[ "$isPi" = "1" ] && sed -i "s|maxmempool=100|maxmempool=10|g" $lconfCheck
[ "$isPi" = "1" ] && sed -i "s|dbcache=450|dbcache=100|g" $lconfCheck # Default is 450MB. Changed to 100MB on the Pi.
cp --remove-destination $lconfCheck /root/.lynx/.lynx.conf && chmod 600 /root/.lynx/.lynx.conf # We are gonna create a backup of the initially created lynx.conf file.
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
verifyconf="/etc/logrotate.d/lynxd.conf"
while [ ! -O $verifyssh ] ; do 	
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
	}" > $verifyconf
	sleep 1 && sed -i 's/^[\t]*//' $verifyconf # Remove the pesky tabs inserted by the 'echo' outputs.
done
echo "LynxCI: Lynx was installed."
verifyssh="/boot/ssh" 											# We now write this empty file to the /boot dir. This file will persist after reboot so if
while [ ! -O $verifyssh ] ; do 									# this script were to run again, it would abort because it would know it already ran sometime
	/usr/bin/touch $verifyssh 									# in the past. This is another way to prevent a loop if something bad happens during the install
	echo "LynxCI: Post install 'ssh' file is installed."  		# process. At least it will fail and the machine won't be looping a reboot/install over and
done 															# over. This helps if we have to debug a problem in the future.
verifylynxci="/boot/lynxci"
while [ ! -O $verifylynxci ] ; do 
	/usr/bin/touch $verifylynxci
	echo "LynxCI: Post install tasks are complete."
done
echo "LynxCI: LynxCI was installed. A reboot will occur 2 seconds."
/bin/rm -rf /root/setup.sh
/bin/rm -rf /root/LynxCI/setup.sh
/bin/rm -rf /root/LynxCI/init.sh
/bin/rm -rf /root/LynxCI/README.md
/bin/rm -rf /root/LynxCI/install.sh
sleep 2 && reboot
