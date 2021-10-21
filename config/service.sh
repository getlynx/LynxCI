#!/bin/bash

# Update the Message of the Day display content
file="https://raw.githubusercontent.com/getlynx/LynxCI/master/config/motd.sh"
local=$(md5sum /usr/local/bin/config/motd.sh | head -c 32)
remote=$(wget -qO - $file | md5sum | head -c 32)

if [ "$local" != "$remote" ]; then 
	wget -P /usr/local/bin/config/ $file | bash
fi

