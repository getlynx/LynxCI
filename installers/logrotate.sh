#!/bin/bash

echo "

/root/.lynx/debug.log {
	daily
	rotate 7
	size 10M
	copytruncate
	compress
	notifempty
	missingok
	prerotate
		/root/LynxCI/installers/firewall.sh
	endscript
}

/root/.lynx/testnet4/debug.log {
	daily
	rotate 7
	size 10M
	copytruncate
	compress
	notifempty
	missingok
	prerotate
		/root/LynxCI/installers/firewall.sh
	endscript
}

" > /etc/logrotate.d/lynxd.conf