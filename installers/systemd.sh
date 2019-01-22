#!/bin/bash

echo "

	#!/bin/bash

	[Unit]
	Description=lynxd
	After=network.target

	[Service]
	Type=simple
	User=root
	Group=root
	WorkingDirectory=/root/lynx
	ExecStart=/root/lynx/src/lynxd -daemon=0 -printtoconsole
	ExecStop=/root/lynx/src/lynx-cli stop

	Restart=always
	RestartSec=10

	[Install]
	WantedBy=multi-user.target

	" > /etc/systemd/system/lynxd.service

systemctl daemon-reload

systemctl enable lynxd

systemctl start lynxd

# systemctl restart lynxd

# systemctl stop lynxd
