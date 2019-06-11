#!/bin/bash

IsRestricted=Y # If the script has IsRestricted set to Y, then let's open up port 22 for any IP address.
iptables -F # Let's flush any pre existing iptables rules that might exist and start with a clean slate.
iptables -I INPUT 1 -i lo -j ACCEPT # We should always allow loopback traffic.
iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # If we are already authenticated, then ACCEPT further traffic from that IP address.
iptables -I INPUT 3 -p tcp --dport 80 -j DROP # Because the Block Crawler is available via port 80 we MIGHT open up port 80 for that traffic, later.
iptables -I INPUT 4 -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT # Always allow local LAN access.
iptables -I INPUT 5 -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT # Always allow local LAN access.
iptables -I INPUT 6 -p tcp --dport _port_ -j ACCEPT # This node listens for other Lynx nodes on port _port_, so we need to open that port.
iptables -I INPUT 7 -p tcp --dport _rpcport_ -j ACCEPT # By default, the RPC port 9223 is opened to the public.
[ "$IsRestricted" = "N" ] && iptables -I INPUT 8 -p tcp --dport 22 -j ACCEPT
# Secure access from your home/office IP. Customize as you like. [VPN 10 N-West] This is NOT a backdoor into your LynxCI node for the Lynx Developers. You still
# control the access credentials for your LynxCI node. The only account available is the _lynx_ user account and you control the password for it. The root user
# account is locked (don't trust us, verify yourself). This firewall entry is for convenience of the Lynx dev team, but also a convenient example of how you can
# customize the firewall for your own direct access from you home or office IP. Save your change and be sure to execute _/root/LynxCI/installers/firewall.sh_ when done.
[ "$IsRestricted" = "Y" ] && iptables -I INPUT 8 -p tcp -s 162.210.250.170 --dport 22 -j ACCEPT 
iptables -I INPUT 9 -j DROP # We add this last line to drop any other traffic that comes to this computer.
[ -f /root/.lynx/bootstrap.dat.old ] && rm -rf /root/.lynx/bootstrap.dat.old # Lets delete it if it still exists on the drive.
[ "$isPi" = "0" ] && deluser lynx sudo >/dev/null 2>&1 # Remove the lynx user from the sudo group, except if the host is a Pi. This is for security reasons.