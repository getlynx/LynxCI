#!/bin/bash

if [ "x${1}" = "x" ]; then
	echo "usage: ./${0} \"http://<collector_ip_address>:<port>/\""
	exit 1
fi
 
url=${1}

height=$(/root/lynx/src/lynx-cli getblockcount)

ip=$(ip ro get 8.8.8.8 | grep dev | awk -F' ' '{ print $7 }')
int=$(ip ro get 8.8.8.8 | grep dev | awk -F' ' '{ print $5 }')
mac=$(ip link show $int | grep ether | awk -F' ' '{ print $2 }')

data="{\"block_height\":$height,\"local_ip\":\"$ip\",\"mac_address\":\"$mac\"}"
header="Content-Type:application/json"

wget -SqO- --post-data=$data --header=$header $url > /dev/null 2>&1