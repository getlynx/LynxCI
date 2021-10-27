#!/bin/bash

config="/home/lynx/.lynx/lynx.conf"

sed -i '/81a3e59444e4/d' $config
sed -i '/addnode=/d' $config

echo "
addnode=node2.getlynx.io
addnode=node3.getlynx.io
addnode=node2.getlynx.club
addnode=node3.getlynx.club
addnode=node2.logware.io
addnode=node3.logware.io
addnode=node2.logware.cloud
addnode=node3.logware.cloud
addnode=node2.logware.club
addnode=node3.logware.club
addnode=node2.logware.us
addnode=node3.logware.us
addnode=node2.logware.net
addnode=node3.logware.net
addnode=node2.getlynx.art
addnode=node3.getlynx.art
addnode=node2.getlynx.cat
addnode=node3.getlynx.cat
addnode=node2.getlynx.org
addnode=node3.getlynx.org
addnode=node.getlynx.xyz
" >> "$config"

sed -i /^$/d $config