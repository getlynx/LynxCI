#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#
# wget -qO - https://getlynx.io/install.sh | bash
# wget -qO - https://getlynx.io/install.sh | bash -s "[TipsyMiner Id]" "[0.01-0.95]" "[300-604900]"
#
# Supported OS's: Raspberry Pi OS (32-bit) Lite, Debian 11 & 10, Ubuntu 20.10 & Ubuntu 20.04 LTS
#
function logware {
  local txid=${1:?Must provide a Logware Transaction Id.}
  wget -O - -q https://chaindata.logware.io/tx/"$txid" | jq -r '.pkdata' | base64 --decode
}
#
echo "LynxCI: Thanks for starting the Lynx Core Installer (LynxCI)."
[ $EUID -ne 0 ] && echo "This script must be run from the root account. Exiting." && exit
#
[ "$(grep 'Revision' /proc/cpuinfo)" != "" ] && isPi="1" || isPi="0" # Detect if Pi target?
tipsyid="$1"
if [ "$isPi" = "1" ]; then # If the target device is a Raspberry Pi.
	[ -z "$2" ] && cpu="0.90" || cpu="$2" # Default CPU for headless Pi installs
else # If it's not a Raspberry Pi, then this value is good for everything else.
	[ -z "$2" ] && cpu="0.75" || cpu="$2" # Default CPU used by the built-in miner.
fi
[ -z "$3" ] && ttl="604900" || ttl="$3" # Firewall blocks WAN access after 1 week (~604800 seconds).
#
os="$(grep 'PRETTY_NAME' /etc/os-release | cut -d'=' -f2)" # Get the full OS of the target.
arch="$(dpkg --print-architecture)" # Get the chip architecture of the target device.
echo "LynxCI: Architecture \"$arch\", Operating system $os detected."
#
apt -y update >/dev/null 2>&1 # Update the package list on the target and don't display any output.
apt -y install iptables sudo wget unzip git jq htop >/dev/null 2>&1 # Install minimal packages. Let's keep this simple.
#
lynxService="/etc/systemd/system/lynxd.service" # Standard systemd file placement.
if [ -O $lynxService ]; then # In case of a re-install. Only do this stuff if the file exists.
	systemctl stop lynxd # If the Lynx daemon is already running, then stop it.
	systemctl disable lynxd # Also disable the daemon service if it was already installed.
	systemctl daemon-reload # Give systemd a kick to save the recent changes.
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
echo "LynxCI: For security purposes, the \"root\" account was locked."
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
echo "LynxCI: The user account \"$user\" was given sudo rights."
#
if [ "$isPi" = "1" ]; then # If the target device is a Raspberry Pi
	usermod -L -e 1 pi # Then lock the Pi user account
	echo "LynxCI: For security purposes, the \"pi\" account was locked."
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
	allow=\"45.90.57.209,45.90.58.5\"
	#
	#
	iptables -F # Clear all the current rules, so we can then recreate new rules.
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	iptables -A INPUT -p tcp --dport 22566 -j ACCEPT # Required public Lynx port.
	#
	#
	# Lynx RPC port 9332. Only allow the RPC port when you need to remotely access the RPC
	# commands of this node. The RPC credentials are stored in the lynx.conf file. Never release
	# your RPC credentials unless you know exactly what you are doing.
	#
	#
	#iptables -A INPUT -p tcp --dport 9332 -j ACCEPT # Port 9332 is restricted by default.
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
# https://www.raspberrypi.org/documentation/computers/config_txt.html#gpu_mem
[ "$isPi" = "1" ] && { sed -i '/gpu_mem/d' /boot/config.txt; echo "gpu_mem=16" >> /boot/config.txt; }
# https://www.raspberrypi.org/documentation/computers/config_txt.html#avoid_warnings
[ "$isPi" = "1" ] && { sed -i '/avoid_warnings/d' /boot/config.txt; echo "avoid_warnings=2" >> /boot/config.txt; }
#
mkdir -p "$dir"/.lynx/; chown $user:$user "$dir"/.lynx/
echo "LynxCI: Grabbing latest blockchain bootstrap and verifying hashes."
wget -qO - https://raw.githubusercontent.com/getlynx/LynxBootstrap/master/extract.sh | bash
#
echo "#!/bin/bash
[Unit]
Description=lynxd
After=network.target
[Service]
Type=simple
User=lynx
Group=lynx
ExecStart=/usr/local/bin/lynxd -daemon=0 -conf=$dir/.lynx/lynx.conf -datadir=$dir/.lynx/ -debuglogfile=$dir/.lynx/debug.log -assumevalid=47c3754611aa7e3f30f6d12a9356b61475cc49d47eab8cb3b811df7bc52a58a2
ExecStop=/usr/local/bin/lynx-cli stop
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/lynxd.service # This service starts lynxd if it stops
echo "LynxCI: Lynx service is installed."
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
echo "LynxCI: Firewall service is installed."
#
tempSystemd="/etc/systemd/system/lyt.service" && echo "" > "$tempSystemd"
eof="# https://docs.getlynx.io/lynx-core/lynxci/thermal-controls"
i=1; while ! grep -q "$eof" "$tempSystemd"; do
	[ $i -gt 5 ] && shutdown -r now
	logware "a468c79603534af2f630c2ef89b1cc233a5a269165c9aa2fb549d3ea8c7e7207" > "$tempSystemd"
	echo "$eof" >> "$tempSystemd" && chmod 644 "$tempSystemd"
	i=$((i+1))
	sed -i 's/\r$//' $tempSystemd # Decoding sometimes gets wrong Unix-style line endings
	sleep 2
done
#
tempService="/usr/local/bin/lyt.sh" && echo "" > "$tempService"
eof="# https://docs.getlynx.io/lynx-core/lynxci/thermal-controls"
i=1; while ! grep -q "$eof" "$tempService"; do
	[ $i -gt 5 ] && shutdown -r now
	echo "LynxCI: Temperature service was installed."
	logware "a89f3361acf354d5a3d19c0ca370650457c36f1e5e037726455140ec05272341" > "$tempService"
	echo "$eof" >> "$tempService" && chmod +x "$tempService"
	i=$((i+1))
	sed -i 's/\r$//' $tempService # Decoding sometimes gets wrong Unix-style line endings
	sleep 2
done
#
if [ "$isPi" = "0" ]; then # Expand swap on target devices
	echo "LynxCI: Setting up 4GB swap file."
	fallocate -l 4G /swapfile >/dev/null 2>&1
	chmod 600 /swapfile
	mkswap /swapfile >/dev/null 2>&1
	swapon /swapfile >/dev/null 2>&1
	echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab >/dev/null 2>&1
else # Expand on the Pi's 100MB to 2GB
	sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
	/etc/init.d/dphys-swapfile restart >/dev/null 2>&1;
fi
#
bin="/usr/local/bin"
for f in $bin/lynx-cli $bin/lynxd $bin/lynx-tx
do
  if [ -f "$f" ] # Check if file exists and is a regular file
  then
    echo "LynxCI: Lynx installer integrity check."
  else
  	echo "LynxCI: Downloading and installing the Lynx installer package for the target OS."
		if [ "$isPi" = "1" ]; then
			# Pi 3 and Pi 4 on latest Raspbian OS Lite
			rm -rf $bin/lynx*
			wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.12/lynx-arm32-wallet-0.16.3.12.tar.gz -qO - | tar -xz -C $bin/
			mv -f $bin/lynx-arm32-wallet-0.16.3.12/* $bin/
			rm -rf $bin/lynx-arm32-wallet-0.16.3.12/
		else
			# Supported OS's: Debian 11 (Bullseye), Debian 10 (Buster), Ubuntu 20.10 & Ubuntu 20.04 LTS
			rm -rf $bin/lynx*
			wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.12/lynx-linux64-wallet-0.16.3.12.tar.gz -qO - | tar -xz -C $bin/
			mv -f $bin/lynx-linux64-wallet-0.16.3.12/* $bin/
			rm -rf $bin/lynx-linux64-wallet-0.16.3.12/
		fi
		chown root:root $bin/lynx*
  fi
done
#
# Create the default lynx.conf file
#
lynxConf="$dir/.lynx/lynx.conf"
eof="# https://docs.getlynx.io/lynx-core/lynxci"
touch "$lynxConf"
i=1; while ! grep -q "$eof" "$lynxConf"; do
[ $i -gt 5 ] && shutdown -r now
echo "host=$name
listen=1
daemon=1
listenonion=1
upnp=1
dbcache=450
txindex=0
port=22566
maxmempool=100
testnet=0
# https://docs.getlynx.io/lynx-core/lynxci/debug-log
debug=miner 
disablebuiltinminer=0
# https://docs.getlynx.io/lynx-core/lynxci/thermal-controls
cpulimitforbuiltinminer=$cpu
# https://docs.getlynx.io/lynx-core/lynxci/wallet-functions
disablewallet=1" > "$lynxConf"

echo "LynxCI: For safety, the wallet is disabled."

echo "LynxCI: Generating unique RPC credentials."
echo "# https://docs.getlynx.io/lynx-core/lynxci/rpc-best-practices" >> "$lynxConf"
wget -qO - https://raw.githubusercontent.com/getlynx/LynxCI/master/config/rpc.sh | bash >> "$lynxConf"
sleep 2

echo "LynxCI: Acquiring the latest seed node list."
echo "# https://docs.getlynx.io/lynx-core/lynx-nodes" >> "$lynxConf"
wget -qO - https://raw.githubusercontent.com/getlynx/LynxCI/master/config/node.txt | sort -R >> "$lynxConf"
sleep 2

echo "LynxCI: Acquiring a default set of Lynx addresses for mining."
echo "# https://docs.getlynx.io/lynx-core/lynxci/default-addresses" >> "$lynxConf"
wget -qO - https://raw.githubusercontent.com/getlynx/LynxCI/master/address-mainnet.txt | shuf -n 25 | while IFS= read -r j; do echo "mineraddress=$j"; done >> "$lynxConf"

[ -n "$tipsyid" ] && echo "tipsyid=$tipsyid" >> "$lynxConf"
echo "$eof" >> "$lynxConf"
chmod 770 "$lynxConf"
i=$((i+1))
sleep 2
done
#
echo "LynxCI: Lynx default configuration file, \"$lynxConf\" was created."
[ -n "$tipsyid" ] && echo "LynxCI: Tipsy Miner registration added to Lynx configuration file."

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
	echo "# https://docs.getlynx.io/lynx-core/lynxci/debug-log
	$dir/.lynx/debug.log {
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
tmptipsy="/home/lynx/.tipsy.sh" && touch "$tmptipsy"
eof="# https://medium.com/lynx-blockchain/how-to-register-your-miner-with-tipsy-in-lynxci-493aa63cceb7"
i=1; while ! grep -q "$eof" "$tmptipsy"; do
[ $i -gt 5 ] && shutdown -r now
echo "#!/bin/bash

if [ -z \"\$1\" ]; then

	echo \"Learn how to configure your Tipsy Lynx Miner at https://medium.com/lynx-blockchain/how-to-register-your-miner-with-tipsy-in-lynxci-493aa63cceb7.\"

else

	sed -i '/tipsyid=/d' /home/lynx/.lynx/lynx.conf # If an old value exists, delete it from the lynx.conf file.
	echo \"tipsyid=\$1 # https://medium.com/lynx-blockchain/how-to-register-your-miner-with-tipsy-in-lynxci-493aa63cceb7\" >> /home/lynx/.lynx/lynx.conf # Append the new value to the end of the file.
	echo \"Restarting Lynx to save settings...\"
	count=\$(lynx-cli -conf=/home/lynx/.lynx/lynx.conf getblockcount) # get the the local blockcount total
	hash=\$(lynx-cli -conf=/home/lynx/.lynx/lynx.conf getblockhash \"\$count\") # get the hash of the newest known local block
	t=\$(lynx-cli -conf=/home/lynx/.lynx/lynx.conf getblock \"\$hash\" | grep '\"time\"' | awk '{print \$2}' | sed -e 's/,\$//g') # get it's time
	cur_t=\$(date +%s) # Get the current time.
	diff_t=\$((cur_t-t)) # Get the time difference from the current time and the latest known blocks time.
	if [ \"\$diff_t\" -lt \"15000\" ]; then
		sudo systemctl restart lynxd
	fi
	echo \"Congratulations! Your Tipsy Miner Id ---\$1--- has been linked to this miner.\"

fi
" > "$tmptipsy"
echo "LynxCI: Tipsy Miner documentation installed."
echo "$eof" >> "$tmptipsy" && chmod +x "$tmptipsy"
i=$((i+1))
sleep 2
done
# sed -i -e 's/\r$//' /home/lynx/.lynxci-tipsy-help.sh # A special char is in the file. Need to strip it.
echo "alias tipsy='/home/lynx/.tipsy.sh'" >> "$localLocale" # Create the alias for 'help'.
#
echo "alias tipsy='echo \"This command only works when logged in under the lynx user account.\"'" >> /root/.bashrc
#
tmphelp="/home/lynx/.lynxci-help" && touch "$tmphelp"
eof="# 3a3b7587bfc7c55aeb487cf56c24be148802bc47cac93554d620b3f266167a9e"
i=1; while ! grep -q "$eof" "$tmphelp"; do
	[ $i -gt 5 ] && shutdown -r now
	logware "3a3b7587bfc7c55aeb487cf56c24be148802bc47cac93554d620b3f266167a9e" > "$tmphelp"
	echo "LynxCI: LynxCI documentation installed."
	echo "$eof" >> "$tmphelp" && chmod +x "$tmphelp"
	i=$((i+1))
	sleep 2
done
#
echo "alias help='tail -n 1000 /home/lynx/.lynxci-help'" >> "$localLocale" # Create the alias for 'help'.
#
echo "alias help='echo \"This command only works when logged in under the lynx user account.\"'" >> /root/.bashrc
#
if [ "$isPi" = "1" ]; then
	#
	echo 1 >/sys/class/leds/led0/brightness # Turn the target Pi activity light on.
	sshPi="/boot/ssh" # Relevent to Pi installs. For remote access via SSH.
	[ ! -O $sshPi ] && { touch $sshPi; echo "LynxCI: Post install \"/boot/ssh\" file was created."; }
	rfkill unblock 0 && rfkill block 1 # Let's enable wifi and disable the bluetooth by default.
	echo "LynxCI: Manually configure wifi with the \"lyw\" command."
	#
	#
	# If a user creates a wp_supplicant.conf file and drops it in the /boot dir prior to first boot
	# This script will not overwrite it. This allows users to create wireless, headless nodes.
	#
	wifiConfiguration="/etc/wpa_supplicant/wpa_supplicant.conf" && touch "$wifiConfiguration"
	i=1; while ! grep -q "country" "$wifiConfiguration"; do # Only create this file if it doesn't exist already.
		[ $i -gt 5 ] && shutdown -r now
		logware "1ffc1bd02a905f9ac72bf21fe5e6db1dae3680790bd225dd3812b670956c728d" > "$wifiConfiguration"
		echo "LynxCI: LynxCI documentation installed."
		echo "$eof" >> "$wifiConfiguration" && chmod +x "$wifiConfiguration"
		i=$((i+1))
		sleep 2
	done
	#
	# If the TipsyId has been stashed in the wpa_supplicant.conf, grab it and place it in the lynx.conf file
	tipsyid="$(sed -ne 's|[\t]*#tipsyid=[\t]*||p' $wifiConfiguration)"
	if [ "$tipsyid" != "" ]; then
		echo "tipsyid=$tipsyid" >> "$dir/.lynx/lynx.conf"
	fi
#
echo "#!/bin/sh
# This file was reset by the LynxCI installer.
#
exit 0" > /etc/rc.local
#
fi
#
# systemctl list-timers

systemctl stop update.timer &>/dev/null
systemctl disable update.timer &>/dev/null
systemctl daemon-reload &>/dev/null

echo "
[Unit]
Description=Built-in LynxCI Updater Service
[Service]
Type=oneshot
ExecStartPre=/bin/mkdir -p /usr/local/bin/config/
ExecStartPre=/usr/bin/wget https://raw.githubusercontent.com/getlynx/LynxCI/master/config/update.sh -O /usr/local/bin/config/update.sh
ExecStartPre=/bin/chmod 744 /usr/local/bin/config/update.sh
ExecStart=/usr/local/bin/config/update.sh
" > /etc/systemd/system/update.service

chmod 644 /etc/systemd/system/update.service
chown root:root /etc/systemd/system/update.service

echo "
[Unit]
Description=Built-in LynxCI Updater Timer
[Timer]
OnBootSec=15min
[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/update.timer

chmod 644 /etc/systemd/system/update.timer
chown root:root /etc/systemd/system/update.timer

systemctl daemon-reload &>/dev/null
systemctl enable update.timer &>/dev/null
systemctl start update.timer &>/dev/null
#
echo "LynxCI: Installation complete. A reboot will occur in 5 seconds."
echo ""
echo "LynxCI: After reboot is complete, log into the \"lynx\" user account with the password \"lynx\"."
echo ""
#
rm -rf "$dir"/install.sh
rm -rf /root/install.sh
sleep 5 && reboot
