#!/bin/bash

# The 'postrotate' argument will force the execution of the firewall.sh script once a log is 
# rotated. This means that IF a log is rotated at 6:25am daily, the firewall will be reset to the 
# most secure status. This creates enough time for an admin to set up the node without getting 
# locked out but also defaults the node to a more secure posture if nothing is changed or updated.

echo "

	_debug_ {
		daily
		rotate 7
		size 10M
		copytruncate
		compress
		notifempty
		postrotate
			/root/LynxCI/installers/firewall.sh
		endscript
	}

	" > /etc/logrotate.d/lynxd.conf
