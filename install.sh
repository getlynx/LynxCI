#!/bin/bash

environment="mainnet"
port="22566"
rpcport="9332"
lynxbranch="master"
explorerbranch="master"
explorer="https://explorer.getlynx.io/api/getblockcount"
setupscript="IsProduction=Y"

detect_os () {

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

install_packages () {

	apt-get -qq update -y

	apt-get -qq install -y autoconf automake build-essential bzip2 curl fail2ban g++ gcc git git-core htop libboost-all-dev libcurl4-openssl-dev libevent-dev libgmp-dev libjansson-dev libminiupnpc-dev libncurses5-dev libssl-dev libtool libz-dev make nano nodejs pkg-config software-properties-common

	apt-get -qq autoremove -y

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

	# On a Raspberry Pi 3, the default swap is 100MB. This is a little restrictive, so we are
	# expanding it to a full 1GB of swap.

	sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile

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

set_accounts () {

	# We don't always know the condition of the host OS, so let's look for several possibilities. 
	# This will disable the ability to log in directly as root.

	sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

	sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' /etc/ssh/sshd_config

	# The new LynxCI username and default password.

	ssuser="lynx"

	sspassword="lynx"

	adduser $ssuser --disabled-password --gecos ""

	echo "$ssuser:$sspassword" | chpasswd

	adduser $ssuser sudo

	# We only need to lock the Pi account if this is a Raspberry Pi. Otherwise, ignore this step.

	if [ ! -z "$checkForRaspbian" ]; then

		# Let's lock the pi user account, no need to delete it.

		usermod -L -e 1 pi

		echo "The 'pi' login was locked. Please log in with '$ssuser'. The default password is '$sspassword'."

		sleep 5

	fi
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

        if [ ! -z \"\$(curl -s http://127.0.0.1/api/getblockcount)\" ]; then

        echo \" | The current block height on this LynxCI node is \$(curl -s http://127.0.0.1/api/getblockcount).                    |
 '-----------------------------------------------------------------------------'\"

        fi

        echo \" | The unique identifier for this LynxCI node is $hhostname.                |
 '-----------------------------------------------------------------------------'\"

 	port=\"$port\"

	if [ \"\$port\" = \"44566\" ]; then

        echo \" | This is a non-production 'testnet' environment of Lynx.                     |
 '-----------------------------------------------------------------------------'\"

	fi

    echo \" | Visit https://help.getlynx.io/ for more information.                        |
 '-----------------------------------------------------------------------------'\"

" > /etc/profile.d/portcheck.sh

	chmod 755 /etc/profile.d/portcheck.sh

	chmod 755 /etc/profile.d/logo.txt

	chown root:root /etc/profile.d/portcheck.sh

	chown root:root /etc/profile.d/logo.txt

}

install_explorer () {

	# Let's jump pack to the root directory, since we can't assume we know where we were.

	cd ~/

	# Let's not assume this is the first time this function is run, so let's purge the directory if
	# it already exists. This way if the power goes out during install, the build process can
	# gracefully restart.

	rm -rf ~/LynxBlockExplorer

	echo "Any previous install of LynxBlockExplorer was removed."

	rm -rf ~/.npm-global

	# We might need curl and some other dependencies so let's grab those now. It is also possible
	# these packages might be used elsewhere in this script so installing them now is no problem.
	# The apt installed is smart, if the package is already installed, it will either attempt to
	# upgrade the package or skip over the step. No harm done.

	curl -sL https://deb.nodesource.com/setup_10.x > setup_10.x

	chmod +x setup_10.x

	./setup_10.x

    apt-get -qq install -y nodejs build-essential libssl-dev

    apt-get -qq autoremove -y

    echo "NodeJS was installed."

	npm install pm2 -g

	echo "PM2 was installed."

	git clone -b $explorerbranch https://github.com/doh9Xiet7weesh9va9th/LynxBlockExplorer.git

	cd /root/LynxBlockExplorer/

	npm install

	# We need to update the json file in the LynxBlockExplorer node app with the lynxd RPC access
	# credentials for this device. Since they are created dynamically each time, we just do
	# find and replace in the json file.

	sed -i "s/9332/${rpcport}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__HOSTNAME__/x$(cat /etc/hostname)/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__MONGO_USER__/x${rrpcuser}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__MONGO_PASS__/x${rrpcpassword}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__LYNXRPCUSER__/${rrpcuser}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__LYNXRPCPASS__/${rrpcpassword}/g" /root/LynxBlockExplorer/settings.json

	# On Raspian, sometimes the pm2 service shows a benign warning during boot, prior to the first
	# command prompt. This replacement fixes the issue, avoiding the unneeded warning.

	sed -i 's/User=undefined/User=root/' /etc/systemd/system/pm2-undefined.service

	# Since we provide a download file for the setup of other nodes, set the flag for the env.

	sed -i "s/IsProduction=N/${setupscript}/g" /root/LynxCI/setup.sh

	# Yeah, we are probably putting to many comments in this script, but I hope it proves
	# helpful to someone when they are having fun but don't know what a part of it does.

	echo "Lynx Block Explorer was installed."
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

	apt-get -qq install autoconf automake bzip2 curl nano htop make g++ gcc git git-core pkg-config build-essential libtool libncurses5-dev software-properties-common libssl-dev libboost-all-dev libminiupnpc-dev libevent-dev -y

	rrpcuser="$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)"

	rrpcpassword="$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)$(shuf -i 1000000000-3999999999 -n 1)"

	rm -rf /root/lynx/

	git clone -b "$lynxbranch" https://github.com/doh9Xiet7weesh9va9th/lynx.git /root/lynx/

	#make -C /root/lynx/depends

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

	make install

	# Now that the Berkeley DB is installed, let's jump to the lynx directory and finish the
	# configure statement WITH the Berkeley DB parameters included.

	cd /root/lynx/

	./autogen.sh

	# If it's a Pi device then set up the uPNP arguments.

	if [ ! -z "$checkForRaspbian" ]; then

		cd /root/lynx/

		./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --enable-cxx --without-gui --disable-shared --with-miniupnpc --enable-upnp-default --disable-tests --disable-bench

		make

	else

		cd /root/lynx/

		./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --enable-cxx --without-gui --disable-shared --disable-tests --disable-bench

		make

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

	cp /root/lynx/src/lynxd /root/lynx/src/$hhostname

	sed -i "s/lynxd/${hhostname}/g" /root/LynxCI/explorerStop.sh
	sed -i "s/lynxd/${hhostname}/g" /root/LynxCI/explorerStart.sh

	# Below we are creating the default lynx.conf file. This file is created with the dynamically
	# created RPC credentials and it sets up the networking with settings that testing has found to
	# work well in the LynxCI build. Of course, you can edit it further if you like, but this
	# default file is the recommended start point.

	echo "

	# The following RPC credentials are created at build time and are unique to this host. If you
	# like, you can change them, but you are encouraged to keep very complex values for each. If an
	# attacker gains RPC access to this host they might be able to steal your Lynx. Understanding
	# that, the wallet is disabled by default so the risk of loss is zero.

	rpcuser=$rrpcuser
	rpcpassword=$rrpcpassword
	rpcport=$rpcport

	# The following settings will allow a connection from any external host. The two entries
	# define that any IPv4 or IPv6 address will be allowed to connect. The default firewall settings
	# also allow the traffic because the RPC port is open by default. If you are setting up a remote
	# connection, all you will need is the above RPC credentials. No further network configuration
	# is needed. To secure the node from repeated connetion attempts or to restrict connections to
	# your IP's only, change the following values as needed.

	rpcallowip=0.0.0.0/24
	rpcallowip=::/0

	# The debug log (/root/.lynx/debug.log) is capable of outputing a massive amount of data. If you
	# are chasing a bug, set the argument to 'debug=1'. It isn't recommended to leave that log level
	# intact though. The default state of this build is to output the BuiltinMiner info, so if you
	# don't want to see it, you can change the argument to 'debug=0'. We think the BuiltinMiner info
	# is fun though, but on a Pi, to reduce SD card writes, it might be most efficient to go with
	# the least amount of debug info, so change it to 'debug=0'.

	debug=miner

	# By default, wallet functions in LynxCI are disabled. This is for security reasons. If you
	# would like to enable your wallet functions, change the value from '1' to '0' in the
	# 'disablewallet' parameter. Then restart lynxd to enact the change. Of course, you can do the
	# reverse action to disable wallet functions on this node. You can always check to see if
	# wallet functions are enabled with '$ /root/lynx/src/lynx-cli help', looking for the
	# '== Wallet ==' section at the bottom of the help file.

	disablewallet=1

	# The following list of nodes are maintained for faster detection of peers and network sync.

	addnode=node01.getlynx.io
	addnode=node02.getlynx.io
	addnode=node03.getlynx.io
	addnode=node04.getlynx.io
	addnode=node05.getlynx.io

	# The following addresses are known to pass the validation requirements for HPoW. If you would
	# like to earn your own mining rewards, you can add/edit/delete this list with your own
	# addresses (more is better). You must have a balance of between 1,000 and 100,000,000 Lynx in
	# each of the Lynx addresses in order to win the block reward. Alternatively, you can enable
	# wallet functions on this node, deposit Lynx to the local wallet (again, between 1,000 and
	# 100,000,000 Lynx) and the miner will ignore the following miner address values.

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

	# It is highly unlikely you need to change any of the following values unless you are tinkering
	# with the node. If you do decide to tinker, make a backup of this file first.

	listen=1
	daemon=1
	port=$port
	rpcbind=127.0.0.1
	rpcbind=::1
	rpcworkqueue=64
	listenonion=0
	upnp=1
	dbcache=100
	txindex=0
	host=$hhostname

	" > /root/.lynx/lynx.conf

	chown -R root:root /root/.lynx/*

	echo "Lynx was installed."

}

install_mongo () {

	if [ "$version_id" = "9" ]; then

		if [ -z "$checkForRaspbian" ]; then

			echo "LynxCI running on Raspbian GNU/Linux 9. Visit https://getlynx.io to learn more!" > /etc/issue

			echo "$pretty_name detected. Installing Mongo 4.0."

			apt-get -qq install dirmngr -y

 			apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

 			echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.0 main" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

 			apt-get update -y && apt-get -qq install -y mongodb-org

			systemctl start mongod && systemctl enable mongod

			sleep 5

			account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

			mongo lynx --eval "db.createUser( ${account} )"

			echo "Mongo 4.0 was installed."

		else

			echo "LynxCI running on Raspbian GNU/Linux 9. Visit https://getlynx.io to learn more!" > /etc/issue

			echo "$pretty_name detected. Installing Mongo."

			apt-get -qq install mongodb-server -y

			service mongodb start && service mongodb enable

			sleep 5

			account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

			mongo lynx --eval "db.addUser( ${account} )"

			echo "Mongo 2.4 was installed."

		fi

	elif [ "$version_id" = "8" ]; then

		echo "LynxCI running on Raspbian GNU/Linux 8. Visit https://getlynx.io to learn more!" > /etc/issue

		echo "$pretty_name detected. Installing Mongo 4.0."

		apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

		echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/4.0 main" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

		apt-get -qq update -y && apt-get -qq install -y mongodb-org

		systemctl start mongod && systemctl enable mongod

		sleep 5

		account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

		mongo lynx --eval "db.createUser( ${account} )"

		echo "Mongo 4.0 was installed."

	elif [ "$version_id" = "16.04" ]; then

		echo "$pretty_name detected. Installing Mongo 4.0."

		apt-get -qq update -y

		sleep 5

		apt-get -qq install apt-transport-https -y

		apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

		echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

		apt-get -qq update -y && apt-get -qq install -y mongodb-org

		echo "

		[Unit]
		Description=High-performance, schema-free document-oriented database
		After=network.target
		Documentation=https://docs.mongodb.org/manual

		[Service]
		User=mongodb
		Group=mongodb
		ExecStart=/usr/bin/mongod --quiet --config /etc/mongod.conf

		[Install]
		WantedBy=multi-user.target

		" > /lib/systemd/system/mongod.service

		systemctl daemon-reload && systemctl start mongod && systemctl enable mongod

		sleep 5

		account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

		mongo lynx --eval "db.createUser( ${account} )"

		echo "Mongo 4.0 was installed."

	elif [ "$version_id" = "18.04" ]; then

		echo "$pretty_name detected. Installing Mongo 4.0."

		apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

		echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

		apt-get -qq update -y && apt-get -qq install -y mongodb-org

		systemctl start mongod && systemctl enable mongod

		sleep 5

		account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

		mongo lynx --eval "db.createUser( ${account} )"

		echo "Mongo 4.0 was installed."

	fi

}

setup_crontabs () {


	/root/LynxCI/explorerStop.sh

}

set_firewall () {

	# To make sure we don't create any problems, let's truly make sure the firewall instructions
	# we are about to create haven't already been created. So we delete the file we are going to
	# create in the next step. This is just a step to insure stability and reduce risk in the
	# execution of this build script.

	rm -rf /root/firewall.sh

	echo "

	#!/bin/bash

	IsRestricted=Y

	# Let's flush any pre existing iptables rules that might exist and start with a clean slate.

	/sbin/iptables -F

	# We should always allow loopback traffic.

	/sbin/iptables -I INPUT 1 -i lo -j ACCEPT

	# This line of the script tells iptables that if we are already authenticated, then to ACCEPT
	# further traffic from that IP address. No need to recheck every packet if we are sure they
	# aren't a bad guy.

	/sbin/iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

	# If the script has IsRestricted set to Y, then let's open up port 22 for any IP address. But if
	# the script has IsRestricted set to N, let's only open up port 22 for local LAN access. This means
	# you have to be physically connected (or via Wifi) to SSH to this computer. It isn't perfectly
	# secure, but it removes the possibility for an SSH attack from a public IP address. If you
	# wanted to completely remove the possibility of an SSH attack and will only ever work on this
	# computer with your own physically attached KVM (keyboard, video & mouse), then you can comment
	# the following 6 lines. Be careful, if you don't understand what you are doing here, you might
	# lock yourself from being able to access this computer. If so, just go through the build
	# process again and start over.

	if [ \"\$IsRestricted\" = \"N\" ]; then

		/sbin/iptables -A INPUT -p tcp --dport 22 -j ACCEPT

	else

		/sbin/iptables -A INPUT -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT

		/sbin/iptables -A INPUT -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [Germany]

		/sbin/iptables -A INPUT -p tcp -s 185.216.33.82 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [Austria]

		/sbin/iptables -A INPUT -p tcp -s 146.255.57.28 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [Canada TCP]

		/sbin/iptables -A INPUT -p tcp -s 67.215.7.186 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [Australia 2 TCP]

		/sbin/iptables -A INPUT -p tcp -s 168.1.53.196 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [Belgium 1 TCP]

		/sbin/iptables -A INPUT -p tcp -s 82.102.19.178 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [United States 10 - N-West]

		/sbin/iptables -A INPUT -p tcp -s 162.210.250.170 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [United States 3 - East]

		/sbin/iptables -A INPUT -p tcp -s 64.20.43.202 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [Vietnam TCP]

		/sbin/iptables -A INPUT -p tcp -s 125.212.251.87 --dport 22 -j ACCEPT

		# VPN service https://www.vpnsecure.me [Netherlands TCP]

		/sbin/iptables -A INPUT -p tcp -s 89.39.105.120 --dport 22 -j ACCEPT

	fi

	# Becuase the Block Explorer or Block Crawler are available via port 80 (standard website port)
	# we must open up port 80 for that traffic.

	/sbin/iptables -A INPUT -p tcp --dport 80 -j DROP

	# This Lynx node listens for other Lynx nodes on port $port, so we need to open that port. The
	# whole Lynx network listens on that port so we always want to make sure this port is available.

	/sbin/iptables -A INPUT -p tcp --dport $port -j ACCEPT

	# Known addresses of other coin projects that operate on the same port and have the same version
	# number. This will remove a good number of 'connection refused' errors in the debug log.

	/sbin/iptables -A INPUT -p tcp -s 95.54.82.161 -j DROP #ExperiencecoinCore:3.0.0.1
	/sbin/iptables -A INPUT -p tcp -s 95.222.46.126 -j DROP #ExperiencecoinCore:3.0.0.1
	/sbin/iptables -A INPUT -p tcp -s 165.227.211.179 -j DROP #ExperiencecoinCore:3.0.0.1
	/sbin/iptables -A INPUT -p tcp -s 76.102.131.12 -j DROP #NewYorkCoin-seeder:0.01
	/sbin/iptables -A INPUT -p tcp -s 62.213.218.8 -j DROP #NewYorkCoin-seeder:0.01

	# By default, the RPC port 9223 is opened to the public. This is so the node can both listen
	# for and discover other nodes. It is preferred to have a node that is not just a leecher but
	# also a seeder.

	/sbin/iptables -A INPUT -p tcp --dport $rpcport -j ACCEPT

	# We add this last line to drop any other traffic that comes to this computer that doesn't
	# comply with the earlier rules. If previous iptables rules don't match, then drop'em!

	/sbin/iptables -A INPUT -j DROP

	#
	# Metus est Plenus Tyrannis
	#" > /root/firewall.sh

	echo "Firewall rules are set in /root/firewall.sh"

	chmod 700 /root/firewall.sh

}

config_fail2ban () {

	#
	# The default ban time for abusers on port 22 (SSH) is 10 minutes. Lets make this a full 24
	# hours that we will ban the IP address of the attacker. This is the tuning of the fail2ban
	# jail that was documented earlier in this file. The number 86400 is the number of seconds in
	# a 24 hour term. Set the bantime for lynxd on port 22566/44566 banned regex matches to 24
	# hours as well.

	echo "

	[sshd]
	enabled	= true
	bantime = 86400

	" > /etc/fail2ban/jail.d/defaults-debian.conf

	# Configure the fail2ban jail for lynxd and set the frequency to 20 min and 3 polls.

	echo "

	#
	# SSH
	#

	[sshd]
	port		= ssh
	logpath		= %(sshd_log)s

	" > /etc/fail2ban/jail.local

	service fail2ban start

}

restart () {

	# We now write this empty file to the /boot dir. This file will persist after reboot so if
	# this script were to run again, it would abort because it would know it already ran sometime
	# in the past. This is another way to prevent a loop if something bad happens during the install
	# process. At least it will fail and the machine won't be looping a reboot/install over and
	# over. This helps if we have ot debug a problem in the future.

	/usr/bin/touch /boot/ssh

	/usr/bin/touch /boot/lynxci

	/bin/rm -rf /root/setup.sh

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
	install_packages
	set_network
	manage_swap
	reduce_gpu_mem
	disable_bluetooth
	set_accounts
	install_portcheck
	install_miniupnpc
	install_lynx
	install_mongo
	install_explorer
	set_firewall
	config_fail2ban
	setup_crontabs
	restart

fi
