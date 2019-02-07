#!/bin/bash

# Lets not assume wget and logrotate is already installeed on the target host, so let's install
# them first.

apt-get -qq install -y wget logrotate

# Below we are creating the default lynx.conf file. This file is created with default RPC 
# credentials and it sets up the networking with settings that testing has found to work well.
# Of course, you can edit it further if you like, but this default file is the recommended start
# point.

echo "

# The following RPC credentials are created at build time and are unique to this host. If you
# like, you can change them, but you are encouraged to keep very complex values for each. If an
# attacker gains RPC access to this host they might be able to steal your Lynx. Understanding
# that, the wallet is disabled by default so the risk of loss is zero.

rpcuser=[yoursupersecretusername]
rpcpassword=[yoursupersecretpassword]
rpcport=9332

# The following settings will allow a connection from any external host. The two entries
# define that any IPv4 or IPv6 address will be allowed to connect. The default firewall settings
# also allow the traffic because the RPC port is open by default. If you are setting up a remote
# connection, all you will need is the above RPC credentials. No further network configuration
# is needed. To secure the node from repeated connetion attempts or to restrict connections to
# your IP's only, change the following values as needed.

rpcallowip=0.0.0.0/24
rpcallowip=::/0

# The debug log (/root/.lynx/debug.log) is capable of outputing a massive amount of data. If you
# are chasing a bug, set the argument to 'debug=1'. It isn't recommended to leave that log level
# intact though. The default state of this build is to output the BuiltinMiner info, so if you
# don't want to see it, you can change the argument to 'debug=0'. We think the BuiltinMiner info
# is fun though, but on a Pi, to reduce SD card writes, it might be most efficient to go with
# the least amount of debug info, so change it to 'debug=0'.

debug=miner
debuglogfile=debug.log
shrinkdebugfile=0

# By default, wallet functions in LynxCI are disabled. This is for security reasons. If you
# would like to enable your wallet functions, change the value from '1' to '0' in the
# 'disablewallet' parameter. Then restart lynxd to enact the change. Of course, you can do the
# reverse action to disable wallet functions on this node. You can always check to see if
# wallet functions are enabled with '$ /root/lynx/src/lynx-cli help', looking for the
# '== Wallet ==' section at the bottom of the help file.

disablewallet=1

# The following list of nodes are maintained for faster detection of peers and network sync.

addnode=node01.getlynx.io
addnode=node02.getlynx.io
addnode=node03.getlynx.io
addnode=node04.getlynx.io
addnode=node05.getlynx.io

# The following addresses are known to pass the validation requirements for HPoW. If you would
# like to earn your own mining rewards, you can add/edit/delete this list with your own
# addresses (more is better). You must have a balance of between 1,000 and 100,000,000 Lynx in
# each of the Lynx addresses in order to win the block reward. Alternatively, you can enable
# wallet functions on this node, deposit Lynx to the local wallet (again, between 1,000 and
# 100,000,000 Lynx) and the miner will ignore the following miner address values.

mineraddress=KKMeTYLM6LrhFc8Gq1uYSua4BLgmFPaZrX
mineraddress=KVKrkxGcUo9wii59ashrbqKub5CpggiFQz
mineraddress=KMPxdPMwJb3rn1dLx9L2xxxUgiZiGRC8Um
mineraddress=KERgGnd5vCMkdFbGynrGeqhBnitz1zrg22
mineraddress=KWJfZ9qQ4aAiieB9jh8iJk5ttxhWV566RU
mineraddress=KVaeY15ikttZM2rwBh694LPC1qZHgKvTsg
mineraddress=KA8VJVzqy7xo6AEYRxAa8WHLqqScwGHmGx
mineraddress=KJhTW2s2q1gvpaWLWSdmwLa9dvvqmAcnzj
mineraddress=KTT3d4obtRGdkyLeUQQk75VKkBavXcXcFn
mineraddress=KH5Lkvw511qAgUeoqxNa9BSGdZuok7q6ow
mineraddress=KJErWXjc4ycq436Tonf5dy8RFhF1SiuSM2
mineraddress=KRJf4FQB6GAk2E6dXeJ5osbd1GsHjW6mWf
mineraddress=KDjfv9bUfyfFfuVgyhTazreESRfHpYnMi3
mineraddress=KBywa5qcAZTB3CC7vCzxVeU8eYW6PBdSfJ
mineraddress=KU7tLLoa1geou57GWoEY7MXUpQNetRbuNy
mineraddress=K7XNmz2h2PgyGC8aYhXHJ8W58WnjZgrU85
mineraddress=KT4nWz8PEAyAiBQTXu6T9z7TZCe5h2pUep
mineraddress=KG5unFERmH6Qsvt3muci4ZeKgtmUaw7TdQ
mineraddress=KRgVAxFgfjkYKovizRG1DfkLKd59rpEHxe
mineraddress=KMoRtp69iMVVSWUPVwdota6HSCkP2yChFH
mineraddress=KNcAXmZY9CKUesky2dRbKWJM5PZwQmUNYk
mineraddress=KSX55i4ef1y1kYtHu6E7EUt7Fx4GAg9yzm
mineraddress=K8QGUNxc86Ahr9CSW1NyT2LGDC8BAUk6iM
mineraddress=KRgVAxFgfjkYKovizRG1DfkLKd59rpEHxe
mineraddress=KMoRtp69iMVVSWUPVwdota6HSCkP2yChFH
mineraddress=KNcAXmZY9CKUesky2dRbKWJM5PZwQmUNYk
mineraddress=KR9QTmep2LYt53oS9Ypn7Qo6mjd9jNMvw5
mineraddress=KKpNgtMs8kjpxB9EHmLVyhsdfcA6tyZ2g8
mineraddress=K7GMcJ4idxwhbusn8sTBotJbsRZ8FU22cu
mineraddress=KFgo4RmUiFX8FAg3sk8ZRptqmTD9Nk8u2w
mineraddress=KV3fxxtbb1gwY69tAsqkq8rBHzMczia7To
mineraddress=KHHHfhcethqahpN7aAeJ9JiBDGtjsW89oM
mineraddress=KVgBWE4xibFrRzN1X7Cv3nVymTg3EcnePm
mineraddress=KPhTE61wshvyiDHFLLLvZ3rBhrGjWruWdh
mineraddress=KLpTz6JbUEkrxNTs24gftPxsgyGG53qKsD
mineraddress=KBw3LHq6TNDLTL35QFTfwyGvDA1YA4xwq7
mineraddress=KDWbrVGdb9M5MuH3q8XP9SuNQweX4g1w7C
mineraddress=KGDFGZuwCnT9kcBNWPtQVuZdZ1AoiaGYUy
mineraddress=KFaLZ37WgSXeUUpQZAXamMDfDkS96Fpp6W
mineraddress=KSbtHFRoaj8Vb5EespmCEbtNJGG7UtM2U2
mineraddress=KUn12PLFXUaVwneQMNp6kiZ2c9rUVPkDjp
mineraddress=KHXGt1Pn1yVXvYQmLTuG8pYqYH29t6p8pL
mineraddress=K85WRcMbcuWi9T3JsH7NhZp8Tb3nNmcYVS
mineraddress=KMzbPq5YvdCpNiVtECk9VVVGbnxhP6V7ch
mineraddress=K8fQpFnHWw2iBHycR1B1NWJBCGSojEhjst
mineraddress=K8yBpqfkP2gg7buhNhWM7s3PqBsCA7PW9r
mineraddress=KSGe8xZbM9NfeQnjX9fyMbqLaGQTRUS5Jh
mineraddress=KBw2p51RrrbcceRoSbvb6ZkX437kuQM99F
mineraddress=KDv7VKpixza5u51L5gmPNtUyRWpkaJBYg3
mineraddress=KTHz2RJrt8SoDXbzwVJ3Znybn3mZNJwscs
mineraddress=KB7SVrCBjKTSZSxqNhX7zfpNK68MPRG95k
mineraddress=K95nM1gWhRMRvgLZTyi61tceYjfp5Ys71u
mineraddress=KJevkjENSeBzVp5MnSvyNqnemF9rn6unYo
mineraddress=KQqL8U2vD5QpZg8MJ47cVj2sRbo7gV4tu5
mineraddress=KQpa4GDG5GcwrinjpDmUgpAaYgRbfNGUMK
mineraddress=KGFx9JD1dFY4dtFdLqw1d3ZQnWL6ws6nLy
mineraddress=KNoWE13FPBDUuqyK1DUT7qnJx9jVfqkeGc
mineraddress=KMqkxAmFYpMDEyEA5QmbZZrwXtu6pwuv61
mineraddress=KS2Gg8MvcJmLNPK7mQdoG6DJJaZxQ4neej
mineraddress=KBmLgzVMiKbcMuaoJeoPNs5R98tAHYM515
mineraddress=KCtFzP3fGn1ZxRiNVFeCnGuwiy7qsSvB22
mineraddress=K9WR6ZTB5X4hoWvTUK1xR4ddWUSX9qMeS4
mineraddress=KSXLSbsoovJepb9x1sczDRNyTvDYEfZZ2k
mineraddress=KNv9XbCfshP4vV9GN7p6KYGEPqYFc4Ei6c
mineraddress=KRUrR4beUxL5AsyVduL5KT7BNHsbkA9Mh2
mineraddress=K9URJRCsL6nrYMXVA6kPBVq5Db8gW5iVEQ
mineraddress=KNYnVkhaQehdbKSqy4a3AiZGBAYQkqemPF
mineraddress=KExtMudoDex2bckdwhoi2jJxpPMTwpvoSd
mineraddress=KHCqKmt8B3zgQ6z3XWGhhPLuLWvsJiwy3Q
mineraddress=KNZLV7CcBgXR87xi7NCyhGojaJrWHg63FC
mineraddress=K8cckpj6R5yBPNHfBpfP3mm9Joo2VgRWSd
mineraddress=KAQuZ4eTzTQ9AR6kgHXay6DbVXBACwfJpK
mineraddress=KQ69GDCDVcd1ar6gFqUHhLzUCa1eG6QK2u
mineraddress=KFj36awh9AaAK3pxKW8E7RmMQf1P17VNdr
mineraddress=K9LLEtQyw32QuhsrdQuf9sYAiMkdNnTvHh
mineraddress=KJfbyn79urpMCaSH3LbN5THz9BFzjpbbXP
mineraddress=KJeTy4YpEB4vfACi8hTDhha8XREkNwfCo5
mineraddress=KVe8M69xcaciUx2stEYPXCvfEBouJPLVCa
mineraddress=K7h1XerggVEGXLSMMxfmHPgL7FbHH2rq3V
mineraddress=KPTaCQ42qSrMRFh8YVVf8cFLpU5tFbVE5M
mineraddress=KQkcW2vQFqpYJ2WeP2mKRJFE9deRUoh6ZL
mineraddress=KGsXZ9f2oPaw2ijN9d3hLqawDAT4Ymj83M
mineraddress=KEnnvXuz63FBtSaf6ugHJ3KJ1vqYExJMvr
mineraddress=KREsateb18vgKzPvfqCkXetKdTEdhCZpQL
mineraddress=KQf9V3AMF8hjYaxNEwxR7vfgDERLajWm56
mineraddress=KAMx31Z7SjW3gZmtGA1Rma5WHv7ZVkZrdu
mineraddress=KA33R8toK25omLrg4TJ4qE5YZQZH9w7icv
mineraddress=KNuWFu2oj9q15C3y2NhjAufdFLhpiyHR7W
mineraddress=KBxpSv3tDPEq2NdiayWu6mLKaJCLR3bESu
mineraddress=KM1VcC7ppY7fmHD8BGoyoyLeR9bTiuQXsY
mineraddress=KVm5auwacM2BRKmtftgPu4wqQyiG56Gsmx
mineraddress=KBp7DvcmhonVqy3Es73dQFTtjCPGrNkPDk
mineraddress=KKuxb5KQCF13D7kDL6rMPx5hNTtDGvqiTV
mineraddress=KC4GBFAbsgRGvdrY9aQgU4XNX85mAFmHHU
mineraddress=KGC3UkcLS2Yq5ZojhuHu5T7XBpf3DJKJKp
mineraddress=KEM9dV7pP1YZkTA3gYpfydSqQUyFzfmwrm
mineraddress=K9JgSJZW6koYKQ4rPmZ7FwRH6dpy7SHVUD
mineraddress=KCeHBX64PT1WvuV4mrSnS7DoyLvpmZ5XXK

# It is highly unlikely you need to change any of the following values unless you are tinkering
# with the node. If you do decide to tinker, make a backup of this file first.

listen=1
daemon=1
port=$port
rpcbind=127.0.0.1
rpcbind=::1
rpcworkqueue=64
listenonion=0
upnp=1
dbcache=100
txindex=1

host=[superSecretTipsyID]

" > /root/.lynx/lynx.conf

# Let's pull down the latest boostrap file for production.

wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.5/bootstrap.tar.gz -O - | tar -xz -C /root/.lynx/

# Reset permissions on the respective files we created.

chown -R root:root /root/.lynx/*

# To better manage the debug log, lets set up logrotate on it so it doesnt take over the 
# target OS drive.

echo "

	/root/.lynx/debug.log {
		daily
		rotate 7
		size 10M
		compress
		delaycompress
		notifempty
	}

	" > /etc/logrotate.d/lynxd.conf

# We want lynxd to run as a system service, so lets set up the systemd service

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
	ExecStart=/root/lynx/src/lynxd -daemon=0
	ExecStop=/root/lynx/src/lynx-cli stop

	Restart=always
	RestartSec=10

	[Install]
	WantedBy=multi-user.target

	" > /etc/systemd/system/lynxd.service

systemctl daemon-reload

systemctl enable lynxd

systemctl start lynxd
