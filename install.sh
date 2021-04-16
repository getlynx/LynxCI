#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#
# wget -O - -q https://getlynx.io/install.sh | bash
# wget -O - -q https://getlynx.io/install.sh | bash -s "[mainnet|testnet|TipsyMiner Id]" "[0.01-0.95]" "[300-604900]"
#
# Supported OS's: Raspberry Pi OS (32-bit) Lite, Debian 10 (Buster), Ubuntu 20.10 & Ubuntu 20.04 LTS
#
function logware {
  local txid=${1:?Must provide a Logware Transaction Id.}
  wget -O - -q https://chaindata.logware.io/tx/"$txid" | jq -r '.pkdata' | base64 --decode
}
#
echo "LynxCI: Thanks for starting the Lynx Cryptocurrency Installer (LynxCI)."
[ $EUID -ne 0 ] && echo "This script must be run from the root account. Exiting." && exit
#
[ "$(grep 'Revision' /proc/cpuinfo)" != "" ] && isPi="1" || isPi="0" # Detect if Pi target?
[ -z "$1" ] && env="mainnet" || env="$1" # Mainnet is default.
####[[ "$env" != "mainnet" && "$env" != "testnet" ]] && echo "LynxCI: Invalid first argument." && exit
if [ "$env" = "mainnet" ]; then
	port="22566"
	rpcport="9332"
elif [ "$env" = "testnet" ]; then
	port="44566"
	rpcport="19335"
else
	env="mainnet"
	port="22566"
	rpcport="9332"
	tipsyid="$1"
fi
if [ "$isPi" = "1" ]; then # If the target device is a Raspberry Pi.
	[ -z "$2" ] && cpu="0.80" || cpu="$2" # Default CPU for headless Pi installs
else # If it's not a Raspberry Pi, then this value is good for everything else.
	[ -z "$2" ] && cpu="0.85" || cpu="$2" # Default CPU used by the built-in miner.
fi
[ -z "$3" ] && ttl="604900" || ttl="$3" # Firewall blocks WAN access after 1 week (~604800 seconds).
#
os="$(grep 'PRETTY_NAME' /etc/os-release | cut -d'=' -f2)" # Get the full OS of the target.
arch="$(dpkg --print-architecture)" # Get the chip architecture of the target device.
echo "LynxCI: Architecture \"$arch\", Operating system $os detected."
#
apt -y update >/dev/null 2>&1 # Update the package list on the target and don't display any output.
apt -y install wget jq htop >/dev/null 2>&1 # Install minimal packages. Let's keep this simple.
#
lynxService="/etc/systemd/system/lynxd.service" # Standard systemd file placement.
if [ -O $lynxService ]; then # In case of a re-install. Only do this stuff if the file exists.
	systemctl stop lynxd
	systemctl disable lynxd
	systemctl daemon-reload
fi
#
firewallService="/etc/systemd/system/lyf.service" # Standard systemd file placement.
if [ -O $firewallService ]; then # In case of a re-install. Only do this stuff if the file exists.
	systemctl stop lyf # If the "Lynx Firewall service" is already running, then stop it.
	systemctl disable lyf # Also disable the firewall service if it was already installed.
	systemctl daemon-reload # Give systemd a kick to save the recent changes.
fi
#
tempService="/etc/systemd/system/lyt.service" # Standard systemd file placement.
if [ -O $tempService ]; then # In case of a re-install. Only do this stuff if the file exists.
	systemctl stop lyt # If the "Lynx Firewall service" is already running, then stop it.
	systemctl disable lyt # Also disable the firewall service if it was already installed.
	systemctl daemon-reload # Give systemd a kick to save the recent changes.
fi
#
# We don't ever want a user to login directly to the root account, even if they know the correct
# password. So the root account is locked. Access requires using 'sudo' in the 'lynx' account.
#
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' /etc/ssh/sshd_config
echo "LynxCI: For security purposes, the 'root' account was locked."
#
# Create the user account 'lynx' and skip the prompts for additional information. Set the default
# 'lynx' password as 'lynx'. Force the user to change the password after the first login. We don't
# always know the root password of the target device, be it a Pi, VPS or something else. Let's add
# the user to the sudo group so they can gain access to the root account with 'sudo su'.
#
user="lynx" # This will be the new user account that users will log into this device with.
adduser $user --disabled-password --gecos "" >/dev/null 2>&1 # User is required to change the pass.
echo "$user:$user" | chpasswd >/dev/null 2>&1
chage -d 0 $user >/dev/null 2>&1
adduser $user sudo >/dev/null 2>&1 # Give this user sudo access for higher level access.
dir="$(echo -n "$(bash -c "cd ~${user} && pwd")")"
echo "LynxCI: The user account '$user' was given sudo rights."
#
if [ "$isPi" = "1" ]; then # If the target device is a Raspberry Pi
	usermod -L -e 1 pi # Then lock the Pi user account
	echo "LynxCI: For security purposes, the 'pi' account was locked."
fi
#
[ "$isPi" = "1" ] && name="lynxpi$(shuf -i 200000000-699999999 -n 1)"
[ "$isPi" = "0" ] && name="lynx$(shuf -i 200000000-699999999 -n 1)"
#
lyf="/usr/local/bin/lyf.sh" # LynxCI firewall file path.
rm -rf $lyf # If the file already exists, delete it so it can be recreated.
echo "#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
while : # This shell script runs an endless loop.
do
	#
	#
	# For the period of 7 days of computer uptime (or 7 days since last reboot), the computer will
	# accept an SSH connection from any IP address on port 22. After the 7 days has passed, the
	# firewall will lock itself to only allow access from the list of IP addresses below. The list
	# can contain as many IP addresses as you like, but they must be comma separated, no spaces.
	# CIDR format addresses are accepted. If you forget to change the IP address list, you can cycle
	# the power of your computer or Raspberry Pi or force a reboot of your VPS. This will give you
	# unrestricted access via SSH for 7 days. Note: regular reboot of a computer with unplanned
	# cycling of the power is not ideal and over time might damage component parts of the hardware
	# or promote decay of the hard drive, SSD drive or SD memory card.
	#
	#
	allow=\"162.210.250.170,185.216.33.98,173.209.51.2\"
	#
	#
	iptables -F # Clear all the current rules, so we can then recreate new rules.
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	iptables -A INPUT -p tcp --dport $port -j ACCEPT # Required public Lynx port.
	#
	#
	# Lynx RPC port $rpcport. Only allow the RPC port when you need to remotely access the RPC
	# commands of this node. The RPC credentials are stored in the lynx.conf file. Never release
	# your RPC credentials unless you know exactly what you are doing.
	#
	#
	#iptables -A INPUT -p tcp --dport $rpcport -j ACCEPT # Port $rpcport is restricted by default.
	#
	#
	full=\"\${allow},192.168.0.0/16,10.0.0.0/8\";
	if [ \"\$(cat /proc/uptime | grep -o '^[0-9]\+')\" -gt \"$ttl\" ]; then # (1 week = ~604800 sec)
		for val in \${full//,/ }
		do
			iptables -A INPUT -p tcp -s \$val --dport 22 -j ACCEPT # Restrict SSH traffic.
		done
		echo \"lyf.service: LynxCI Firewall Reset - \${full}\" | systemd-cat -p info
	else
		iptables -A INPUT -p tcp --dport 22 -j ACCEPT # Allow all SSH traffic.
		echo \"lyf.service: LynxCI Firewall Reset - 0.0.0.0/24\" | systemd-cat -p info
	fi
	iptables -A INPUT -j DROP # Drop any other incoming traffic.
	#
	#
	# View the LynxCI Firewall Service activity with the following command
	#
	# $ sudo tail -n 5000 /var/log/syslog | grep lyf.service
	#
	#
	# View the current firewall state with the following command
	#
	# $ lyf
	#
	#
	rm -rf $dir/.lynx/bootstrap.dat.old # Free up some space by removing the old bootstrap file.
	sleep 3600 # Every 1 hour, the script wakes up and runs again. (1 hour = 3600 seconds)
done
#
# \"The trouble with the world is that the stupid
# are cocksure and the intelligent are full of doubt.\" -Bertrand Russell
#
" > $lyf && chmod +x $lyf # Create the file and set the execution permissions on it.
#
echo "$name" > /etc/hostname
echo "127.0.0.1 $name" >> /etc/hosts
#
# Specific to AWS Debian 10. Only applied for AWS Instances. Ignored otherwise.
debianHostTemplate="/etc/cloud/templates/hosts.debian.tmpl"
if [ -O $debianHostTemplate ]; then
	sed -i "/127.0.0.1 localhost/d" $debianHostTemplate
	echo "127.0.0.1 localhost $name" >> $debianHostTemplate
fi
# Pi GPU memory was reduced to 16MB on system reboot.
[ "$isPi" = "1" ] && { sed -i '/gpu_mem/d' /boot/config.txt; echo "gpu_mem=16" >> /boot/config.txt; }
#
# To make the installation go a little faster and reduce Lynx network chatter, let's prep the
# install with the latest copy of the chain. On first start, lynxd will index the bootstrap.dat file
# and import it.
#
mainnetBlocksB="https://github.com/getlynx/LynxBootstrap/releases/download/v5.0-mainnet/blocks.tar.gz"
mainnetBlocksC="https://github.com/getlynx/LynxBootstrap/releases/download/v5.0-mainnet/chainstate.tar.gz"
testnetBootstrap="https://github.com/getlynx/LynxBootstrap/releases/download/v3.0-testnet/bootstrap.tar.gz"
echo "LynxCI: Downloading the Lynx $env bootstrap file."
[ "$env" = "mainnet" ] && { bootstrapFile="$dir/.lynx/blocks.tar.gz"; }
[ "$env" = "testnet" ] && { bootstrapFile="$dir/.lynx/testnet4/bootstrap.dat"; }
rm -rf "$bootstrapFile"
#
echo "LynxCI: This could take 15 minutes, depending on your network connection speed."
if [ ! -O "$bootstrapFile" ]; then # Only create the file if it doesn't already exist.
	[ "$env" = "mainnet" ] && { mkdir -p "$dir"/.lynx/; chown $user:$user "$dir"/.lynx/; wget $mainnetBlocksB -O - -q | tar -xz -C "$dir"/.lynx/; }
	[ "$env" = "mainnet" ] && { mkdir -p "$dir"/.lynx/; chown $user:$user "$dir"/.lynx/; wget $mainnetBlocksC -O - -q | tar -xz -C "$dir"/.lynx/; }
	[ "$env" = "testnet" ] && { mkdir -p "$dir"/.lynx/testnet4/; chown $user:$user "$dir"/.lynx/; wget -q $testnetBootstrap -O - -q | tar -xz -C "$dir"/.lynx/testnet4/; }
	[ "$env" = "testnet" ] && { sleep 1; }
	[ "$env" = "testnet" ] && { chmod 600 "$bootstrapFile"; }
	sleep 1
	echo "LynxCI: Lynx $env bootstrap is downloaded and decompressed."
fi
#
echo "#!/bin/bash
[Unit]
Description=lynxd
After=network.target
[Service]
Type=simple
User=lynx
Group=lynx
ExecStart=/usr/local/bin/lynxd -daemon=0 -conf=$dir/.lynx/lynx.conf -datadir=$dir/.lynx/ -debuglogfile=$dir/.lynx/debug.log
ExecStop=/usr/local/bin/lynx-cli stop
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/lynxd.service # This service starts lynxd if it stops
echo "LynxCI: Service 'lynxd' is installed."
#
echo "#!/bin/bash
[Unit]
Description=lyf
After=network.target
[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/lyf.sh
Restart=always
RestartSec=30
KillMode=mixed
[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/lyf.service # This service resets the local iptables
echo "LynxCI: LynxCI firewall service is installed."
#
echo "#!/bin/bash
[Unit]
Description=lyt
After=network.target
[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/lyt.sh
Restart=always
RestartSec=30
KillMode=mixed
[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/lyt.service # This service resets the CPU based on temp
echo "LynxCI: LynxCI temperature service is installed."
#
if [ "$isPi" = "0" ]; then # Expand swap on target devices
	echo "LynxCI: Setting up 2GB swap file."
	fallocate -l 2G /swapfile >/dev/null 2>&1
	chmod 600 /swapfile
	mkswap /swapfile >/dev/null 2>&1
	swapon /swapfile >/dev/null 2>&1
	echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab >/dev/null 2>&1
else # Expand on the Pi's 100MB to 2GB
	sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
	/etc/init.d/dphys-swapfile restart >/dev/null 2>&1;
fi
#
echo "#!/bin/bash
echo \"\"
echo \"\"
echo \"\"
echo \"
┏┓┃┃┃┃┃┃┃┃┃┃┃┃┃━━━┓━━┓
┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┏━┓┃┫┣┛
┃┃┃┃┃┓┃┏┓━┓┃┓┏┓┃┃┗┛┃┃┃
┃┃┃┏┓┃┃┃┃┏┓┓╋╋┛┃┃┏┓┃┃┃
┃┗━┛┃┗━┛┃┃┃┃╋╋┓┗━┛┃┫┣┓
┗━━━┛━┓┏┛┛┗┛┛┗┛━━━┛━━┛
┃┃┃┃┃━┛┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃
┃┃┃┃┃━━┛┃┃┃┃┃┃┃┃┃┃┃┃┃┃

Lynx Cryptocurrency Installer
https://getlynx.io/
https://logware.io/
https://explorer.getlynx.io/
https://medium.com/lynx-blockchain/
Twitter: @getlynxio

Learn quick, type 'doc'\"
echo \"\"
echo \"\"
echo \"\"
" > /etc/profile.d/portcheck.sh
chmod 755 /etc/profile.d/portcheck.sh
chown root:root /etc/profile.d/portcheck.sh
#
echo "LynxCI: Downloading and installing the Lynx installer package for the target OS."
if [ "$isPi" = "1" ]; then
	# Pi 3 and Pi 4 on latest Raspbian OS Lite
	rm -rf /usr/local/bin/lynx*
	wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.11/lynx-arm32-wallet-0.16.3.11.tar.gz -qO - | tar -xz -C /usr/local/bin/
	cd /usr/local/bin/lynx-arm32-wallet-0.16.3.11/ || exit
	mv -- * .. && cd && rm -rf /usr/local/bin/lynx-arm32-wallet-0.16.3.11/
else
	# Supported OS's: Debian 10 (Buster), Ubuntu 20.10 & Ubuntu 20.04 LTS
	rm -rf /usr/local/bin/lynx*
	wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.11/lynx-linux64-wallet-0.16.3.11.tar.gz -qO - | tar -xz -C /usr/local/bin/
	cd /usr/local/bin/lynx-linux64-wallet-0.16.3.11/ || exit
	mv -- * .. && cd && rm -rf /usr/local/bin/lynx-linux64-wallet-0.16.3.11/
fi
#
chown root:root /usr/local/bin/lynx*
#
# Create the default lynx.conf file
#
lynxConf="$dir/.lynx/lynx.conf"
eof="# end of file"
touch "$lynxConf"
if ! grep -q "$eof" "$lynxConf"; then
	echo "# The following RPC credentials are created at build time and are unique to this host. If you
	# like, you can change them, but you are encouraged to keep very complex strings for each. If an
	# attacker gains RPC access to this host they will steal your Lynx. Understanding that, the
	# wallet is disabled by default so the risk of loss is lowest with this lynx.conf configuration.
	rpcuser=$(sha256sum /var/log/syslog | awk '{print $1}') # Generate a random Lynx RPC username.
	rpcpassword=$(sha256sum /var/log/auth.log | awk '{print $1}') # Generate a random Lynx RPC password.
	rpcport=$rpcport
	rpcallowip=0.0.0.0/24
	rpcallowip=::/0
	rpcworkqueue=64
	# The RPC settings will allow a connection from ANY external host. These
	# two entries define that any IPv4 or IPv6 address will be allowed to
	# connect. But, the operating system firewall settings block the RPC traffic because the RPC
	# port is closed by default. If you are setting up a remote connection, all you will need are
	# the above RPC credentials and to unblock the operating system firewall. As the 'lynx' user,
	# type '$ lyi' to edit the firewall.
	" > "$lynxConf"

	echo "LynxCI: Logging set to minimal output."
	echo "# https://medium.com/lynx-blockchain/lynxci-explainer-the-debug-log-d6ffedaa0e8" >> "$lynxConf"
	logware "97f04e3eaa81849eb3fdecea20e5654905202cd5bf9154dfffc8cc23b36fac72" >> "$lynxConf"

	echo "LynxCI: Wallet is disabled by default."
	echo "# https://medium.com/lynx-blockchain/lynxci-explainer-wallet-security-fd07a9917080" >> "$lynxConf"
	logware "c41882650265bf16e509a8d251c33a36b6f78d3fb5b902f76fd699051fd289ca" >> "$lynxConf"

	echo "LynxCI: Acquiring the latest seed node list."
	echo "# https://medium.com/lynx-blockchain/lynxci-explainer-seed-nodes-81a3e59444e4" >> "$lynxConf"
	[ "$env" = "mainnet" ] && logware "1281f5df994164e2678f00570ad0d176bf98d511f1a80b9a17e3de3ed7f510d0" | sort -R | head -n 5 >> "$lynxConf"
	[ "$env" = "testnet" ] && logware "54dd2e08aedb30e70c8f4f80ffe621ce812f83673691adb1ef2728c26a76549f" | sort -R | head -n 5 >> "$lynxConf"

	echo "LynxCI: Acquiring a default set of Lynx addresses for mining."
	echo "# https://medium.com/lynx-blockchain/lynxci-explainer-default-addresses-for-the-built-in-miner-787988de19f2" >> "$lynxConf"
	[ "$env" = "mainnet" ] && wget -O - -q https://raw.githubusercontent.com/getlynx/LynxCI/master/address-mainnet.txt | sort -R | head -n 5 | while IFS= read -r i; do echo "mineraddress=$i"; done >> "$lynxConf"
	[ "$env" = "testnet" ] && wget -O - -q https://raw.githubusercontent.com/getlynx/LynxCI/master/address-testnet.txt | sort -R | head -n 5 | while IFS= read -r i; do echo "mineraddress=$i"; done >> "$lynxConf"

	echo "
	listen=1                      # It is highly unlikely you need to change any of the following values unless you are tinkering with the node. If you decide to
	daemon=1                      # tinker, know that a backup of this file already exists as /home/lynx/.lynx/sample-lynx.conf.
	port=$port
	                              # Our exchange and SPV wallet partners might want to disable the built in miner. This can be easily done with the 'disablebuiltinminer'
	listenonion=0                 # parameter below. As for our miners who are looking to tune their devices, we recommend the default 0.25 (25%), but if you insist on
	upnp=1                        # increasing the 'cpulimitforbuiltinminer' amount, we recommend you not tune it past using 75% of your CPU load. Remember, with HPoW
	dbcache=450                   # increasing the mining speed does not mean you will win more blocks. You are just generating heat, not blocks. Also, if you are using
	txindex=1                     # a VPS, increasing 'cpulimitforbuiltinminer' too high might get you banned from the the VPS vendors platform. You've been warned.
	host=$name
	maxmempool=100
	testnet=0
	disablebuiltinminer=0
	cpulimitforbuiltinminer=$cpu" >> "$lynxConf"
	[ -n "$tipsyid" ] && echo "tipsyid=$tipsyid" >> "$lynxConf"
	echo "$eof" >> "$lynxConf"
	chmod 770 "$lynxConf"
fi
sleep 2 && sed -i 's/^[\t]*//' "$lynxConf" # Remove the pesky tabs inserted by the 'echo' outputs.
echo "LynxCI: Lynx default configuration file, '$lynxConf' was created."
[ -n "$tipsyid" ] && echo "LynxCI: Tipsy Miner registration added to Lynx configuration file."

[ "$env" = "testnet" ] && { sed -i 's|testnet=0|testnet=1|g' "$lynxConf"; echo "LynxCI: This node is operating on the testnet environment and it's now set in the lynx.conf file."; }
[ "$env" = "mainnet" ] && { sed -i 's|testnet=1|testnet=0|g' "$lynxConf"; echo "LynxCI: This node is operating on the mainnet environment and it's now set in the lynx.conf file."; }
[ "$isPi" = "1" ] && sed -i "s|dbcache=450|dbcache=100|g" "$lynxConf" # Default is 450MB. Changed to 100MB on the Pi.
cp --remove-destination "$lynxConf" "$dir"/.lynx/sample-lynx.conf && chmod 600 "$dir"/.lynx/sample-lynx.conf # We are gonna create a backup of the initially created lynx.conf file.
#
systemctl daemon-reload
if [ "$isPi" = "1" ]; then # Temp service only used if Pi
	systemctl enable lyt >/dev/null 2>&1
fi
systemctl enable lyf >/dev/null 2>&1
systemctl enable lynxd >/dev/null 2>&1 # lynxd will start automatically after reboot.
chown -R $user:$user "$dir"/ # Be sure to reset the ownership of all files in the .lynx dir to root in case any process run
chmod 770 "$dir"/.lynx/*.conf # previously changed the default ownership setting. More of a precautionary measure.
#
lynxLogrotateConfiguration="/etc/logrotate.d/lynxd.conf"
if [ ! -O $lynxLogrotateConfiguration ]; then
	echo "$dir/.lynx/debug.log {
		daily
		rotate 7
		size 10M
		copytruncate
		compress
		notifempty
		missingok
	}
	$dir/.lynx/testnet4/debug.log {
		daily
		rotate 7
		size 10M
		copytruncate
		compress
		notifempty
		missingok
	}" > $lynxLogrotateConfiguration
	echo "LynxCI: Log rotate script installed for Lynx debug file."
fi
#
echo "LynxCI: Lynx was installed."
#
localLocale="$dir"/.bashrc && touch "$localLocale" # If this file doesn't already exist, create it.
rootLocale=/root/.bashrc && touch "$rootLocale" # If this file doesn't already exist, create it.
echo "tail -n 25 $dir/.lynx/debug.log | grep -a \"BuiltinMiner\|UpdateTip\|Pre-allocating\"" >> "$localLocale"
#
echo "alias lyc='nano $dir/.lynx/lynx.conf'" >> "$localLocale" # Create the alias lyc.
echo "alias lyc='echo \"This command only works when logged in under the lynx user account.\"'" >> "$rootLocale" # Create the alias lyc.
#
echo "alias lyl='tail -n 1000 -F $dir/.lynx/debug.log | grep -a \"BuiltinMiner\|UpdateTip\|Pre-allocating\"'" >> "$localLocale"
echo "alias lyl='echo \"This command only works when logged in under the lynx user account.\"'" >> "$rootLocale"
#
echo "alias lyi='sudo nano /usr/local/bin/lyf.sh'" >> "$localLocale" # Create the alias 'lyi'.
echo "alias lyi='echo \"This command only works when logged in under the lynx user account.\"'" >> "$rootLocale" # Create the alias 'lyi'.
#
echo "alias lyf='sudo iptables -L -vn'" >> "$localLocale" # Create the alias 'lyf'.
echo "alias lyf='echo \"This command only works when logged in under the lynx user account.\"'" >> "$rootLocale" # Create the alias 'lyf'.
#
if [ "$isPi" = "1" ]; then # We only need wifi config if the target is a Pi.
	echo "alias lyw='sudo nano /etc/wpa_supplicant/wpa_supplicant.conf'" >> "$localLocale"
	echo "alias lyw='echo \"This command only works when logged in under the lynx user account.\"'" >> "$rootLocale"
	echo "alias lyt='sudo tail -n 500 /var/log/syslog | grep lyt'" >> "$localLocale"
	echo "alias lyt='echo \"This command only works when logged in under the lynx user account.\"'" >> "$rootLocale"
else # Since the target is not a Pi, gracefully excuse.
	echo "alias lyw='echo \"It appears you are not running a Raspberry Pi, so no wireless to be configured.\"'" >> "$localLocale"
	echo "alias lyw='echo \"This command only works when logged in under the lynx user account.\"'" >> "$rootLocale"
	echo "alias lyt='echo \"It appears you are not running a Raspberry Pi, so no temperature to be seen.\"'" >> "$localLocale"
	echo "alias lyt='echo \"This command only works when logged in under the lynx user account.\"'" >> "$rootLocale"
fi
#
# Install the Lynx temperature service code
#
echo -e "#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#
# In order for CPU to change, the temperature must fall out of a preset range. Raise CPU by 1% if 
# temp is too low. Lower CPU 5% if temp is too high.
#
while : # This shell script runs an endless loop.
do
	if \$(pgrep -x \"lynxd\" >/dev/null); then # Only run this script if the Lynx daemon is running
		seconds=\"300\" # The time span in seconds to check for avg temp
		sum=\"0\" # Some defaults for the iterations
		avg=\"0\" # Some defaults for the iterations
		floor=\"53000\" # If the avg temp is below this value, change the CPU
		ceiling=\"60000\" # If the avg temp is above this value, change the CPU
		max=\"92\" # Don't allow the CPU to ever run faster than this value, regardless of temp
		min=\"10\" # Don't allow the CPU to ever run slower than this value, regardless of temp
		lconf=\"$dir/.lynx/lynx.conf\" # The default location of the lynx.conf file
		cpu=\"\$(sed -ne 's|[\t]*cpulimitforbuiltinminer=0.[\t]*||p' \$lconf)\" # Grab the current CPU value
		# Iterate for a time period to get an average temp
		#echo \"Starting \$seconds second test\" # Display the rounded value
		i=1; while [ \"\$i\" -le \"\$seconds\" ]; do
		    temp=\"\$(head -n 1 /sys/class/thermal/thermal_zone0/temp)\"
		    #echo \"\$i: \$((temp/1000))°\" # Output to the screen the running test
		    sum=\"\$sum\"+\"\$temp\"
		    i=\$((i+1))
		    sleep 1
		done
		avg=\"\$((sum/seconds))\" # Generate the average amount
		#echo \"\$seconds second average: \$((avg/1000))°\" # Display the rounded value
		echo \"lyt.service: \$seconds second average: \$((avg/1000))°\" | systemd-cat -p info # Log to syslog
		count=\$(lynx-cli -conf=\$lconf getblockcount) # Get the the local blockcount total
		hash=\$(lynx-cli -conf=\$lconf getblockhash \"\$count\") # Get the hash of the newest known local block
		t=\$(lynx-cli -conf=\$lconf getblock \"\$hash\" | grep '\"time\"' | awk '{print \$2}' | sed -e 's/,\$//g') # Get it's time
		cur_t=\$(date +%s) # Get current time
		diff_t=\$[\$cur_t - \$t] # Difference the current time with the latest known block. 
		# If the temp it too low, raise the CPU value and restart lynxd
		if [ \"\$avg\" -le \"\$floor\" ]; then # Only if the average temp is lower then floor, then increase CPU
		    newcpu=\"\$((cpu+1))\" # Increment the CPU usage of lynxd by 1%
		    newcpuformat=\"0.\"\$newcpu # Increment the CPU usage of lynxd by 1%
		    if [ \"\$newcpu\" -le \"\$max\" ]; then # A hard cap of CPU usage by lynxd
				if [ \"\$diff_t\" -lt \"15000\" ]; then
					sed -i '/cpulimitforbuiltinminer=/d' \$lconf # Delete the old param from the file
			        echo \"cpulimitforbuiltinminer=\$newcpuformat\" >> \$lconf # Append the updated param value to the file
			        echo \"lyt.service: lynxd CPU changed to \${newcpu}%\" | systemd-cat -p info
					systemctl restart lynxd
					echo \"lyt.service: Lynx daemon restarted to commit change.\" | systemd-cat -p info # Log to syslog
				else
					echo \"lyt.service: Initial chain sync not completed. \$diff_t diff. No change to built-in miner.\" | systemd-cat -p info # Log to syslog
				fi
			else
				echo \"Built-in miner maximum of \$max% reached. No change.\"
		    fi
		fi
		# If the temp it too high, lower the CPU value and restart lynxd
		if [ \"\$avg\" -gt \"\$ceiling\" ]; then # Only if the average temp is higher then ceiling, then decrease CPU
		    newcpu=\"\$((cpu-5))\" # Decrement the CPU usage of lynxd by 5%
		    newcpuformat=\"0.\"\$newcpu # Decrement the CPU usage of lynxd by 5%
		    if [ \"\$newcpu\" -ge \"\$min\" ]; then # A hard min of CPU usage by lynxd
				if [ \"\$diff_t\" -lt \"15000\" ]; then
					sed -i '/cpulimitforbuiltinminer=/d' \$lconf # Delete the old param from the file
			    	echo \"cpulimitforbuiltinminer=\$newcpuformat\" >> \$lconf # Append the updated param value to the file
			    	echo \"lyt.service: lynxd CPU changed to - \${newcpu}%\" | systemd-cat -p info
					systemctl restart lynxd
					echo \"lyt.service: Lynx daemon restarted to commit change.\" | systemd-cat -p info # Log to syslog
				else
					echo \"lyt.service: Initial chain sync not completed. \$diff_t diff. No change to built-in miner.\" | systemd-cat -p info # Log to syslog
				fi
			else
				echo \"Built-in miner minimum of \$min% reached. No change.\"
		    fi
		fi
	else
		echo \"lyt.service: Lynx daemon is not running. Temperature check skipped.\" | systemd-cat -p info
	fi
	sleep 3600 # Every 1 hour, the script wakes up and runs again. (1 hour = 3600 seconds)
done
" > /usr/local/bin/lyt.sh && chmod +x /usr/local/bin/lyt.sh # Create the file and set the execution permissions on it.
#
# We are alerting the user to change the firewall settings from the default state.
#
echo "
file=\"/usr/local/bin/lyf.sh\"
fileHash=(\$(sha256sum \$file))
targetHash=\"$(sha256sum /usr/local/bin/lyf.sh | awk '{print $1}')\"
if [ \$targetHash = \$fileHash ] && [ \"\$(cat /proc/uptime | grep -o '^[0-9]\+')\" -lt \"$ttl\" ];
then
	echo \"\"
	echo \"\"
	echo \"--- Please customize your firewall ---\"
	echo \"\"
	echo \"Type 'lyi' now and customize the IP addresses in the 'allow' list. Type 'control-o'\"
	echo \"to save the file after updating it and then 'control-x' to quit the edit session. We\"
	echo \"recommend adding several IP addresses, just for safety. Using your home or office IP\"
	echo \"as well as a VPN IP can work well. If you have a Raspberry Pi, you can most likely\"
	echo \"skip this task. Also, you can skip this task if your computer has an IP address in\"
	echo \"the format 192.168.x.x or 10.0.x.x.\"
	echo \"\"
	echo \"-This message will go away after 7 days or when the 'allow' list is customized. If you\"
	echo \"fail to customize your firewall and get locked out from your computer, manually reboot\"
	echo \"and you will have another 7 days to login. -\"
	echo \"\"
	echo \"\"
fi
" >> "$dir"/.bashrc
#
# Part of the TipsyLynx integration, we are setting up a custom command
# that can be used to connect the local miner rewards to their Tipsy
# Discord account.
#
sed -i '/function tipsy/Q' "$dir"/.bashrc # Remove any previously set 'tipsy' function first.
sed -i '/function tipsy/Q' /root/.bashrc # Remove any previously set 'tipsy' function first.
#
# Install the Tipsy function to be used.
#
echo -e "
function tipsy ()
{
	if [ -z \"\$1\" ]; then
		echo \"\"
		echo \"\"
		echo \"Welcome to TipsyLynx, the easiest way to begin mining Lynx!\"
		echo \"By linking your official Tipsy account to your Lynx miner,\"
		echo \"you will receive double the standard block reward plus you\"
		echo \"will gain access to your rewards much faster!\"
		echo \"\"
		echo \"GETTING STARTED WITH TIPSY\"
		echo \"Tipsy is a bot that runs on the Discord chat platform and\"
		echo \"resides in the official Lynx guild. It's completely free\"
		echo \"and very simple to get started.\"
		echo \" 1 - Register a free Discord account and install it.\"
		echo \" 2 - Visit https://discord.gg/yTfCs5J to join the Lynx guild.\"
		echo \" 3 - Type: !begin - This will register your Discord with Tipsy.\"
		echo \" 4 - Type: !lynx miner - This will display your TipsyLynx Id.\"
		echo \" 5 - Log into LynxCI and type: tipsy [code], replacing \"
		echo \"     [code] with your TipsyLynx Id.\"
		echo \"And now you're all set!\"
		echo \"\"
	else
		sed -i '/tipsyid=/d' $dir/.lynx/lynx.conf
		echo \"tipsyid=\$1\" >> $dir/.lynx/lynx.conf
		echo \"\"
		echo \"\"
		echo \"Congratulations! Your TipsyLynx ID ---\$1---\"
		echo \"has been linked to this miner, no further action is needed.\"
		echo \"From now on, your Tipsy linked miner will earn extra LYNX\"
		echo \"for you!\"
	fi
	echo \"\"
	echo \"HOW WILL THIS WORK?\"
	echo \"Each time this miner finds a block, your ID is etched into\"
	echo \"the public Lynx blockchain. Tipsy sees this, alerts you on\"
	echo \"Discord with a direct message, and sends 2 LYNX to your\"
	echo \"account, that is double the block reward you would receive\"
	echo \"normally. For safety, rewards are delayed by 5 blocks.\"
	echo \"\"
	echo \"BONUS ROUND!\"
	echo \"If the last ordered digits of your TipsyLynx ID match the block\"
	echo \"hash, Tipsy will be instructed to send a bonus amount of\"
	echo \"LYNX to your account. The size of the bonus depends on the\"
	echo \"number of matching digits. You will also receive a direct\"
	echo \"message notice for this.\"
	echo \"\"
	echo \"Match 1 = A 1/16 chance to win 16 extra Lynx\"
	echo \"Match 2 = A 1/256 chance to win 256 extra Lynx\"
	echo \"Match 3 = A 1/4,096 chance to win 4,096 extra Lynx\"
	echo \"Match 4 = A 1/65,536 chance to win 65,536 extra Lynx\"
	echo \"Match 5 = A 1/1,048,576 chance to win 1,048,576 extra Lynx\"
	echo \"\"
	echo \"*Rules are subject to change at anytime.\"
	echo \"\"
	echo \"\"
	if ! [ -z \"\$1\" ]; then
		echo \"Restarting Lynx to save settings...\"
		count=\$(lynx-cli -conf=$dir/.lynx/lynx.conf getblockcount) # Get the the local blockcount total
		hash=\$(lynx-cli -conf=$dir/.lynx/lynx.conf getblockhash \"\$count\") # Get the hash of the newest known local block
		t=\$(lynx-cli -conf=$dir/.lynx/lynx.conf getblock \"\$hash\" | grep '\"time\"' | awk '{print \$2}' | sed -e 's/,\$//g') # Get it's time
		cur_t=\$(date +%s) # Get current time
		diff_t=\$[\$cur_t - \$t] # Difference the current time with the latest known block. 
		if [ \"\$diff_t\" -lt \"15000\" ]; then
			sudo systemctl restart lynxd
		fi
		echo \"Lynx was restarted. All done!\"
	fi
}
" >> "$dir"/.bashrc
echo "alias tipsy='echo \"This command only works when logged in under the lynx user account.\"'" >> /root/.bashrc
#
# Let's include some documentation for CLI users.
#
sed -i '/function doc/Q' "$dir"/.bashrc # Remove any previously set 'doc' function first.
sed -i '/function doc/Q' /root/.bashrc # Remove any previously set 'doc' function first.
#
# Install the Doc function to be used.
#
echo "
function doc ()
{
	echo \"\"
	echo \"LynxCI Commands\"
	echo \"---------------\"
	echo \"\"
	echo \"\"
	echo \"$ doc\"
	echo \"\"
	echo \"Display a list of commands available and shortcuts that will make Linux administration\"
	echo \"of the Lynx daemon easier.\"
	echo \"\"
	echo \"\"
	echo \"$ lyl\"
	echo \"\"
	echo \"[Abbreviation for ‘lynx log’]\"
	echo \"\"
	echo \"Displays the filtered Lynx debug log quickly and it only displays the information you\"
	echo \"are most interested in. Specifically, the command reveals the built-in miner statistics,\"
	echo \"status and latest block tip as detected by peers. This command will be the most common\"
	echo \"command you use to check the status of your Lynx node.\"
	echo \"\"
	echo \"Also, you will also see this command is executed automatically when you first log into a\"
	echo \"LynxCI node.\"
	echo \"\"
	echo \"\"
	echo \"$ tail -F -n 1000 ~/.lynx/debug.log\"
	echo \"\"
	echo \"Displays the unfiltered live streaming debug log. It can be overwhelming at times but\"
	echo \"helpful when troubleshooting.\"
	echo \"\"
	echo \"\"
	echo \"$ lyc\"
	echo \"\"
	echo \"[Abbreviation for ‘lynx configuration’]\"
	echo \"\"
	echo \"This command allows you to quickly view and edit the lynx.conf file. This command allows\"
	echo \"quick access to the Lynx configuration file. The lynx.conf file is preconfigured for you.\"
	echo \"It is well documented and few changes will ever be needed.\"
	echo \"\"
	echo \"\"
	echo \"$ lyw\"
	echo \"\"
	echo \"[Abbreviation for ‘lynx wireless’]\"
	echo \"\"
	echo \"When LynxCI is running on a Raspberry Pi via the ISO, this command is helpful to\"
	echo \"configure the wireless features of the Raspberry Pi. Replace the respective wireless SSID\"
	echo \"username and password values from the default listed values. You may need to gracefully\"
	echo \"reboot your Raspberry Pi after making this change.\"
	echo \"\"
	echo \"\"
	echo \"$ lyt\"
	echo \"\"
	echo \"[Abbreviation for ‘lynx temperature’]\"
	echo \"\"
	echo \"Displays the temperature of your Raspberry Pi and hourly changes made to the lynx.conf\"
	echo \"'cpulimitforbuiltinminer' parameter. This command only works for Raspberry Pi.\"
	echo \"The temperature service automatically adjusts the CPU mining capacity of the device. When\"
	echo \"the Pi is running 'cool', the miner will be ramped up, and when the miner is running\"
	echo \"'hot' the miner is tuned down. The objective is to keep the Pi temperature below the\"
	echo \"maximum operating temperature threshold of 85 C. If you would like to turn off the\"
	echo \"service and manually tune your miner with the 'cpulimitforbuiltinminer' parameter, use\"
	echo \"the following service command.\"
	echo \"\"
	echo \"\"
	echo \"$ sudo systemctl stop lyt\"
	echo \"\"
	echo \"Turns off the temperature service. Only used on a Raspberry Pi. You are required to\"
	echo \"modify the 'cpulimitforbuiltinminer' parameter manually if you turn this off.\"
	echo \"\"
	echo \"\"
	echo \"$ sudo systemctl restart lynxd\"
	echo \"\"
	echo \"Restarts the Lynx daemon. You may be prompted for your lynx user account password. This\"
	echo \"is normal.\"
	echo \"\"
	echo \"\"
	echo \"$ lyf\"
	echo \"\"
	echo \"[Abbreviation for ‘lynx firewall’]\"
	echo \"\"
	echo \"Display the current firewall settings. This command reveals what IP’s will be allowed\"
	echo \"access and the respective ports as well.\"
	echo \"\"
	echo \"\"
	echo \"$ lyi\"
	echo \"\"
	echo \"[Abbreviation for ‘lynx iptables’]\"
	echo \"\"
	echo \"View and edit the firewall settings. This command allows you to edit the firewall\"
	echo \"configuration. The firewall is configured to be secure by default. Be sure to read the\"
	echo \"notes in the file for further customization.\"
	echo \"\"
	echo \"\"
	echo \"$ tipsy\"
	echo \"\"
	echo \"If you are a member of the Lynx Discord, you can register with the Tipsy bot for free.\"
	echo \"You can register your LynxCI node or Raspberry Pi to double your mining rewards and be\"
	echo \"automatically entered to win more Lynx. Display more instructions to get registered.\"
	echo \"\"
	echo \"\"
	echo \"$ htop -t\"
	echo \"\"
	echo \"This Linux package will provide insight into the CPU load. It is recommended to not have\"
	echo \"CPU load average higher than 90% capacity.\"
	echo \"\"
	echo \"\"
}
" >> "$dir"/.bashrc
echo "alias doc='echo \"This command only works when logged in under the lynx user account.\"'" >> /root/.bashrc
echo "LynxCI: The 'doc' command was installed. When logged in, type 'doc'."
#
if [ "$isPi" = "1" ]; then
	#
	echo 1 >/sys/class/leds/led0/brightness # Turn the target Pi activity light on.
	sshPi="/boot/ssh" # Relevent to Pi installs. For remote access via SSH.
	[ ! -O $sshPi ] && { touch $sshPi; echo "LynxCI: Post install '/boot/ssh' file was created."; }
	rfkill unblock 0 && rfkill block 1 # Let's enable wifi and disable the bluetooth by default.
	echo "LynxCI: Manually configure wifi with the 'lyw' command."
	#
	#
	# If a user creates a wp_supplicant.conf file and drops it in the /boot dir prior to first boot
	# This script will not overwrite it. This allows users to create wireless, headless nodes.
	#
	wifiConfiguration="/etc/wpa_supplicant/wpa_supplicant.conf"
	if [ ! -O $wifiConfiguration ]; then # Only create this file if it doesn't exist already.
		echo "
		#
		# For non-US users, making sure you have the correct country code is important. Consult the
		# wireless section of https://www.raspberrypi.org/blog/working-from-home-with-your-raspberry-pi/
		# for details and for your specific country code. After you change the country code, a full
		# reboot of the Pi is required. Yes, you can use both wifi and an eth cable connection at the
		# same time, if you like.
		#
		country=US
		#
		ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
		update_config=1
		network={
		 ssid=\"SSID1\"
		 psk=\"PASSWORD\"
		 key_mgmt=WPA-PSK
		}
		#
		# The double quotes around the SSID and psk value must remain. Make sure you leave the quotes
		# intact. If you have more then one wifi network (like for home and office), having
		# more then one SSID in the file is helpful. The order of the SSID is important. If the first
		# SSID is not found, the Pi will look for the next SSID on the list. Order them as you like.
		# Having multiple SSID's is also nice in the case your primary wifi network goes down.
		#
		network={
		 ssid=\"SSID2\"
		 psk=\"PASSWORD\"
		 key_mgmt=WPA-PSK
		}
		network={
		 ssid=\"SSID3\"
		 psk=\"PASSWORD\"
		 key_mgmt=WPA-PSK
		}
		#
		# \"The fact that an opinion has been widely held is no evidence
		# whatever that it is not utterly absurd. -Bertrand Russell\"
		#
		" > "$wifiConfiguration"
	fi
	#
	# If the TipsyId has been stashed in the wpa_supplicant.conf, grab it and place it in the lynx.conf file
	tipsyid="$(sed -ne 's|[\t]*#tipsyid=[\t]*||p' $wifiConfiguration)"
	echo "tipsyid=$tipsyid" >> "$dir/.lynx/lynx.conf"
	#
	echo "
	#!/bin/sh -e
	# This file was reset by the LynxCI installer.
	#
	# \"The most valuable things in life are not measured in monetary terms. The really important
	# things are not houses and lands, stocks and bonds, automobiles and real state, but
	# friendships, trust, confidence, empathy, mercy, love and faith.\" —Bertrand Russell
	#
	exit 0
	" > /etc/rc.local
	#
fi
#
echo "LynxCI: Installation complete. A reboot will occur 5 seconds."
echo ""
echo "LynxCI: After reboot is complete, log into the 'lynx' user account with the password 'lynx'."
echo ""
#
rm -rf "$dir"/install.sh
rm -rf /root/install.sh
sleep 5 && reboot