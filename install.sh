#!/bin/bash

environment="mainnet"
lynxbranch="master"

detect_os () {

	if [ "$environment" = "mainnet" ]; then

		port="22566"
		rpcport="9332"

	else

		port="44566"
		rpcport="19335"

	fi

	# We are inspecting the local operating system and extracting the full name so we know the
	# unique flavor. In the rest of the script we have various changes that are dedicated to
	# certain operating system versions.

	version_id=`cat /etc/os-release | egrep '^VERSION_ID=' | cut -d= -f2 -d'"'`

	pretty_name=`cat /etc/os-release | egrep '^PRETTY_NAME=' | cut -d= -f2 -d'"'`

	checkForRaspbian=$(cat /proc/cpuinfo | grep 'Revision')

	echo "Build environment is '$environment'."

	# Since we are starting the install of LynxCI, let's remove the crontab that started this
	# process so we don't accidently run it twice simultaneously. That could get ugly. Now this 
	# script can run as long as it needs without concern another crontab might start and withdraw
	# reseources.

	crontab -r &> /dev/null

}

manage_swap () {

	# Some vendors already have swap set up, so only create it if it's not already there.

	exists="$(swapon --show | grep 'partition')"

	if [ -z "$exists" ]; then

		# https://www.2daygeek.com/shell-script-create-add-extend-swap-space-linux/#

		newswapsize=1024

		grep -q "swapfile" /etc/fstab

		if [ $? -ne 0 ]; then

			fallocate -l ${newswapsize}M /swapfile

			chmod 600 /swapfile

			mkswap /swapfile

			swapon /swapfile

			echo '/swapfile none swap defaults 0 0' >> /etc/fstab

		fi

	fi

	# Only if the target device is a Pi, bump up the swap.

	if [ ! -z "$checkForRaspbian" ]; then

		# On a Raspberry Pi, the default swap is 100MB. This is a little restrictive, so we are
		# expanding it to a full 1GB of swap.

		sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile

		/etc/init.d/dphys-swapfile restart

	fi

}

reduce_gpu_mem () {

	# On the Pi, the default amount of gpu memory is set to be used with the GUI build. Instead
	# we are going to set the amount of gpu memmory to a minimum due to the use of the Command
	# Line Interface (CLI) that we are using in this build. This means we don't have a GUI here,
	# we only use the CLI. So no need to allocate GPU ram to something that isn't being used. Let's
	# assign the param below to the minimum value in the /boot/config.txt file.

	if [ ! -z "$checkForRaspbian" ]; then

		# First, lets not assume that an entry doesn't already exist, so let's purge and preexisting
		# gpu_mem variables from the respective file.

		sed -i '/gpu_mem/d' /boot/config.txt

		# Now, let's append the variable and value to the end of the file.

		echo "gpu_mem=16" >> /boot/config.txt

		echo "GPU memory was reduced to 16MB on reboot."

	fi

}

disable_bluetooth () {

	if [ ! -z "$checkForRaspbian" ]; then

		# First, lets not assume that an entry doesn't already exist, so let's purge any preexisting
		# bluetooth variables from the respective file.

		sed -i '/pi3-disable-bt/d' /boot/config.txt

		# Now, let's append the variable and value to the end of the file.

		echo "dtoverlay=pi3-disable-bt" >> /boot/config.txt

		# Next, we remove the bluetooth package that was previously installed.

		apt-get -qq remove pi-bluetooth -y

		echo "Bluetooth was uninstalled."

	fi

}

set_network () {

	ipaddr=$(ip route get 1 | awk '{print $NF;exit}')

	hhostname="lynx$(shuf -i 100000000-999999999 -n 1)"

	fqdn="$hhostname.getlynx.io"

	echo $hhostname > /etc/hostname && hostname -F /etc/hostname

	echo $ipaddr $fqdn $hhostname >> /etc/hosts

}

install_portcheck () {

	rm -rf /etc/profile.d/portcheck.sh

	rm -rf /etc/profile.d/logo.txt

	cp -rf /root/LynxCI/logo.txt /etc/profile.d/logo.txt

	echo "	#!/bin/bash

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
 | For local tools to play and learn, type 'sudo /root/lynx/src/lynx-cli help'.|
 '-----------------------------------------------------------------------------'
 | For LYNX RPC credentials, type 'sudo nano /root/.lynx/lynx.conf'.           |
 '-----------------------------------------------------------------------------'\"

 		if [ \"\$(id -u)\" = \"0\" ]; then
        if [ ! -z \"\$(/root/lynx/src/lynx-cli getblockcount)\" ]; then

        echo \" | The current block height on this LynxCI node is \$(/root/lynx/src/lynx-cli getblockcount).                    |
 '-----------------------------------------------------------------------------'\"

 		echo \" | Local version is \$(/root/lynx/src/lynx-cli -version).          |
 '-----------------------------------------------------------------------------'\"

        fi
    	fi

        echo \" | The unique identifier for this LynxCI node is $hhostname.                |
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

}

setup_nginx () {

    rm -rf /etc/nginx/sites-enabled/default

    rm -rf /etc/nginx/sites-available/default

    echo "

	server {

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

	}

    " > /etc/nginx/sites-available/default

    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

    sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.2/fpm/php.ini

    # The first command stops nginx and the second makes sure it doesn't start after a reboot.

	systemctl stop nginx && systemctl disable nginx

	# The first command stops PHP-FPM and the second makes sure it doesn't start after a reboot.

	systemctl stop php7.2-fpm && systemctl disable php7.2-fpm

	echo "Nginx is configured."

	rm -rf /var/www/html/

	git clone https://github.com/getlynx/LynxBlockCrawler.git /var/www/html/

	chmod 755 -R /var/www/html/
	chown www-data:www-data -R /var/www/html/

	echo "Block Crawler is installed."

}

# The MiniUPnP project offers software which supports the UPnP Internet Gateway Device (IGD)
# specifications. You can read more about it here --> http://miniupnp.free.fr
# We use this code because most folks don't know how to configure their home cable modem or wifi
# router to allow outside access to the Lynx node. While this Lynx node can talk to others, the
# others on the network can't always talk to this device, especially if it's behind a router at
# home. Currently, this library is only installed if the device is a Raspberry Pi.

install_miniupnpc () {

	if [ ! -z "$checkForRaspbian" ]; then

		echo "$pretty_name detected. Installing Miniupnpc."

		apt-get -qq install libminiupnpc-dev -y

		echo "Miniupnpc was installed."

	fi

}

install_lynx () {

	echo "$pretty_name detected. Installing Lynx."

	apt-get -qq install autoconf automake bzip2 curl nano htop g++ gcc git git-core pkg-config build-essential libtool libncurses5-dev software-properties-common libssl-dev libboost-all-dev libminiupnpc-dev libevent-dev -y

	rrpcuser="$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)"

	rrpcpassword="$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)"

	rm -rf /root/lynx/

	git clone -b "$lynxbranch" https://github.com/getlynx/Lynx.git /root/lynx/

	# We will need this db4 directory soon so let's delete and create it.

	rm -rf /root/lynx/db4 && mkdir -p /root/lynx/db4

	# We need a very specific version of the Berkeley DB for the wallet to function properly.

	cd /root/lynx/

	wget http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz

	# Now that we have the tarbar file, lets unpack it and jump to a sub directory within it.

	tar -xzf db-4.8.30.NC.tar.gz

	cd db-4.8.30.NC/build_unix/

	# Configure and run the make file to compile the Berkeley DB source.

	../dist/configure --enable-cxx --disable-shared --with-pic --prefix=/root/lynx/db4

	make --quiet install

	# Now that the Berkeley DB is installed, let's jump to the lynx directory and finish the
	# configure statement WITH the Berkeley DB parameters included.

	cd /root/lynx/

	./autogen.sh

	# If it's a Pi device then set up the uPNP arguments.

	if [ ! -z "$checkForRaspbian" ]; then

		cd /root/lynx/

		./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --enable-cxx --without-gui --disable-shared --with-miniupnpc --enable-upnp-default --disable-tests --disable-bench

		make --quiet

	else

		cd /root/lynx/

		./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --enable-cxx --without-gui --disable-shared --disable-tests --disable-bench

		make --quiet

	fi

	# The .lynx dir must exist for the bootstrap and lynx.conf to be placed in it.

	cd ~/ && rm -rf .lynx && mkdir .lynx

	# Some VPS vendors are struggling with cryptocurrency daemons and miners running on their 
	# platforms. These applications and mining platforms waste resources on those platforms so it's 
	# understandable why they block those daemons from running. Testing has found that lynxd is 
	# killed occasionally on some VPS platforms, even though the avg server load for a LynxCI built
	# is about 0.3 with 1 CPU and 1 GB of RAM. By copying the lynxd daemon and using the randomly 
	# generated name, we escape the daemon getting killed by some vendors. Of course, it is a cat
	# and mouse game so this will be upgraded sometime in the future.

	cp --remove-destination /root/lynx/src/lynxd /root/lynx/src/$hhostname

	sed -i "s|/root/lynx/src/lynxd|/root/lynx/src/${hhostname}|g" /root/LynxCI/installers/systemd.sh


	# If this is a testnet node, the debug.log file is in a different directory. Lets be sure to
	#truncate that file too, otherwise the drive space will fill up.

	if [ "$rpcport" = "19335" ]; then

		sed -i "s|debug.log|testnet4/debug.log|g" /root/LynxCI/stop.sh
		sed -i "s|debug.log|testnet4/debug.log|g" /root/LynxCI/start.sh

	fi

	# Below we are creating the default lynx.conf file. This file is created with the dynamically
	# created RPC credentials and it sets up the networking with settings that testing has found to
	# work well in the LynxCI build. Of course, you can edit it further if you like, but this
	# default file is the recommended start point.

	echo "
# The following RPC credentials are created at build time and are unique to this host. If you
# like, you can change them, but you are encouraged to keep very complex values for each. If an
# attacker gains RPC access to this host they will steal your Lynx. Understanding that, the
# wallet is disabled by default so the risk of loss is zero with the default configuration.
#
# curl --user $rrpcuser:$rrpcpassword --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"help\", \"params\": [] }' -H 'content-type: text/plain;' http://$hhostname:$rpcport/

rpcuser=$rrpcuser
rpcpassword=$rrpcpassword
rpcport=$rpcport

# The following settings will allow a connection from ANY external host. The two entries
# define that any IPv4 or IPv6 address will be allowed to connect. The default firewall settings
# also allow the traffic because the RPC port is open by default. If you are setting up a remote
# connection, all you will need is the above RPC credentials. No further network configuration
# is needed. To secure the node from repeated connection attempts or to restrict connections to
# your IP's only, change the following values as needed. The following example will work 
# locally, on this machine. You can try this curl example from another computer, just change the
# '$hhostname' value to the IP of this node.
#
# curl --user $rrpcuser:$rrpcpassword --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getblockcount\", \"params\": [] }' -H 'content-type: text/plain;' http://$hhostname:$rpcport/

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
#debug=0

# By default, wallet functions in LynxCI are disabled. This is for security reasons. If you
# would like to enable your wallet functions, change the value from '1' to '0' in the
# 'disablewallet' parameter. Then restart lynxd to enact the change. Of course, you can do the
# reverse action to disable wallet functions on this node. You can always check to see if
# wallet functions are enabled with '$ /root/lynx/src/lynx-cli help', looking for the
# '== Wallet ==' section at the bottom of the help file.
#
# If you change this value to '0' and someone knows your RPC username and password, all your 
# Lynx coins in this wallet will probably be stolen. The Lynx development team can not get your
# stolen coins back. You are responsible for your coins. If the wallet is empty, it's not a
# risk, but make sure you know what you are doing.

disablewallet=1

# The following list of nodes are maintained for faster detection of peers and network sync.
#
# curl --user $rrpcuser:$rrpcpassword --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getpeerinfo\", \"params\": [] }' -H 'content-type: text/plain;' http://$hhostname:$rpcport/

addnode=node01.getlynx.io
addnode=node02.getlynx.io
addnode=node03.getlynx.io
addnode=node04.getlynx.io
addnode=node05.getlynx.io
addnode=node06.getlynx.io
addnode=node07.getlynx.io
addnode=node08.getlynx.io
addnode=node09.getlynx.io
addnode=node10.getlynx.io
addnode=node11.getlynx.io
addnode=node12.getlynx.io
addnode=node13.getlynx.io

# curl --user $rrpcuser:$rrpcpassword --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getconnectioncount\", \"params\": [] }' -H 'content-type: text/plain;' http://$hhostname:$rpcport/

# The following addresses are known to pass the validation requirements for HPoW. If you would
# like to earn your own mining rewards, you can add/edit/delete this list with your own
# addresses (more is better). You must have a balance of between 1,000 and 100,000,000 Lynx in
# each of the Lynx addresses in order to win the block reward. Alternatively, you can enable
# wallet functions on this node (above), deposit Lynx to the local wallet (again, between 1,000
# and 100,000,000 Lynx) and the miner will ignore the following miner address values.

mineraddress=KKMeTYLM6LrhFc8Gq1uYSua4BLgmFPaZrX
mineraddress=KVKrkxGcUo9wii59ashrbqKub5CpggiFQz
mineraddress=KMPxdPMwJb3rn1dLx9L2xxxUgiZiGRC8Um
mineraddress=KERgGnd5vCMkdFbGynrGeqhBnitz1zrg22
mineraddress=KWJfZ9qQ4aAiieB9jh8iJk5ttxhWV566RU
mineraddress=KVaeY15ikttZM2rwBh694LPC1qZHgKvTsg
mineraddress=KA8VJVzqy7xo6AEYRxAa8WHLqqScwGHmGx
mineraddress=KJhTW2s2q1gvpaWLWSdmwLa9dvvqmAcnzj
mineraddress=KTT3d4obtRGdkyLeUQQk75VKkBavXcXcFn
mineraddress=KH5Lkvw511qAgUeoqxNa9BSGdZuok7q6ow
mineraddress=KJErWXjc4ycq436Tonf5dy8RFhF1SiuSM2
mineraddress=KRJf4FQB6GAk2E6dXeJ5osbd1GsHjW6mWf
mineraddress=KDjfv9bUfyfFfuVgyhTazreESRfHpYnMi3
mineraddress=KBywa5qcAZTB3CC7vCzxVeU8eYW6PBdSfJ
mineraddress=KU7tLLoa1geou57GWoEY7MXUpQNetRbuNy
mineraddress=K7XNmz2h2PgyGC8aYhXHJ8W58WnjZgrU85
mineraddress=KT4nWz8PEAyAiBQTXu6T9z7TZCe5h2pUep
mineraddress=KG5unFERmH6Qsvt3muci4ZeKgtmUaw7TdQ
mineraddress=KRgVAxFgfjkYKovizRG1DfkLKd59rpEHxe
mineraddress=KMoRtp69iMVVSWUPVwdota6HSCkP2yChFH
mineraddress=KNcAXmZY9CKUesky2dRbKWJM5PZwQmUNYk
mineraddress=KSX55i4ef1y1kYtHu6E7EUt7Fx4GAg9yzm
mineraddress=K8QGUNxc86Ahr9CSW1NyT2LGDC8BAUk6iM
mineraddress=KRgVAxFgfjkYKovizRG1DfkLKd59rpEHxe
mineraddress=KMoRtp69iMVVSWUPVwdota6HSCkP2yChFH
mineraddress=KNcAXmZY9CKUesky2dRbKWJM5PZwQmUNYk
mineraddress=KR9QTmep2LYt53oS9Ypn7Qo6mjd9jNMvw5
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
# Added March 18, 2019
mineraddress=KCEtXtUd3H8bG7Jn7FCLuEhNdVvD5AbDVf
mineraddress=K9aVTZzPRwuVD7k3oELGh2aDKcF95kjEN1
mineraddress=KAaaYX5rXaSJstmszDEJgxAYjx655CctoE
mineraddress=KQVjEoCtKfB2KRQCrpL91NxokdmosJAWSH

# It is highly unlikely you need to change any of the following values unless you are tinkering
# with the node. If you do decide to tinker, make a backup of this file first.

listen=1
daemon=1
port=$port
rpcworkqueue=64
listenonion=0
upnp=1
#dbcache=100
txindex=1
host=$hhostname

# Our exchange and SPV wallet partners might want to disable the built in miner. This can be 
# easily done with the 'disablebuiltinminer' parameter below. As for our miners who are looking
# to tune their devices, we recommend the default 0.01 (1%), but if you insist on increasing the 
# amount, we recommend you not tune it past using 50% of your CPU load. This often means setting 
# the 'cpulimitforbuiltinminer' value no greater then 0.3 (30%). Remember, with HPoW, increasing
# the mining speed does not mean you will win more blocks. You are are just generating heat, 
# not blocks, if you increase the 'cpulimitforbuiltinminer' value. Also, if you are using a VPS
# like AWS or Linode, your node will get banned and shut down if they detect mining activity.
# Best to keep it low.
#
# curl --user $rrpcuser:$rrpcpassword --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getmininginfo\", \"params\": [] }' -H 'content-type: text/plain;' http://$hhostname:$rpcport/

#disablebuiltinminer=1
#cpulimitforbuiltinminer=0.01
" > /root/.lynx/lynx.conf

	if [ "$rpcport" = "19335" ]; then

	# Since this is testnet, let's purge those mainnet mineraddress values.
	sed -i '/mineraddress=K/d' /root/.lynx/lynx.conf

	sed -i '/addnode=node/d' /root/.lynx/lynx.conf

	echo "
# The following list of nodes are maintained for faster detection of peers and network sync.
#
# curl --user $rrpcuser:$rrpcpassword --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getpeerinfo\", \"params\": [] }' -H 'content-type: text/plain;' http://$hhostname:$rpcport/
# curl --user $rrpcuser:$rrpcpassword --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getconnectioncount\", \"params\": [] }' -H 'content-type: text/plain;' http://$hhostname:$rpcport/

addnode=test01.getlynx.io
addnode=test02.getlynx.io
addnode=test03.getlynx.io
addnode=test04.getlynx.io
addnode=test05.getlynx.io
addnode=test06.getlynx.io

# All testnet coin public addresses start with am M or a N. Mainnet coins, the one's that 
# are publicly traded and used always start with a K. If you would like to take coins from any
# of these addresses, be sure to send at least 1 coin back the original address so it will
# still meet HPoW Rule 2 with it's minimum balance requirement.

testnet=1

# Private key for the below address: cUYQ4bvyzUy2gAzSf79hUPqEasuziKYzSpRaifAXM2zb5Y6X5gQD
mineraddress=mvAqk6Q9ABF91TaAKsDhauym1MNuaj6ZzL

# Private key for the below address: cUNsqZjzywvZPLcUvso8d1FixiJZc7aX1iLfEB9BHqVxRGdz7tuz
mineraddress=mzKEf2fzK5WYTUM3ZffQQKtGXbuBSyQbXL

# Private key for the below address: cMppJ2yBU918qiwYo9aEhgqKiDK45TLSoEid8s7XBdajE8ZrZwmS
mineraddress=mo5Nvd6GJHN696NJ1NmXj4b6RHoig1NEV9

# Private key for the below address: cVGvDcvdm6gmRDqR5BQwbhdcj6eNMLJNkjwaKEq3YNkj9sv5Q3Lr
mineraddress=mh6KV4wKbm5pmG6Y6LTT1A9DeXziUafsP4

# Private key for the below address: cTGFEfAbu7Q8fr7hvkWWzRxPANWT76quFCazris5V7ojkQggUCTp
mineraddress=mgX7cXxob5DNAJgu1UrpAgLGfa4FnfSCVj

# Private key for the below address: cNuUkW32HkYqenNV5FV51PRKejCPYK3PZ2YpkqndaMDvJEpwTZ2G
mineraddress=mgriF5mgsuyvnh3f9QNwFHR9qDwgYfEjZP

# Private key for the below address: cW8Nt4N7QcK1K1g6igrYRR4QBzagujFSNJ7dDcMpUkGWEyaGTJL8
mineraddress=n3wKyoCcpcE4x8oo3hvJU1drgi7QTVEcrf

# Private key for the below address: cU8wXQWXbAbfrhGSM6raX2wWhxisHC5oiwWQyzr2mRdKvzdKQ643
mineraddress=myJwCi7nBLv5wUyXz3ZFq15hnGVtHa7tun

# Private key for the below address: cR97VSALAiZPLL9GwcQajP45crGajfxrcPyucZgnrvPZD4Zfu5UP
mineraddress=n1j2L3tncm8Prc3oQmtgKKjERUEr1x3uDK

# Private key for the below address: cTKf8NYhWksuWsHmNxfcHUN2TCkv6YNkk8ekpAGyqhLvtuV6Kfmc
mineraddress=mhuwHPSWKBaHSaWMjuU7m5TbzG3j75amTw

# Private key for the below address: cQD2PkGkjrCGywyMU5331xxvHbNWgcvByK4X8gU1bST5dMfGzpaB
mineraddress=mtp2CyLf7kBfBjEfBjnsdt3x6kv7CWkWTe

# Private key for the below address: cRMyr2RHhbF1FKARiwoDWBh8pQLC2KrRRRSLztLioT97XU1cegYA
mineraddress=mmQxpEVVp7bBXfkF2dVkGCWxaX5dxt2vR5

# Private key for the below address: cVB7cPJiWUCP72J39EZjJ6k1T4FSH5u8LrMKfk5YqyrbxiZwChcb
mineraddress=mgDHQbZHUU2YCx3wpF6gjvND7UPSmYUEgc

# Private key for the below address: cN9JnwhNDiTY1f3UaY5F7jeiEfnv3tWCVBp6GfZq43HnT2NH5R7e
mineraddress=mfmXw6tnWuMPPAPEqFeakodw3nwJoyYw71

# Private key for the below address: cVXzDVfw4mW3tVWepek35ENXNnp1X6NiNgnm2pJpvQA3tPY3pwiL
mineraddress=mhuP1zXXsBb5AbGgX5H4veTYM8RgkpshJv

# Private key for the below address: cQBVDLHgSyxbvxWApQXHDTaLwApsNx4NLCofWGjSrFCPq96Qyfec
mineraddress=mnRyuThfF2YF4kbtVXWFXgX9knhfFQzBoB

# Private key for the below address: cVwrj2tnSLLaMvF2r5UPtq53DnXkhPmZhjUn8yXZX3WyNv9Z3Z5p
mineraddress=mmfspxuCpe5getSthHFrorK4YJE9MoxHFE

# Private key for the below address: cSNJbVb2LdspWQVWB6H1VpMwHLDv7DzWx7bfb9uQPAWnXD712tCH
mineraddress=n4CkrFFcYSRtazYSw1MYJ1dYUQSN2jpe3P

# Private key for the below address: cQSzmvtszC8hratBG1Wdyv2QUd9xXPALEkpqU7g7xu66YAcr1QQD
mineraddress=mphs8iML38DhsbB1qx4D8kxLgQvjYubKvc

# Private key for the below address: cVXHFRAw8qEYvxzU4trU8tWWqVo93E2T287mJou6nUhbHBB1C28k
mineraddress=mindpMbbrNEE6Ap15G7PSAQaJsaFsydvEt

# Private key for the below address: cW3otbFXUy7dCwGsA1wsM2yTnJsEo4djXDFXiVab6Tk2Zv4dxfMX
mineraddress=mkUh7tjREvdL9zK9SeLs4mVhhTLcffk82k

# Private key for the below address: cSRMwRnrtXjee1SewUNuwD468WfP8kUvj8iruerRpnBQNzoynS4f
mineraddress=msfDHvn2L5TSqFZYCq3EerxzHtbFZ4cBpE

# Private key for the below address: cR8ZQpFF9yq2BXRCN7xxL3EYYsGczS51tpRBkvFNjRdPe3d1jWuk
mineraddress=miMWN96feXFA4a4fktA68xscZPeXBqvHsc

# Private key for the below address: cU1farVJJ56mYv8RJzVuwqFuFPwPwKSMtpstaujBYrBDWNisJ62u
mineraddress=mvrMeLhELTCaXkmo7r8XccEMGa6ppKqiUb

# Private key for the below address: cScYkvYV8m9Xbr8nYpb6F4n6D15HLzVTR9ZUeKazk9oW4NoJpism
mineraddress=mu3fpDNWjCTMaAGtnoJVKpwbZtoRkasphJ

# Private key for the below address: cNzX2wv65SxE5c1VeRc7FYAxXY6qnwgsyv3fcMZvwiGkdhKeDNTX
mineraddress=ms6W9vmqT5NDw6vdmT31yLEo7TwCm3cgVh

# Private key for the below address: cSf99ZpsiQNP2WMm5zo6WefBnRX1V1Kxaguco3jsdx3U1kzLgqXi
mineraddress=mxJC8oiLbsSRhmSCgcBWpahC2eyZU1W7qs

# Private key for the below address: cN3LdHXGZy2ANNP221Tbm7uoG7AGBgvz6doPuERVsg6W5DwxZZ6p
mineraddress=mpniFaj9a8L6332TpjoWArcso5cTRFgJHd

# Private key for the below address: cScdbYMYAD8zYFfX9VxVbmkg61oDV64vUTxAL9zvSGLpRwduVWmC
mineraddress=mydYEwnf6s2BRWLVA7dYPmVLvK2PcdTkDt

# Private key for the below address: cQQNxD6CZ8CrinW4Eq3wrXuCuX6Ccaws6LTDD1c64YXYngyyp86f
mineraddress=mhZtewGZTJw2ewWHufFa7ZCkrz4jeWVmD9

# Private key for the below address: cMyyArq6kzXBb4L9jKWLkANqfaMmchjobyMGdYANdu935Hv7RBMu
mineraddress=mqVPvnrkCvSkKnR3KPeVk3LcnWf6rvRAPe

# Private key for the below address: cRyYu5mHXrDzGqQpbeW2ksTPJcwdodqJyej3KsqxFvFQhsqCQTHx
mineraddress=mvfi4LZxMDdPzT9PnDuxyKsK63a1ybSZUf

# Private key for the below address: cVMinxvyGjv943184JcNbY1zzjkuTScLYfm6k4QG2f4wVeArN4HT
mineraddress=muzoQBrL1T4tyCALtsapWJY76ertjZhuow

# Private key for the below address: cTMdGYJ8Wm8f8cfhAxSERecTt8wj4KcNvqk88G9uihmufyZaiVRR
mineraddress=mjucNa4ZS5QD5TD8WzZv7CHze3wLLneK84

# Private key for the below address: cV1YnJrcM8gUg2g81HMgbZXCLdPUBSyWK3ZQXpsmNpiZo5DeJLT5
mineraddress=mg4oSdwnD2MNJ4JW5a2qYWrk7FHQUypHJf

# Private key for the below address: cURgVN4gUfBHVd9eFsnqWyqRWJrQep6SRg8AsBjv9F8mUUgNLNQL
mineraddress=mqkMYkskQ7DiFf57FmfvWJoiSNUG5uBfUJ

# Private key for the below address: cTLxyQq95fPWV7q3NpAg25nCcuo9acmg25PK9Cc6WDHcfbqrj9mU
mineraddress=mgMs2dY1Tx1wYJTEsUhJwja9n8xcyoNUbv

# Private key for the below address: cQVCzmtp9qF4aQChoJkjrsVZn1bM4NgPezQeQLP1PQ3FQt8JxjW8
mineraddress=mv4m5GWongwdX43sjN9HTQwcpuPq9gfmKM

# Private key for the below address: cT6TKiBpwWC191damceRu31NjyqA9KhVUSBEPZtjRkN6ntDbCqoK
mineraddress=mqwyDHhvDb3nNWYdRrT7JJxK3uf2ciMWyy

# Private key for the below address: cNefKgDW18N3aeondGVaRMEjfEyZvzejFAD7KCnthECMtSeNtZb9
mineraddress=mtfxpRruFQxC958vScDrW34WnAao7g45Nc

# Private key for the below address: cRXzXq3on3gKmZgGcftbj7JZeGSfpjR38abdgKBi1hyiucsKaXVs
mineraddress=mj84VsKaDCf1bXJkSVLNoM68mMPzg59dQW

# Private key for the below address: cQyUrfhCiU8rp1mcv4eQfAdTwZVXvj7N21kZEX52TcELS5FDAL2p
mineraddress=mhUhvRLRmbFvsBsA2Eo7r2wa779YoxRFbj

# Private key for the below address: cSLtUJZYZ5aPCNNvTTuXBPy94Mr49iBgzfXqiRcZb6BPTJycMM1g
mineraddress=mzdykDkMfSdeidP7acpUbhcVfFtVTMg5DB

# Private key for the below address: cP3z7fvNG3yoeiYpBeoqDWa1qzYHsDPZ2eDRjLzMf7wcFGDNtu1P
mineraddress=n1gS6tDmcMuWoTeCbRFdQzfAhKYjaxnTHj

# Private key for the below address: cT14ZwS1Zsfz19CBAxPKk4dfNM1shtC2jHcepUTYcj3qRqeoNbsD
mineraddress=mmYxH7a3qtrQyhCyK1nBqctSLgiSyfd9vt

# Private key for the below address: cNCf7DECtWD7ysj4kqARUobvqjE1FBvzN8Hfq3bgoHjvPyVVEr93
mineraddress=mizWLQTrBcAhp8fmYp9qwepLWEx7MfRLyv

# Private key for the below address: cPBSQabsG33RS9AL8j6VAgF7veYtUVbySFKXen3qoh7bbpsYVEEs
mineraddress=mzwp37KxEDfKZfQm6LxRS7nkxrZAcgUrqS

# Private key for the below address: cPM7st6TpGFKxJkb7xmvMjuv2HYpLs8FbDeGW7KtswpM1RK4FF5k
mineraddress=mt7zphoNE3U1NsQEcN1miwpCVqrppDEoib

# Private key for the below address: cS9cxEjPkjYAhEBrYcmxRiVJQYFJ2sDc6s2JYrYwrkmi1LYeY15D
mineraddress=mg9WCFUUB7uVTEzJVfD3fi3kUnzZdUFMqU

# Private key for the below address: cURaQQjK8ZDjhEmYKpRy2jani6cjCd2JtUynDehKd1btnXG1znTE
mineraddress=mxqG7ioQGjowKoTUKy7ndoH2RKU8cv8JYt

# Private key for the below address: cVcJpgFFXcM99xq6BWxWozsg5vz7fm1GgcXvoYuwCybArrMQxsHk
mineraddress=mrkoa8hEXKfWiWmYgJAzStQCUjxgUvhQQW

# Private key for the below address: cQYGrYDG1GRxyNtdK54rDquf2YojLwTr67Pxa9AreUYq6v5cAMxt
mineraddress=mh4hFG8Bt6iWkiZP8mBmZxCNSKd4AZLJDE

# Private key for the below address: cRJMKmRwaJn6z4EPqamFgqWoWLp6rcgsyB8xKNe1juAsLi3zsE91
mineraddress=mkcEyefPiV2LXmiAsJxtnCw4ZEhLWsnwN1

# Private key for the below address: cS8LE8NkY4FCcDUKgX2frNApVaqKP3KJJpLnioAANkYWb4NR9LLe
mineraddress=mwEPbNRxsaNfgQmPHYcfU9CHo2Ux5QRc1x

# Private key for the below address: cUkvh4sDUXHrXmfmZYY2oUJmfPc1rRhF8Btb9tfWt3FT47KxBokY
mineraddress=mr9JzWDH6s7cJuAdZHhoKrH9aWo5dmYLW3

# Private key for the below address: cPwq3wr1x2mQD5NzkTXkhNVz6SkMdxss3AiVy3NWiC3u7isbpnav
mineraddress=mh3ReeQk5XhF6cpw2TexQVZbtND1mFBU5Q

# Private key for the below address: cVhhRkAGHFpvH2yxLjtzeJpGEp7tB8SmXiYxV7MazAp8zKi7xsj1
mineraddress=mvbRLcu2xX31pGPbfL8yV6t4JNUf4sQHgc

# Private key for the below address: cSE4c2zoa8XCTXjLDcrRWWPEHehM6qoS5v5647jiVkQboyCqKdtn
mineraddress=mmnwg2spU3DQVhVuBpTCsKd2jC4tAFk2xg

# Private key for the below address: cTcBgsx9g4oVZSKTgsmCT4TmCKz5Y2Kat4LDnrGxLkxWju67L6Ws
mineraddress=mtiReGFHm1i6LpUZ54eQAY1jojGPBuQBwP

# Private key for the below address: cNd2yuK5T246doYKwdtCTbnAqdZg4sx69vKgcBZ4gNWdZYg6GERM
mineraddress=mtHtim5hxsCPq6vkytVtFJzYiTYRDFVXwT

# Private key for the below address: cPDCDc9bp88jitpZNA3Va7geEqatmRbDsAa86DQNPwB9woVHjuVA
mineraddress=mq6dunoC4sPPJnBgoUyZEz3ihHNe5wGmkq

# Private key for the below address: cMtkabnJKiN7T4ma1Moq4mxdGaBKKB5wiJ8JsMfgE5VUsntGwFKW
mineraddress=mnPb788WQyQRK8Qp83URpS2bD2noVGJEQz

# Private key for the below address: cSHDivWZwoa3jiQDFBF5EWwfYXtpsQVfJtNEaKLeRRi3z16rQjWJ
mineraddress=mrZcAGQdffwtuBkjUSyzK7wzqMfrgrF4BC

# Ineviably someone is gonna think themselves a smarty pants and sweep all the above addresses,
# thus possibly forcing the above addresses to fail HPoW Rule 2. This means the testnet network
# could run the risk of getting stuck, since it's not widely supported with lots of installs.
# Here are some addresses with privkey keys destroyed. The coins the following addresses earn
# therfore get burned as they become unspendable, but their existence supports HPoW on testnet.

mineraddress=miVEdh1sWTM2TQr24hHhjW1Q77QQQHUAGH
mineraddress=mzVR6YdZRUhaB872BH5SR8rPXsYtCrRqRV
mineraddress=mwFFHvixYABGVQ6G2csVqwzfMYd6VQcvWe
mineraddress=myKe9zSDqLWGJZufjXEfjBuWo61Ks4Lg3v
mineraddress=mxV4B4niYHmkxBBmawtHBnUQyHJG11g9Gk
mineraddress=mo9hxMnMQUcqAEXTqovMeEdJ4wmvswkH6t
mineraddress=mmQ7HjBLideqDKP5fqpY2oiRPC2pBYjnxt
mineraddress=mvxVyK2LJ41Cv4vm8yHZ8Xw534oRGaiH2Z
mineraddress=mstUwkrcdTAChLymymgFB4h4ibyBTkKMWD
mineraddress=mtN9c9TeazxLw5uPSR6mW6zwABPbmaEHpL
mineraddress=myCqSH8dfZ9EXBQPZgHnK9VF43nvpWkcyw
mineraddress=mxqyFrJ6DYQ5CPjptdX9jXLMP4npa6SyCx
mineraddress=mnYqYpN6gKMzhG2rrfFp6UYZZzazujc6Bu
mineraddress=mnenfD8DYmHwxaQ2mnZQR2XfcP8YzfTfM2
mineraddress=mpMyprNfY5Kz9E175bnQN85B1pMq3ATroc
mineraddress=mxMAArTr3hHYfbV2YUoxFdVTkMTNoUadWF
mineraddress=miuWJcdonyEryZUmuFHKrpnsEhc8VTvstS
mineraddress=mmbtJrLVv76EvJ8hQiMMoeLD3r1USf2vWN
mineraddress=mrFXqummwGAi7w6saCEGixr3v1RSbzSgrj
mineraddress=msNfqB4G4r9iV4jBQZmaQBbkbPcVELBdTs
mineraddress=mmhAk3VqPJqrsv1utCZGWKNnXWE52pgAxt
mineraddress=mxfdwQjFsBmTFC2RP5CeqQLNfP3rA9R7Cj
" >> /root/.lynx/lynx.conf

	fi

	# On the Pi, the dbcache param has value. The limited RAM environment of the Pi means we should
	# store less data about the chainstate in RAM. We can reduce the about of RAM used my lynxd with
	# this param. Default is 450MB.

	if [ ! -z "$checkForRaspbian" ]; then

		sed -i "s|#dbcache=100|dbcache=100|g" /root/.lynx/lynx.conf

	fi

	# We are gonna create a backup of the initially created lynx.conf file. This file does not ever
	# run, it is just created for backup purposes. Please leave it intact so you can refer to it in
	# the future in case you need to restore a parameter or value you have previously edited.

	cp --remove-destination /root/.lynx/lynx.conf /root/.lynx/lynx.default

	chmod 600 /root/.lynx/lynx.conf
	chmod 600 /root/.lynx/lynx.default

	# Only download the bootstrap files for mainnet.

	if [ "$environment" = "mainnet" ]; then

		wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.6/bootstrap.tar.gz -O - | tar -xz -C /root/.lynx/

	fi

	# Be sure to reset the ownership of all files in the .lynx dir to root in case any process run
	# previously changed the default ownership setting. More of a precautionary measure.

	chown -R root:root /root/.lynx/*

	echo "Lynx was installed."

}

config_firewall () {

	sed -i "s/_port_/${port}/g" /root/LynxCI/installers/firewall.sh
	
	sed -i "s/_rpcport_/${rpcport}/g" /root/LynxCI/installers/firewall.sh

	crontab -r

	crontab -l | { cat; echo "@daily		/root/LynxCI/installers/firewall.sh"; } | crontab -
	
}

restart () {

	# We now write this empty file to the /boot dir. This file will persist after reboot so if
	# this script were to run again, it would abort because it would know it already ran sometime
	# in the past. This is another way to prevent a loop if something bad happens during the install
	# process. At least it will fail and the machine won't be looping a reboot/install over and
	# over. This helps if we have to debug a problem in the future.

	/usr/bin/touch /boot/ssh

	/usr/bin/touch /boot/lynxci

	/bin/rm -rf /root/setup.sh
	/bin/rm -rf /root/LynxCI/setup.sh
	/bin/rm -rf /root/LynxCI/init.sh
	/bin/rm -rf /root/LynxCI/README.md
	/bin/rm -rf /root/LynxCI/install.sh

	echo "LynxCI was installed."

	echo "A reboot will occur 10 seconds."

	sleep 10

	reboot

}

# First thing, we check to see if this script already ran in the past. If the file "/boot/ssh"
# exists, we know it previously ran.

if [ -f /boot/lynxci ]; then

	echo "Previous LynxCI detected. Install aborted."

else

	echo "Starting installation of LynxCI."

	detect_os
	/root/LynxCI/installers/package.sh
	set_network
	manage_swap
	reduce_gpu_mem
	disable_bluetooth
	/root/LynxCI/installers/account.sh
	install_portcheck
	install_miniupnpc
	install_lynx
	/root/LynxCI/installers/nginx.sh
	setup_nginx
	config_firewall
	/root/LynxCI/installers/systemd.sh
	/root/LynxCI/installers/logrotate.sh
	restart

fi

