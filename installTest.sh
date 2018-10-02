#!/bin/bash

# Our first required argument to run this script is to specify the environment to run Lynx. The two
# accepted options are 'mainnet' or 'testnet'.

if [ "$1" = "mainnet" ]; then

	environment="mainnet"
	port="22566"
	rpcport="9332"
	lynxbranch="master"
	explorerbranch="master"
	lynxconfig=""
	explorer="https://explorer.getlynx.io/api/getblockcount"
	addresses="miner-addresses.txt"
	setupscript="IsProduction=Y"

else

	environment="testnet"
	port="44566"
	rpcport="19335"
	lynxbranch="new_validation_rules"
	explorerbranch="master"
	lynxconfig="testnet=1"
	explorer="https://test-explorer.getlynx.io/api/getblockcount"
	addresses="miner-addresses-testnet.txt"
	setupscript="IsProduction=N"

fi

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

	# We are inspecting the local operating system and extracting the full name so we know the
	# unique flavor. In the rest of the script we have various changes that are dedicated to
	# certain operating system versions.

	version_id=`cat /etc/os-release | egrep '^VERSION_ID=' | cut -d= -f2 -d'"'`

	pretty_name=`cat /etc/os-release | egrep '^PRETTY_NAME=' | cut -d= -f2 -d'"'`

	checkForRaspbian=$(cat /proc/cpuinfo | grep 'Revision')

	process_name=$(shuf -n 1 -e A B C D E F G H J K M N P Q R S T U V W Z Y Z)$(shuf -i 1000-9999 -n 1)

	print_success "Build environment is '$environment'."

	crontab -r

}

install_packages () {

	apt-get update -y \
		&> /dev/null

	apt-get install -y \
		autoconf \
		automake \
		build-essential \
		bzip2 \
		cpulimit \
		curl \
		fail2ban \
		g++ \
		gcc \
		git \
		git-core \
		htop \
		libboost-all-dev \
		libcurl4-openssl-dev \
		libevent-dev \
		libgmp-dev \
		libjansson-dev \
		libminiupnpc-dev \
		libncurses5-dev \
		libssl-dev \
		libtool \
		libz-dev \
		make \
		nano \
		nodejs \
		pkg-config \
		software-properties-common \
		&> /dev/null

}

install_throttle () {

	apt-get update -y

	apt-get install cpulimit -y

	print_success "Cpulimit was installed."

}

manage_swap () {

	# We are only modifying the swap amount for a Raspberry Pi device.

	if [ ! -z "$checkForRaspbian" ]; then

		# On a Raspberry Pi 3, the default swap is 100MB. This is a little restrictive, so we are
		# expanding it to a full 1GB of swap. We don't usually touch too much swap but during the
		# initial compile and build process, it does consume a good bit so lets provision this.

		sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile

		print_success "Swap will be increased to 1GB on reboot."

	# The following condition checks if swaps exists and set it up if it doesn't.

	else

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

		# swapon --show

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

		print_success "GPU memory was reduced to 16MB on reboot."

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

		apt-get remove pi-bluetooth -y

		print_success "Bluetooth was uninstalled."

	fi

}

set_network () {

	ipaddr=$(ip route get 1 | awk '{print $NF;exit}')

	hhostname="lynx$(shuf -i 100000000-999999999 -n 1)"

	fqdn="$hhostname.getlynx.io"

	echo $hhostname > /etc/hostname && hostname -F /etc/hostname

	echo $ipaddr $fqdn $hhostname >> /etc/hosts

}

set_wifi () {

	# The only time we want to set up the wifi is if the script is running on a Raspberry Pi. The
	# script should just skip over this step if we are on any OS other then Raspian.

	if [ ! -z "$checkForRaspbian" ]; then

		# Let's assume the files already exists, so we will delete them and start from scratch.

		rm -rf /boot/wpa_supplicant.conf
		rm -rf /etc/wpa_supplicant/wpa_supplicant.conf
		
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

		print_success "Wifi configuration script was installed."

	fi

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

		print_success "The 'pi' login was locked. Please log in with '$ssuser'. The default password is '$sspassword'."

		sleep 5

	fi
}

install_portcheck () {

	rm -rf /etc/profile.d/portcheck.sh

	rm -rf /etc/profile.d/logo.txt

	cp -rf /root/LynxCI/logo.txt /etc/profile.d/logo.txt

	echo "	#!/bin/bash

	BLUE='\033[94m'
	GREEN='\033[32;1m'
	RED='\033[91;1m'
	RESET='\033[0m'

	print_success () {

		printf \"\$GREEN\$1\$RESET\\n\"

	}

	print_error () {

		printf \"\$RED\$1\$RESET\\n\"

	}

	print_info () {

		printf \"\$BLUE\$1\$RESET\\n\"

	}

	print_warning () {

		printf \"\$YELLOW\$1\$RESET\\n\"

	}

	print_success \" Standby, checking connectivity...\"

	# When the build script runs, we know the lynxd port, but we don't know if after the node is
	# built. So we are hardcoding the value here, so it can be checked in the future.

	port=\"$port\"

	rpcport=\"$rpcport\"

	if [ -z \"\$(ss -lntu | grep \$port | grep -i listen)\" ]; then

		app_reachable=\"false\"

	else

		app_reachable=\"true\"

	fi

	if [ -z \"\$(ss -lntu | grep \$rpcport | grep -i listen)\" ]; then

		rpc_reachable=\"false\"

	else

		rpc_reachable=\"true\"

	fi

	if ! pgrep -x \"lynxd\" > /dev/null; then

		block=\"being updated\"

	else

		block=\$(curl -s http://127.0.0.1/api/getblockcount)

		if [ -z \"\$block\" ]; then

			block=\"being updated\"

		else

			block=\$(echo \$block | numfmt --grouping)

		fi

	fi

	print_success \"\"
	print_success \"\"
	print_success \"\"

	# This file really should not be downloaded over and over again. Instead, just copy the local
	# file in root to a dir in /home/lynx/ for self indexing.

	cat /etc/profile.d/logo.txt

	echo \"
 | To set up wifi, edit the '/etc/wpa_supplicant/wpa_supplicant.conf' file.    |
 '-----------------------------------------------------------------------------'
 | For local tools to play and learn, type 'sudo /root/lynx/src/lynx-cli help'.|
 '-----------------------------------------------------------------------------'
 | LYNX RPC credentials are located in '/root/.lynx/lynx.conf'.                |
 '-----------------------------------------------------------------------------'
   The current block height on this LynxCI node is \$block.
 '-----------------------------------------------------------------------------'
   The unique identifier for this LynxCI node is $hhostname.
 '-----------------------------------------------------------------------------'\"

	if [ \"\$app_reachable\" = \"true\" ]; then

		print_success \"\"
		print_success \" Lynx port \$port is open.\"

	else

		print_success \"\"
		print_error \" Lynx port \$port is not open.\"

	fi

	if [ \"\$rpc_reachable\" = \"true\" ]; then

		print_success \"\"
		print_success \" Lynx RPC port \$rpcport is open.\"
		print_success \"\"

	else

		print_success \"\"
		print_error \" Lynx RPC port \$rpcport is not open.\"
		print_success \"\"

	fi

	if [ \"\$port\" = \"44566\" ]; then

		print_error \" This is a non-production 'testnet' environment of Lynx.\"
		print_success \"\"

	fi

	print_success \" Lots of helpful videos about LynxCI are available at the Lynx FAQ. Visit \"
	print_success \" https://getlynx.io/faq/ for more information and help.\"


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

	rm -rf ~/LynxBlockExplorer && rm -rf ~/.npm-global

	# We might need curl and some other dependencies so let's grab those now. It is also possible
	# these packages might be used elsewhere in this script so installing them now is no problem.
	# The apt installed is smart, if the package is already installed, it will either attempt to
	# upgrade the package or skip over the step. No harm done.

	apt-get update -y

    apt-get install -y curl software-properties-common git gcc g++ make

    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -

    apt-get install -y nodejs

    print_success "NodeJS was installed."

	npm install pm2 -g

	sleep 3

	print_success "PM2 was installed."

	git clone -b $explorerbranch https://github.com/doh9Xiet7weesh9va9th/LynxBlockExplorer.git

	sleep 3
	
	# We need to update the json file in the LynxBlockExplorer node app with the lynxd RPC access
	# credentials for this device. Since they are created dynamically each time, we just do
	# find and replace in the json file.

	sed -i "s/9332/${rpcport}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__HOSTNAME__/x${fqdn}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__MONGO_USER__/x${rrpcuser}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__MONGO_PASS__/x${rrpcpassword}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__LYNXRPCUSER__/${rrpcuser}/g" /root/LynxBlockExplorer/settings.json
	sed -i "s/__LYNXRPCPASS__/${rrpcpassword}/g" /root/LynxBlockExplorer/settings.json

	cd /root/LynxBlockExplorer/

	npm install

	sleep 3
	
	# Start the Block Explorer nodejs app and set it up in PM2

	pm2 stop LynxBlockExplorer

	sleep 3

	pm2 delete LynxBlockExplorer

	sleep 3

	pm2 start

	sleep 3

	pm2 startup ubuntu

	sleep 3

	pm2 save

	sleep 3

	# On Raspian, sometimes the pm2 service shows a benign warning during boot, prior to the first
	# command prompt. This replacement fixes the issue, avoiding the unneeded warning.

	sed -i 's/User=undefined/User=root/' /etc/systemd/system/pm2-undefined.service

	# Since we provide a download file for the setup of other nodes, set the flag for the env.

	sed -i "s/IsProduction=N/${setupscript}/g" /root/LynxBlockExplorer/public/setup.sh

	# Yeah, we are probably putting to many comments in this script, but I hope it proves
	# helpful to someone when they are having fun but don't know what a part of it does.

	print_success "Lynx Block Explorer was installed"
}

# The MiniUPnP project offers software which supports the UPnP Internet Gateway Device (IGD)
# specifications. You can read more about it here --> http://miniupnp.free.fr
# We use this code because most folks don't know how to configure their home cable modem or wifi
# router to allow outside access to the Lynx node. While this Lynx node can talk to others, the
# others on the network can't always talk to this device, especially if it's behind a router at
# home. Currently, this library is only installed if the device is a Raspberry Pi.

install_miniupnpc () {

	if [ ! -z "$checkForRaspbian" ]; then

		print_success "$pretty_name detected. Installing Miniupnpc."

		apt-get install libminiupnpc-dev -y

		print_success "Miniupnpc was installed."

	fi

}

install_lynx () {

	print_success "$pretty_name detected. Installing Lynx."

	apt-get install git-core build-essential autoconf libtool libssl-dev libboost-all-dev libminiupnpc-dev libevent-dev libncurses5-dev pkg-config bzip2 -y

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

		./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --enable-cxx --without-gui --disable-shared --with-miniupnpc --enable-upnp-default --disable-tests

		make

	else

		cd /root/lynx/

		./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --enable-cxx --without-gui --disable-shared --disable-tests

		make

	fi

	# In the past, we used a bootstrap file to get the full blockchain history to load faster. This
	# was very helpful but it did bring up a security concern. If the bootstrap file had been
	# tampered with (even though it was created by Lynx dev team) it might prove a security risk.
	# So now that the seed nodes run faster and new node discovery is much more efficient, we are
	# phasing out the use of the bootstrap file.

	# Below we are creating the default lynx.conf file. This file is created with the dynamically
	# created RPC credentials and it sets up the networking with settings that testing has found to
	# work well in the LynxCI build. Of course, you can edit it further if you like, but this
	# default file is the recommended start point.

	cd ~/ && rm -rf .lynx && mkdir .lynx

	echo "
	listen=1
	daemon=1
	rpcuser=$rrpcuser
	rpcpassword=$rrpcpassword
	rpcport=$rpcport
	port=$port
	rpcbind=127.0.0.1
	rpcbind=::1
	rpcallowip=0.0.0.0/24
	rpcallowip=::/0
	rpcworkqueue=64
	listenonion=0
	upnp=1
	txindex=1

	# By default, wallet functions in LynxCI are disabled. This is for security reasons. If you
	# would like to enable your wallet functions, change the value from '1' to '0' in the
	# 'disablewallet' parameter. Then restart lynxd to enact the change. Of course, you can do the
	# reverse action to disable wallet functions on this node. You can always check to see if
	# wallet functions are enabled with '$ /root/lynx/src/lynx-cli help', looking for the
	# '== Wallet ==' section at the bottom of the help file.

	disablewallet=1

	$lynxconfig

	addnode=seed1.getlynx.io
	addnode=seed2.getlynx.io
	addnode=seed3.getlynx.io
	addnode=seed4.getlynx.io
	addnode=seed5.getlynx.io
	addnode=seed6.getlynx.io
	addnode=seed7.getlynx.io
	addnode=seed8.getlynx.io
	addnode=seed9.getlynx.io

	mineraddress=mfbJcPvkAarZsZ4NardWnjTLUScGBMTxU7
	mineraddress=mfkGhgn8pRPiF1BjXGRNpm7rNJvaNdhPfY
	mineraddress=mfveuaZ7ruutDQTAgpTV2H4AP4iKJaRqyK
	mineraddress=mfZf9oZ3mKpU28z6HCtEMQjHm96PU6gEEp
	mineraddress=mg6ZhPJrXgWGUXBPTJwrvRxWtBfsVtoAJf
	mineraddress=mgcq4nFwKEhFK7sqLmLsZAVeqwXMXSN6qr
	mineraddress=mgePXHSf5CCvg4pi3Sy8RwnBAnBPqrHrpZ
	mineraddress=mgF98BtQZvteDnsP71xUfcp264aqjxKWYV
	mineraddress=mgh7sH4Gi6pE2XBo1a8Prxwxa3bSajhcdo
	mineraddress=mgj6MkmvNohh8wonKEiqsbnat5szqPmg8d
	mineraddress=mgkCjM7pbsc7he4CbrATLP35kA39ceNK1a
	mineraddress=mgLATgS1G3MuWztKCPjrDWSjdpsUYxT9Gm
	mineraddress=mgPP4MMz2t7qG4SQbr8438YDJoGQZAkkje
	mineraddress=mgrqEpUjeUnaCaNQ5Zrokhy7nYn9XumM7A
	mineraddress=mgzXoLJz8F1fJfoYogPfHnawhG4Ye3vvFn
	mineraddress=mh99teTkCEbdyJMwXyjtwpfngR6AVriyKJ
	mineraddress=mh9XjtNrEvDHc88E96tVjQSZWG9Xdcwsb9
	mineraddress=mhdnTu4jvm1hfL9fLhGfVucx3XppuLmwZV
	mineraddress=mhgxEHyAfkKmo2ZjPhJ9MGw9g9t9PudM1H
	mineraddress=mhHdZxoCBKK5KXoCEimFMP8iT5RBruWhxH
	mineraddress=mhHky5Aa9WorDdiTFkqorSbY21YhSRftF1
	mineraddress=mhJySRkcmqws5g3bm6pfrTrDvMpbwKiqJQ
	mineraddress=mhmnf4cEwwVjfWVaaDZ5BLtDe4YoRFmoaP
	mineraddress=mhNCXtwAuY9yW7FMiHqpeXuEBFcYiW3ovZ
	mineraddress=mhNgag6jeGeqSv37vRwSLeNMUYV1KvN3U5
	mineraddress=mhof7Mqs3B86sMBngLxsryr2S5iiMTqREE
	mineraddress=mhRxSsr6xrfswHJEsHXxG9hvnVsCkHwGZt
	mineraddress=mhsBGcPhfM91tjD6nqcQTCY3fKjxUGqHgc
	mineraddress=mhT3eifaUq9qg2tA8SkXn2ZgSAEXkCivBN
	mineraddress=mhuPEiFAAtbD7Bn1wQYPKjpfW1E939urK8
	mineraddress=mhZqPAff3L4c4xpRuk7VHoxmRQf4yWRCja
	mineraddress=mibbwNgDxPv1Yko5ZEtUJATHPogs9a5JYc
	mineraddress=miCsmAb4xo18jBpWWpDAEwXtqRmFQtVJPe
	mineraddress=midrvMU5DTeHw2Lqeni9mkddnqjfv8Ykqq
	mineraddress=mij8SGoMYnVYj9E2zQUCuGtxrtMsfrjXrc
	mineraddress=miKNQHAB3xycHNHHufmLxiynNyF6X2E379
	mineraddress=miMb3ovWwLpks5UqUGLVfqQ9bx4S4jj7vs
	mineraddress=miMNoyRqo87a5vfhtHJ22XFvVMrU2zfGwG
	mineraddress=mivhP58mjwENRr52xTA5ciZqdDVnucgSpW
	mineraddress=miVu69vx9WR7pkZKQtvdqgZziqRVASsPwE
	mineraddress=mj1kXB9k2hEKAMB3AWND2QQuBbjDmSWWiB
	mineraddress=mj94XPmSRpSJiuV56saZc8dNWdtWs9M4Qy
	mineraddress=mjbXzBRm4As1M8M2iJYULdtR14JctuYikc
	mineraddress=mjfSh2LbqT9f2fFxVsPCF3A3u6v9UppzR9
	mineraddress=mjjJZc9vFEuwhCTwr4n1H7ycFbYEvuSAeK
	mineraddress=mjkdrkVHgxBiGzyKhQNm4TJa7NZUREbXgV
	mineraddress=mjN3UzmPorA84EVNjuZ7tfWwAk4HVqUeop
	mineraddress=mjnbK7Aw28FcYVnqwy8p7VwPSkAAsRyeJ2
	mineraddress=mjRpbdXg6fQuDrgYr4zsJrrp6ZTms6BVYn
	mineraddress=mjRwmrFDNwR69iEJKcjag1pYYjgC7NccmH
	mineraddress=mjSd6mN6VzYaowDaCTYw59M5b5pR5F1D1d
	mineraddress=mjYaA5TNht95o2EieCBj2p4ACpyXQmWs4G
	mineraddress=mjyb1cyKj4nfqbhmQA7pYo7CDMmt8UayBq
	mineraddress=mjZvQ5utTMn6eQrE4DvzXXUjX2iMoHWWhn
	mineraddress=mk2p1HB6Ns6aFXUDUmJSJiky9sR3aoQ4b8
	mineraddress=mk4DsvWxopkw4nBuNtksNvBNfUADjqXjKC
	mineraddress=mk7GYHqySTohQVqmpwa3BdJvZ1ZHLfMdv7
	mineraddress=mkFn1a6ZiShz3xtLGzjAsrdkoLHQcshoaW
	mineraddress=mkhf7sHwNXttxFLDG8x2EDy2yxt7deBXJS
	mineraddress=mkj6HSS6JYTUyCQgdvELiDjvz5wjeTM3CP
	mineraddress=mkqPn8Y7pwgHUo9u2ySzBQeiyv3q4PnfMo
	mineraddress=mkqY7T27v445RE4KihadwmF9HrwsrYzQzh
	mineraddress=mkrAbJXuT32Sf3ihznZf2ViAmaCco3onY6
	mineraddress=mkX7KEqjJCJmMcaCxKqodZxTvdfmx6jUb5
	mineraddress=mkZhVkwQALd6tGm4mjoeotX1S238rzQ7LJ
	mineraddress=mm8mXYNEjB52nR3fcJGgxL2HXcPZAEEded
	mineraddress=mm8SC5zoGPTsqzJooThnvMHwqjnpe6wYUU
	mineraddress=mmaQCSiRCkXjd2B2cLmhJq9k9N3JqzumtD
	mineraddress=mmavJyzM8oRZnypHTDjufXPKT5bgmjqNKs
	mineraddress=mmbCAJpoy1wxJ58xduNqnYydVUcp5MaWUe
	mineraddress=mmiFkWa92H441PeEconm2vYN5mxKaWMvwE
	mineraddress=mmikwS8CgPi3zLtyNgahB2o6E4TE4LxtQ9
	mineraddress=mmKCTnJtfHJAR67AoP92yW6PBvqG1dcKoR
	mineraddress=mmKgmR39UbeVChDPosdFbbs624jfhri3i3
	mineraddress=mmqDjNL7VUbdiWb2nXDqvXFcVD8qqAMEYV
	mineraddress=mmvSiPBi5xQDLL8M7yvMmLXf3XyKndLnRD
	mineraddress=mmXFyNDoK6De2Pq3ZcpFXBH4XgxyTce1n9
	mineraddress=mmyNF5oFLY5XEr82i5Xj6LQWcGPqQb6Eqk
	mineraddress=mn297ttVyPgo9atNr1uSswQSss6B6tVqK8
	mineraddress=mn4aHQYTUwdQHyYAcpuezh9rij7ZSJr6KZ
	mineraddress=mnLJyF51tkuJWedY53cDB72tvxdG1b6PLF
	mineraddress=mnoJt1YNnpGkG9H16H1GZmxeryGrzetDpN
	mineraddress=mnTJV2LX5PKHpBF5BkPRnBzF4J6qACbAxH
	mineraddress=mnTwfTjUqae742HmLy7X1Tbk4PRnUNjBLN
	mineraddress=mnZTUTT8s6NZcFJBg2oGr67cySibMTW44G
	mineraddress=mnZXpmYn6kchKdV4vzWKya6XUPfcsJoZ3d
	mineraddress=mo2pWzwMzqF21Feo62Mro3CxSTkD6aob1N
	mineraddress=mo2vdiFM6xAE7rtYVK8vVGo9BNZTHiDfRr
	mineraddress=mo5B3QmSD7vR7XkJ6BxNmDQr8iDYCA93XP
	mineraddress=mo5nR4mkNXnjXe2dvzTGQN8qnFgsKi1Cng
	mineraddress=moeAdZ9fEkYWqnK89V7XiKN6dyTC331zai
	mineraddress=mogdSuYZWd9Hj6HtbskDrihAfgMHZd4o3y
	mineraddress=mogricZsSUXGUqhfFi6VfBtBKoYmYY71HY
	mineraddress=mokUmXxjCpYop11KmdUYodWoEGnwGzq6Zu
	mineraddress=mopUyLLkcPidWdfdKczrmL7rJ3g3AAmLP1
	mineraddress=moTcFdXCHUDSSS3iGTPVfcpqdEdW42RqFL
	mineraddress=motugTcvYJ43VZxnb1FMQT57NNhYZNXouy
	mineraddress=mouRvK53rGZjsxgiytxhkFRcchsrX3bY4d
	mineraddress=moVopppNUFVKa749Q4CfJfCNewsndxDukx
	mineraddress=mow54mSApbv5jgdjzwg1QRsfRWAfcQjYjQ
	mineraddress=moZ4PJ96QittUn31zpRv814C9hq486wzhh
	mineraddress=moz6h8vZbvy3yykb9V58Nu2U5xLVuwTn5o
	mineraddress=mp5hAVVKmw8nNxQKoac2qQMQZPyd23yLgW
	mineraddress=mp7wev8oDHbfRGfSFcLFPmt8c1SS4AFZjy
	mineraddress=mp9vGMcnmLQupoLPs943nyLwMXeo2Z3zk6
	mineraddress=mpDGMj9RVwCGpx2M91Yvz79YeaC23ajBzd
	mineraddress=mpiRXCHpruScyP1sKHzik5RMSzegrB6Xz1
	mineraddress=mpjeopVB6ssPU9ZkccuZ4WxhK6BpqF7ARr
	mineraddress=mpkKhqBfukjd6GTBSSsuJGjRyMeoLGqCJA
	mineraddress=mpzvSX22ucUgjVH89nGnynrL2Vr8qzp6i6
	mineraddress=mq4M3CaW9ZPychQJQTG7KhRGVD99t82Pkn
	mineraddress=mqfA4LWioaVicuo62YXGsHXMDH3eBVDts4
	mineraddress=mqfaJ9AhSuPreiVeABtxa3nZii1iGvvik6
	mineraddress=mqMeRUxbwmkeR4LrCRZ9jMWc8XhCc67BeR
	mineraddress=mqokKpgYzTSCYXzrqJSptUhkj84ubhAjq3
	mineraddress=mqoYbu4keXGarLiStuaKNUTdNEADpijmJY
	mineraddress=mqVF7V4ktgMtmCqyxY47W46kdoCzuYkRc5
	mineraddress=mqVUdWgnJstohBmFbawXJddgQYP4MVq4vW
	mineraddress=mr4MJKiEpPHQpNeZZmgPiJZmbvZpbjvYcs
	mineraddress=mrgE8D4FojafW9dbyfLsF4JwHXVhP5zur7
	mineraddress=mrieP5T6Gszyke635qFd9JR83WqakFkiwR
	mineraddress=mrJHiCnUFXwVzfKxhTFEBvWh7tD4CJPTiX
	mineraddress=mrk8yMq5meMsRZHoxci8VWSZisHp9FZXXD
	mineraddress=mroAPtB74CDKTR3cZzg3M1WWmxigT7EnKp
	mineraddress=mrw9BqFvrp7tYfjpnAaM8jWoxe3EcJsmvP
	mineraddress=mrXw9ZCMu31tmagopLcBUrr16zzKoF3oTR
	mineraddress=ms1pMzoBRrmXTxmYmhwnsVafx279AMigF3
	mineraddress=ms5uHDvnRvyYvo449kPeS9TWHzdpo9b3Uo
	mineraddress=msbvu9xVcYMA4yFuqZc9zBzu3fneNGh8AQ
	mineraddress=msF3am4EqnvktV3KVKfsMsB7wZrTNzQskQ
	mineraddress=msGW7nStR7MKc4VnLAXoaxZGqgGC34qHcz
	mineraddress=msjNbug6YVRmTiBSsFhKbDN6K2DcMqs5rp
	mineraddress=msqQuz3w3u3RHgBLBgvRbwHEvyZYr6HUBi
	mineraddress=msR94L8jKHV8tvnNH7uaVoD4e7Mm4Fdr13
	mineraddress=msSNsjj5xk6itUmd22PB4MHyJ4mkCuZq2H
	mineraddress=msVbPxoye34hZGWvexsXsjd6DvnxLqH9eL
	mineraddress=msX5Td4xoZ6SET2qAKEYS7odFteACVcxiA
	mineraddress=msZXuiZisKTdkt9zESskUvLPffyo96hvGL
	mineraddress=mt4gP1W9Wa2PnsWUE14RoSoyxSitThpHtY
	mineraddress=mtAycYFUFbFRqyVqEYTtaW5XMEAvPvYR4X
	mineraddress=mtBdMFpxFju8Nt9RexV9j1Tn8KQDfSjkcF
	mineraddress=mtiJ2PGpp54mxG2QiVj4jHRCp4Ge4mf2Jo
	mineraddress=mtjNvBikhMg3rtw6AcQswAb8oGERjpwZJE
	mineraddress=mtL13mYBfPqqbD6YdcUckAs74Xg47hpgnB
	mineraddress=mtM8XRZrMFiediihaTsBdv9ezNAk6ExdUn
	mineraddress=mtMxLYCVqqp8tamp45hb7zRhnsBUHEb4XM
	mineraddress=mtunou4jbqEdmnugGDY2Tucs7svpUpBxro
	mineraddress=mtX4VVRAoqdG87zjRMamaYs4hydMuweg86
	mineraddress=mtYpsYwaiYREQt4JVX5Q3bPfkuanA5uo7v
	mineraddress=mupVapHUC31X7Asp2v2HKQvwYBbYcyUUEz
	mineraddress=musW5LaJR3X1ck9tNC47pm4NXgGGFB7miu
	mineraddress=muyQwrWXXt1UHDhYy5S7jEwiM6LuUn4n4F
	mineraddress=muYVj7QA1CmNUsCLcSyVdYo8tm9CyPmCBz
	mineraddress=muYXo8GCDw25WZqLFaCToeCF6UFYa59a7i
	mineraddress=mvD6pZmoMZvsfxosuCENWH9UYHMDyYqDVs
	mineraddress=mvDgJ13RoJMtpdYLwcRToP3kKPMtAvnZ7S
	mineraddress=mvHvRzB6JFzq32HpK573PaP18px3w4oTDd
	mineraddress=mvMt7BPKPNkE7cuktL4D9BQ1eEwDgtk9yy
	mineraddress=mvmygSvEoFZmF3eRNhLB7SXY2VxQZ5cVg6
	mineraddress=mvWgHm3wFCK27TXwp6TGJbHYYurAmTZJTp
	mineraddress=mvWP7MwHaDYkvj3sCSS2GWjQbP7DPA6ntE
	mineraddress=mvwQBcFM1Uu7ihANHxZVPtitcJqJ19cTrd
	mineraddress=mvZDwaeBWCgdTMvtTJDZw9Mi18uhkEDw4i
	mineraddress=mwkGKu67JvReEFxaZTsrp6o9w5fgxtsJA3
	mineraddress=mwxkPxx8SXZmafCGsCDrdEuigXTCzYbqiE
	mineraddress=mxeTLVyYXrviG7npKjBYQ1zdcDA6vy59Fc
	mineraddress=mxHmZsNnSbeiZxg4DZFZdPQvF2evavNbfc
	mineraddress=mxNeUH65YhVnALxsnD668vMt1HqvkoqBcN
	mineraddress=mxoDvwfmNr2FBSTGhRzXZRpeQSxi5DE8d8
	mineraddress=mxqLhqu5q7Pis31DwfEErRrxVs2du39A9Z
	mineraddress=mxR2co5octogzMzChtHQPiY7qjHY99VVEL
	mineraddress=mxSy3pNp1hLvAkfpqrVQ1x6GL3eaEs8uvK
	mineraddress=mxTJzfV79an1UbPtSDT33QMr3UuXVXRSFe
	mineraddress=mxynR9ukFQFd6HbtjAEoam9ZZwxHqfq4kQ
	mineraddress=mya75kke83iVnqsytj2AdLpJNgpYHgt5Ni
	mineraddress=myfnZM71KaMjrCzbQX96dWQdtodHwjYThu
	mineraddress=myHQWP4xT5NEDkvEL7qV4cieexQJCXmi3o
	mineraddress=myJh1LETJiixp1axQJ7rnsczQz5vPRzFzh
	mineraddress=myjYw35rNEeic2GUGP1ATPSkmvntEYYjGy
	mineraddress=myMq9Dd7Vfgwrr5Swi6XjoxDMNYkBJhzRV
	mineraddress=mytcRp7T1gm8oEYsbVZA7S5rSfyfjNKSpw
	mineraddress=myv2tcejWbAWGWmYCsoZM5ddLU9QVPTRpu
	mineraddress=mzdj5hiF9qZyHifWdEACoCMxyYmyaNhjiU
	mineraddress=mzF8Vd13BisXxZGZXfunYAmAgyGhAbG5As
	mineraddress=mzFc2731iQD1t2eb1HVWCcvLFMox2oKPXB
	mineraddress=mzKsMieTWN665ThC7QoU2AQpQbY1ktKpAa
	mineraddress=mzkzjrh6aUh29ypBDWdPJyfYBZia8HRhuG
	mineraddress=mzoCHjzkRHFo18w8WxNPNZW3ocMuyJazGC
	mineraddress=mzoX6qtHGwR85zYAwsH44UcEZk8XYcrUHb
	mineraddress=mzpFBHB7pVp2P27fGpBX9roYM7LxJhNQoA
	mineraddress=mzpsscMkhuEW3Qdx4rHKsQv1mu2hGMm3fS
	mineraddress=mzrZJsiNNRoPH45rKe6TqKmyvtaY8SGys5
	mineraddress=mzyjTdHeoiuwYD1peVB2dwDCNWcReJBSkC
	mineraddress=mzZ6cTHSaX2X6ixFRivZq7i6ahmca3zC6S
	mineraddress=n11byeGBGrApWruxdWhfPdeq9x57HQQ68G
	mineraddress=n198S1NLJSFCmKzE6ewz8QRJivRvrLtVtG
	mineraddress=n1PXZzhjL8BoN1v7Qu81KbBFWbCQrxwRJr
	mineraddress=n1QLGe5V2edYLKvkekXjkvo26yUgHtdMXX
	mineraddress=n1s1CN8hpiCPPrdcnxGkPYRbg41Adn8jXp
	mineraddress=n1so9dS3T83XP1k7avHRoGxcaZdcFdFPf4
	mineraddress=n1TVtmyJBGrryCrqRubFr8XinMsuyagawX
	mineraddress=n1wYukcEgiKKthDqfLS2UdPsfh6DpLBeoU
	mineraddress=n1XbBbXXVv5K2y4wKVCQZmPTugxBb2jBE7
	mineraddress=n1yYxi7zHxJcfLxsXCz4GRqSALYXg1Jn4p
	mineraddress=n27Wao58wFRTbhRehqCMNk4H9xX14TMe7w
	mineraddress=n2aQZL7AJ5HtmZghYEpJnFfZdruGRqkcXF
	mineraddress=n2caqpCnbGTmmiW25f5regnczwo29hZumv
	mineraddress=n2cnWc3YxhXHA4oCc6eP86yDM3ZrBXJkob
	mineraddress=n2fJQt3wRF8BNYxDtdquacTHxjRj115Vub
	mineraddress=n2kB6aoM6PamrXyCshBMgpHLd1PZR3YHYi
	mineraddress=n2kbr5AQ7zAAH8SxirqESkrfjvfpmf3TXM
	mineraddress=n2kP1GLieKBpwGzRVbN6VR7bgTbeLoXg2Q
	mineraddress=n2qQhU7gw21PmGoyDidQ68FMTjdtc2Gm1n
	mineraddress=n2RQzz343w6ikYcrz9gKArQdS6pZF6TajR
	mineraddress=n32ahfZzwFW1kU31kDrZ4eekz7WgQ3f6qx
	mineraddress=n34BrQEXn412KnQmhknzyVKaWPoJpNovVj
	mineraddress=n3ALLv6xc1CasiNoxnBTAwWhypRpj6Giua
	mineraddress=n3BJmvNTjm3PEWsaz8mBctWVYGtU4LBbYQ
	mineraddress=n3CevcUURjYGTBvueW8gW6UAwbHmn2Js6Q
	mineraddress=n3ekr53WUURJ4DKNoAxHiB78hWtjch8nry
	mineraddress=n3haw3DKwpmpUwkaC9icTgnh947bUd44GX
	mineraddress=n3MGkxc83p8USEBS5tj9kRZ6GA37MMYkzg
	mineraddress=n3ooxkUMis1QRmB9XfDbG5dwYTngwS8vWe
	mineraddress=n3PpZfjX3jdYzeKuxyQgktt5PBha1A2bp7
	mineraddress=n3pWj6m85y5vBddNWjGdhvrdvQt4vghAqz
	mineraddress=n3qcW2YTTUVQR5fe3kqtKRaJh4ieVxpoiJ
	mineraddress=n3S9zzZrEYxFPeQZA1BnUPcwWgdEswFv6f
	mineraddress=n3zUf2ZJqWYApxKhRo2dhZsgzxZPEbKM9m
	mineraddress=n45qVSFy1VeQfA9BibwWfB1cTi8bXK1coQ
	mineraddress=n45s65UeZMYBT3JrGTv5JYavGCttanUa4k
	mineraddress=n4aTctXLuCEdwoRaP9YUuuen6CWxDkDWgD
	mineraddress=n4bBHsQDD1hBpJdT2LDfsBkRmi9Ha9DD4b
	mineraddress=n4JTb14DcNLmtftrhS9rWAVdrRZzyubpR4
	mineraddress=n4L14ix9Homs84KMULabgapDC7d3RptuDn
	mineraddress=n4LaAbH1J7zyCRRHpwDoNRoG1uAFoGxXJW
	mineraddress=n4p3XenUDLW9V1Ldofg2XayfQ49LDK46eZ
	mineraddress=n4qmQMFn4tb2kz2dLiG3wLer9LJhsXfvvw
	mineraddress=n4T1XPNQ1owhEBpdKtBvYZj7QQF4ue3dyJ
	mineraddress=n4Yr4XqvKQT4rLaSqL37a6kEaLEkHrVyvW

	" > /root/.lynx/lynx.conf

	chown -R root:root /root/.lynx/*

	print_success "Lynx was installed."

}

install_miner () {

	print_success "$pretty_name detected. Installing CPUMiner-Multi."

	apt-get update -y \
		&> /dev/null

	apt-get install -y \
		automake \
		autoconf \
		pkg-config \
		libcurl4-openssl-dev \
		libjansson-dev \
		libssl-dev \
		libgmp-dev \
		make \
		g++ \
		libz-dev \
		git \
		&> /dev/null

	git clone https://github.com/tpruvot/cpuminer-multi.git /tmp/cpuminer/

	cd /tmp/cpuminer/ && ./build.sh

	make install

	mv /usr/local/bin/cpuminer /usr/local/bin/$process_name

	print_success "CPUMiner-Multi 1.3.5 was installed."

}

install_mongo () {

	if [ "$version_id" = "9" ]; then

		if [ -z "$checkForRaspbian" ]; then

			echo "LynxCI running on Raspbian GNU/Linux 9. Visit https://getlynx.io to learn more!" > /etc/issue

			print_success "$pretty_name detected. Installing Mongo 4.0."

			apt-get install dirmngr -y

 			apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

 			echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.0 main" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

 			apt-get update -y && apt-get install -y mongodb-org

			systemctl start mongod && systemctl enable mongod

			sleep 5

			account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

			mongo lynx --eval "db.createUser( ${account} )"

			print_success "Mongo 4.0 was installed."

		else

			echo "LynxCI running on Raspbian GNU/Linux 9. Visit https://getlynx.io to learn more!" > /etc/issue

			print_success "$pretty_name detected. Installing Mongo."

			apt-get install mongodb-server -y

			service mongodb start

			sleep 5

			account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

			mongo lynx --eval "db.addUser( ${account} )"

			print_success "Mongo 2.4 was installed."

		fi

	elif [ "$version_id" = "8" ]; then

		echo "LynxCI running on Raspbian GNU/Linux 8. Visit https://getlynx.io to learn more!" > /etc/issue

		print_success "$pretty_name detected. Installing Mongo 4.0."

		apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

		echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/4.0 main" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

		apt-get update -y && apt-get install -y mongodb-org

		systemctl start mongod && systemctl enable mongod

		sleep 5

		account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

		mongo lynx --eval "db.createUser( ${account} )"

		print_success "Mongo 4.0 was installed."

	elif [ "$version_id" = "16.04" ]; then

		print_success "$pretty_name detected. Installing Mongo 4.0."

		apt-get update -y

		sleep 5

		apt-get install apt-transport-https -y

		apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

		echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

		apt-get update -y && apt-get install -y mongodb-org

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

		print_success "Mongo 4.0 was installed."

	elif [ "$version_id" = "18.04" ]; then

		print_success "$pretty_name detected. Installing Mongo 4.0."

		apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

		echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

		apt-get update -y && apt-get install -y mongodb-org

		systemctl start mongod && systemctl enable mongod

		sleep 5

		account="{ user: 'x${rrpcuser}', pwd: 'x${rrpcpassword}', roles: [ 'readWrite' ] }"

		mongo lynx --eval "db.createUser( ${account} )"

		print_success "Mongo 4.0 was installed."

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

	/sbin/iptables -A INPUT -p tcp --dport 80 -j ACCEPT

	# This Lynx node listens for other Lynx nodes on port $port, so we need to open that port. The
	# whole Lynx network listens on that port so we always want to make sure this port is available.

	/sbin/iptables -A INPUT -p tcp --dport $port -j ACCEPT

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

	print_success "Firewall rules are set in /root/firewall.sh"

	chmod 700 /root/firewall.sh

}

set_miner () {

	rm -rf /root/miner.sh

	echo "
	#!/bin/bash

	# This valus is set during the initial build of this node by the LynxCI installer. You can
	# override it by changing the value. Acceptable options are Y and N. If you set the value to
	# N, this node will not mine blocks, but it will still confirm and relay transactions.

	IsMiner=N

	# The objective of this script is to start the local miner and have it solo mine against the
	# local Lynx processes. So the first think we should do is assume a mining process is already
	# running and kill it.

	pkill -f $process_name

	# Let's wait 10 seconds and give the task a moment to finish.

	sleep 10

	# If the flag to mine is set to Y, then lets do some mining, otherwise skip this whole
	# conditional. Seems kind of obvious, but some of us are still learning.

	if [ \"\$IsMiner\" = \"Y\" ]; then

		# Mining isnt very helpful if the process that run's Lynx isn't actually running. Why bother
		# running all this logic if Lynx isn't ready? Unfortunaately, this isnt the only check we need
		# to do. Just because Lynx might be running, it might not be in sync yet, and running the miner
		# doesnt make sense yet either. So, lets check if Lynxd is running and if it is, then we check
		# to see if the blockheight of the local node is _close_ to the known network block height. If
		# so, then we let the miner turn on.

		if pgrep -x \"lynxd\" > /dev/null; then

			# Only if the miner isn't running. We do this to ensure we don't accidently have two
			# miner processes running at the same time.

			if ! pgrep -x \"$process_name\" > /dev/null; then

				# Just to make sure, lets purge any spaces of newlines in the file, so we don't
				# accidently pick one.

				chmod 644 /root/LynxCI/miner-add*

				# Randomly select an address from the addresse file. You are welcome to change
				# any value in that list.

				random_address=\"\$(shuf -n 1 /root/LynxCI/$addresses)\"

				# With the randomly selected reward address, lets start solo mining.

				/usr/local/bin/$process_name -o http://localhost:$rpcport -u $rrpcuser -p $rrpcpassword --no-longpoll --no-getwork --no-stratum --coinbase-addr=\"\$random_address\" -t 1 -R 15 -B -S

			fi

		fi

	fi

	if [ \"\$IsMiner\" = \"Y\" ]; then

		# Only set the limiter if the miner is actually running. No need to start the process if not
		# needed.

		if pgrep -x \"$process_name\" > /dev/null; then

			# Only if the cpulimit process isn't already running, then start it.

			if ! pgrep -x \"cpulimit\" > /dev/null; then

				# Let's set the amount of CPU that the process cpuminer can use to 5%.

				cpulimit -e $process_name -l 5 -b
			fi

		fi

	fi

	#
	# Metus est Plenus Tyrannis
	#" > /root/miner.sh

	chmod 700 /root/miner.sh
	chown root:root /root/miner.sh

}

# This function is still under development.

install_ssl () {

	#https://calomel.org/lets_encrypt_client.html
	print_success "SSL creation scripts are still in process."

}

# This function is still under development.

install_tor () {

	apt install tor
	systemctl enable tor
	systemctl start tor

	echo "
	ControlPort 9051
	CookieAuthentication 1
	CookieAuthFileGroupReadable 1
	" >> /etc/tor/torrc

	usermod -a -G debian-tor root

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

setup_crontabs () {

	# In the event that any other crontabs exist, let's purge them all.

	crontab -r

	# The following 3 lines set up respective crontabs to run every 15 minutes. These send a polling
	# signal to the listed URL's. The ONLY data we collect is the MAC address, public and private
	# IP address and the latest known Lynx block heigh number. This allows development to more
	# accurately measure network usage and allows the pricing calculator and mapping code used by
	# Lynx to be more accurate. If you want to turn off particiaption in the polling service, all
	# you have to do is remove the following 3 crontabs.

	crontab_spacing="$(shuf -i 15-30 -n 1)"

	crontab -l | { cat; echo "*/$crontab_spacing * * * *		/root/LynxCI/poll.sh http://seed00.getlynx.io:8080"; } | crontab -

	crontab_spacing="$(shuf -i 15-30 -n 1)"

	crontab -l | { cat; echo "*/$crontab_spacing * * * *		/root/LynxCI/poll.sh http://seed01.getlynx.io:8080"; } | crontab -

	crontab_spacing="$(shuf -i 15-30 -n 1)"

	crontab -l | { cat; echo "*/$crontab_spacing * * * *		/root/LynxCI/poll.sh http://seed02.getlynx.io:8080"; } | crontab -

	# Every 15 minutes we reset the firewall to it's default state. Additionally we reset the miner.
	# The lynx daemon needs to be checked too, so we restart it if it crashes (which has been been
	# known to happen on low RAM devices during blockchain indexing.)

	crontab_spacing="$(shuf -i 15-30 -n 1)"

	crontab -l | { cat; echo "*/$crontab_spacing * * * *		/root/firewall.sh"; } | crontab -

	crontab_spacing="$(shuf -i 15-30 -n 1)"

	crontab -l | { cat; echo "*/$crontab_spacing * * * *		/root/lynx/src/lynxd"; } | crontab -

	crontab_spacing="$(shuf -i 15-30 -n 1)"

	crontab -l | { cat; echo "*/$crontab_spacing * * * *		/root/miner.sh"; } | crontab -

	# The update script totally reinstalls the Block Explorer code. It's pretty intensive for the
	# host device. So instead of running it daily like we used to, we only run it once a month. This
	# day of the month is randomly selected on build.

	crontab -l | { cat; echo "0 0 $(shuf -i 1-15 -n 1) * *		/root/LynxCI/update.sh"; } | crontab -

	# We found that after a few weeks, the debug log would grow rather large. It's not really needed
	# after a certain size, so let's truncate that log down to a reasonable size every day.

	crontab -l | { cat; echo "*/5 * * * *		truncate -s 1KB /root/.lynx/debug.log"; } | crontab -

	# Evey 15 days we will reboot the device. This is for a few reasons. Since the device is often
	# not actively managed by it's owner, we can't assume it is always running perfectly so an
	# occasional reboot won't cause harm. This crontab means to reboot EVERY 15 days, NOT on the
	# 15th day of the month. An important distinction.

	crontab -l | { cat; echo "0 0 $(shuf -i 16-28 -n 1) * *		/sbin/shutdown -r now"; } | crontab -

	crontab -l | { cat; echo "*/3 * * * *		cd /root/LynxBlockExplorer && /usr/bin/nodejs scripts/sync.js index update >> /tmp/explorer.sync 2>&1"; } | crontab -

	crontab -l | { cat; echo "*/10 * * * *		cd /root/LynxBlockExplorer && /usr/bin/nodejs scripts/peers.js > /dev/null 2>&1"; } | crontab -

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

	print_success "LynxCI was installed."

	print_success "A reboot will occur 10 seconds."

	sleep 10

	reboot

}

# First thing, we check to see if this script already ran in the past. If the file "/boot/ssh"
# exists, we know it previously ran.

if [ -f /boot/lynxci ]; then

	print_error "Previous LynxCI detected. Install aborted."

else

	print_error "Starting installation of LynxCI."

	detect_os
	install_packages
	install_throttle
	set_network
	manage_swap
	reduce_gpu_mem
	disable_bluetooth
	set_wifi
	set_accounts
	install_portcheck
	install_miniupnpc
	install_lynx
	install_mongo
	install_explorer
	#install_miner
	set_firewall
	#set_miner
	secure_iptables
	config_fail2ban
	setup_crontabs
	restart

fi

