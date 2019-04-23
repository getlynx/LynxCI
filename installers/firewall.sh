#!/bin/bash

IsRestricted=Y

/sbin/iptables -F # Let's flush any pre existing iptables rules that might exist and start with a clean slate.
/sbin/iptables -I INPUT 1 -i lo -j ACCEPT # We should always allow loopback traffic.

# This line of the script tells iptables that if we are already authenticated, then to ACCEPT
# further traffic from that IP address. No need to recheck every packet if we are sure they
# aren't a bad guy.

/sbin/iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Becuase the Block Explorer or Block Crawler are available via port 80 (standard website port)
# we must open up port 80 for that traffic.

/sbin/iptables -A INPUT -p tcp --dport 80 -j DROP

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
/sbin/iptables -A INPUT -j DROP # We add this last line to drop any other traffic that comes to this computer.

[ -f /root/.lynx/bootstrap.dat.old ] && { /bin/rm -rf /root/.lynx/bootstrap.dat.old; } # If the bootstrap.dat file had been used in the past, lets delete it if it still exists on the drive.
[ ! $(grep 'pi' /etc/passwd) ] && { /usr/sbin/deluser lynx sudo >/dev/null 2>&1; } # Remove the lynx user from the sudo group, except if the host is a Pi. This is for security reasons.

#
# Metus est Plenus Tyrannis
#