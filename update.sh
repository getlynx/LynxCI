#!/bin/bash

update_block_crawler () {

    cd /root/var/www/html/

    if [ -r "/root/var/www/html/.commit.txt" ]; then

            remotehash=`git ls-remote origin -h refs/heads/master | awk '{print $1;exit}'`

            localhash=$(cat /root/var/www/html/.commit.txt)

            if [ "$remotehash" != "$localhash" ]; then

                rm -R /root/var/www/html/*

                git pull https://github.com/getlynx/LynxBlockCrawler.git

                user=$(cat /root/.lynx/lynx.conf | egrep 'rpcuser=' | cut -d= -f2)
                #echo "RPC username is $user."
                pass=$(cat /root/.lynx/lynx.conf | egrep 'rpcpassword=' | cut -d= -f2)
                #echo "RPC password is $pass."
                port=$(cat /root/.lynx/lynx.conf | egrep 'rpcport=' | cut -d= -f2)
                #echo "RPC port is $port."

                sed -i "s/8332/${port}/g" /root/var/www/html/bc_daemon.php
                sed -i "s/username/x${user}/g" /root/var/www/html/bc_daemon.php
                sed -i "s/password/x${pass}/g" /root/var/www/html/bc_daemon.php

            fi

            git ls-remote origin -h refs/heads/master | awk '{print $1;exit}' > cd /root/var/www/html/.commit.txt

    else
            git ls-remote origin -h refs/heads/master | awk '{print $1;exit}' > cd /root/var/www/html/.commit.txt
    fi

}

update_block_crawler