echo "rpcuser=$(date +%N | sha256sum | awk '{print $1}')
rpcpassword=$(date +%N | sha256sum | awk '{print $1}')
rpcport=9332
rpcallowip=0.0.0.0/24
rpcallowip=::/0
rpcworkqueue=256"
