#!/bin/bash

update_block_crawler () {

    cd /var/www/html/

    if [ -r "/var/www/html/.commit.txt" ]; then

            remotehash=`git ls-remote origin -h refs/heads/master | awk '{print $1;exit}'`

            localhash=$(cat /var/www/html/.commit.txt)

            if [ "$remotehash" != "$localhash" ]; then

                rm -rf /var/www/html/

                git clone https://github.com/getlynx/LynxBlockCrawler.git /var/www/html/ --quiet

                user=$(cat /root/.lynx/lynx.conf | egrep 'rpcuser=' | cut -d= -f2)
                #echo "RPC username is $user."
                pass=$(cat /root/.lynx/lynx.conf | egrep 'rpcpassword=' | cut -d= -f2)
                #echo "RPC password is $pass."
                port=$(cat /root/.lynx/lynx.conf | egrep 'rpcport=' | cut -d= -f2)
                #echo "RPC port is $port."

                sed -i "s/8332/${port}/g" /var/www/html/bc_daemon.php
                sed -i "s/username/x${user}/g" /var/www/html/bc_daemon.php
                sed -i "s/password/x${pass}/g" /var/www/html/bc_daemon.php

            fi

            git ls-remote origin -h refs/heads/master | awk '{print $1;exit}' > /var/www/html/.commit.txt

    else
            git ls-remote origin -h refs/heads/master | awk '{print $1;exit}' > /var/www/html/.commit.txt
    fi

}


#kill -9 $(pidof lynxd)
#cd /root/lynx
#git pull
#make && make install
#rm -rf /root/.lynx/peers.dat
#rm -rf /root/.lynx/banlist.dat
#./lynxd


update_block_crawler