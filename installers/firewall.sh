#!/bin/bash

IsRestricted=Y

# Whenever the firewall is reset, we also remove the lynx user from the sudo group. This is for
# security reasons. A grace period exists after the initial build but after the firewall is reset,
# we no longer allow the lynx user to use the sudo command to gain access to root. The user MUST
# know the root account password to administer the lynxd settings. An exception exists for the
# Raspberry pi device. We don't take away sudo from the lynx user on the Pi.

if ! grep 'pi' /etc/passwd >/dev/null 2>&1; then

	/usr/sbin/deluser lynx sudo >/dev/null 2>&1

fi

/sbin/iptables -F # Let's flush any pre existing iptables rules that might exist and start with a clean slate.
/sbin/iptables -I INPUT 1 -i lo -j ACCEPT # We should always allow loopback traffic.

# This line of the script tells iptables that if we are already authenticated, then to ACCEPT
# further traffic from that IP address. No need to recheck every packet if we are sure they
# aren't a bad guy.

/sbin/iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Becuase the Block Explorer or Block Crawler are available via port 80 (standard website port)
# we must open up port 80 for that traffic.

/sbin/iptables -A INPUT -p tcp --dport 80 -j DROP

# Known addresses of other coin projects that operate on the same port and have the same version
# number. This will remove a good number of _connection refused_ errors in the debug log.

/sbin/iptables -A INPUT -p tcp -s 192.210.200.58 -j DROP # Satoshi:0.15.0.1
/sbin/iptables -A INPUT -p tcp -s 193.29.56.183 -j DROP # Satoshi:0.15.0.1
/sbin/iptables -A INPUT -p tcp -s 31.204.147.56 -j DROP # Satoshi:0.15.0.1
/sbin/iptables -A INPUT -p tcp -s 50.225.198.67 -j DROP # Satoshi:0.15.0.1
/sbin/iptables -A INPUT -p tcp -s 185.175.56.132 -j DROP # Satoshi:0.15.0.1
/sbin/iptables -A INPUT -p tcp -s 82.199.45.7 -j DROP # Satoshi:0.15.0.1
/sbin/iptables -A INPUT -p tcp -s 118.240.210.46 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 146.120.14.160 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 159.203.134.242 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 159.65.189.70 -j DROP # Satoshi:0.15.0.1
/sbin/iptables -A INPUT -p tcp -s 165.227.211.179 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 178.118.21.128 -j DROP # NewYorkCoin-seeder:0.01
/sbin/iptables -A INPUT -p tcp -s 178.62.59.145 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 188.166.62.180 -j DROP # /blockchair.com/dogecoin/nodes/
/sbin/iptables -A INPUT -p tcp -s 2.226.152.231 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 200.252.9.194 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 207.154.242.254 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 50.225.198.67 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 62.213.218.8 -j DROP # NewYorkCoin-seeder:0.01
/sbin/iptables -A INPUT -p tcp -s 73.164.61.211 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 74.124.24.246 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 75.88.232.28 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 76.102.131.12 -j DROP # NewYorkCoin-seeder:0.01
/sbin/iptables -A INPUT -p tcp -s 78.81.182.206 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 78.81.191.136 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 80.82.49.16 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 85.236.188.28 -j DROP # Satoshi:0.8.6.2
/sbin/iptables -A INPUT -p tcp -s 88.99.91.47 -j DROP # CryptoTransfer:1.0.0
/sbin/iptables -A INPUT -p tcp -s 94.130.16.85 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 94.177.201.91 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 95.52.43.220 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 95.52.42.249 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 95.54.68.250 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 95.54.69.24 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 95.68.166.255 -j DROP # ExperiencecoinCore:3.0.0.1
/sbin/iptables -A INPUT -p tcp -s 95.68.196.178 -j DROP # ExperiencecoinCore:3.0.0.1

# If the script has IsRestricted set to Y, then let's open up port 22 for any IP address. But if
# the script has IsRestricted set to N, let's only open up port 22 for local LAN access. This means
# you have to be physically connected (or via Wifi) to SSH to this computer. It isn't perfectly
# secure, but it removes the possibility for an SSH attack from a public IP address. If you
# wanted to completely remove the possibility of an SSH attack and will only ever work on this
# computer with your own physically attached KVM (keyboard, video & mouse), then you can comment
# the following 6 lines. Be careful, if you don't understand what you are doing here, you might
# lock yourself from being able to access this computer. If so, just go through the build
# process again and start over.

if [ "$IsRestricted" = "N" ]; then

	/sbin/iptables -A INPUT -p tcp --dport 22 -j ACCEPT

else

	/sbin/iptables -A INPUT -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT

	/sbin/iptables -A INPUT -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT

	# Secure access from your home/office IP. Customize as you like. [VPN 10 N-West] This is NOT a
	# backdoor into your LynxCI node for the Lynx Developers. You still control the access
	# credentials for your LynxCI node. The only account available is the _lynx_ user account
	# and you control the password for it. The root user account is locked (don't trust us, verify
	# yourself). This firewall entry is for convenience of the Lynx dev team, but also a convenient
	# example of how you can customize the firewall for your own direct access from you home or
	# office IP. Save your change and be sure to execute _/root/LynxCI/installers/firewall.sh_
	# when done.

	/sbin/iptables -A INPUT -p tcp -s 162.210.250.170 --dport 22 -j ACCEPT

fi

/sbin/iptables -A INPUT -p tcp --dport _port_ -j ACCEPT # This node listens for other Lynx nodes on port _port_, so we need to open that port.
/sbin/iptables -A INPUT -p tcp --dport _rpcport_ -j ACCEPT # By default, the RPC port 9223 is opened to the public.
/sbin/iptables -A INPUT -j DROP # We add this last line to drop any other traffic that comes to this computer that doesn't comply with the earlier rules. If previous iptables rules dont match, then drop'em!

# Some system cleanup. If the bootstrap.dat file had been used in the past, it is not flagged as
# old. It is no longer needed so let's delete it if it still exists on the drive.

/bin/rm -rf /root/.lynx/bootstrap.dat.old

#
# Metus est Plenus Tyrannis
#
