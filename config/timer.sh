#!/bin/bash

# systemctl list-timers

systemctl stop update.timer
systemctl disable update.timer
systemctl daemon-reload

echo "
[Unit]
Description=Update LynxCI
[Service]
Type=oneshot
ExecStart=/usr/local/bin/config/update.sh
" > /etc/systemd/system/update.service # Create the systemd service unit

chmod 644 /etc/systemd/system/update.service
chown root:root /etc/systemd/system/update.service

echo "
[Unit]
Description=Update LynxCI on boot
[Timer]
OnBootSec=5min
[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/update.timer # Create the systemd timer unit

chmod 644 /etc/systemd/system/update.timer
chown root:root /etc/systemd/system/update.timer

systemctl daemon-reload
systemctl enable update.timer
systemctl start update.timer
