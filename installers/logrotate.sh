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
}

/root/.lynx/testnet4/debug.log {
	daily
	rotate 7
	size 10M
	copytruncate
	compress
	notifempty
	missingok
}

" > /etc/logrotate.d/lynxd.conf