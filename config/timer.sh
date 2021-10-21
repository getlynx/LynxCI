#!/bin/bash

echo "
[Unit]
Description=Update LynxCI

[Service]
Type=oneshot
ExecStart=/usr/bin/wget -O - https://raw.githubusercontent.com/getlynx/LynxCI/master/config/update.sh | bash
" > /etc/systemd/system/update.service # Create the systemd service unit

chmod 644 /etc/systemd/system/update.service
chown root:root /etc/systemd/system/update.service

echo "
[Unit]
Description=Update LynxCI on boot

[Timer]
OnBootSec=5min
Unit=update.service

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/update.timer # Create the systemd timer unit

chmod 644 /etc/systemd/system/update.timer
chown root:root /etc/systemd/system/update.timer

systemctl enable update.timer