#!/bin/bash

update_block_explorer () {

    cd /root/LynxBlockExplorer/

    if [ -r "/root/LynxBlockExplorer/.commit.txt" ]; then

            remotehash=`git ls-remote origin -h refs/heads/master | awk '{print $1;exit}'`

            localhash=$(cat /root/LynxBlockExplorer/.commit.txt)

            if [ "$remotehash" != "$localhash" ]; then

                git stash save --keep-index

                git pull https://github.com/doh9Xiet7weesh9va9th/LynxBlockExplorer.git

                user=$(cat /root/.lynx/lynx.conf | egrep 'rpcuser=' | cut -d= -f2)
                #echo "RPC username is $user."
                pass=$(cat /root/.lynx/lynx.conf | egrep 'rpcpassword=' | cut -d= -f2)
                #echo "RPC password is $pass."
                port=$(cat /root/.lynx/lynx.conf | egrep 'rpcport=' | cut -d= -f2)
                #echo "RPC port is $port."
                host=$(cat /etc/hostname)
                #echo "Host is $host."

                sed -i "s/9332/${port}/g" /root/LynxBlockExplorer/settings.json
                sed -i "s/__HOSTNAME__/x${host}/g" /root/LynxBlockExplorer/settings.json
                sed -i "s/__MONGO_USER__/x${user}/g" /root/LynxBlockExplorer/settings.json
                sed -i "s/__MONGO_PASS__/x${pass}/g" /root/LynxBlockExplorer/settings.json
                sed -i "s/__LYNXRPCUSER__/${user}/g" /root/LynxBlockExplorer/settings.json
                sed -i "s/__LYNXRPCPASS__/${pass}/g" /root/LynxBlockExplorer/settings.json

                npm install

            fi

            git ls-remote origin -h refs/heads/master | awk '{print $1;exit}' > /root/LynxBlockExplorer/.commit.txt

    else
            git ls-remote origin -h refs/heads/master | awk '{print $1;exit}' > /root/LynxBlockExplorer/.commit.txt
    fi

}


detect_os () {

    # We are inspecting the local operating system and extracting the full name so we know the
    # unique flavor. In the rest of the script we have various changes that are dedicated to
    # certain operating system versions.

    OS=`cat /etc/os-release | egrep '^PRETTY_NAME=' | cut -d= -f2 -d'"'`

    echo "The local operating system is '$OS'."

}

update_lynx_core () {
    echo "installing last updates."

    cd /root/lynx/
    ./autogen.sh

    if [ "$OS" = "Raspbian GNU/Linux 9 (stretch)" ]; then
        ./configure --enable-cxx --without-gui --disable-wallet --disable-tests --with-miniupnpc --enable-upnp-default
        make
    else
        ./configure --enable-cxx --without-gui --disable-wallet --disable-tests
        make
    fi

    echo "The latest updates of Lynx is being compiled."
}

changed=0

#git remote update && git status -uno | grep -q 'Your branch is behind' && changed=1

if [ $changed = 1 ]; then
    git pull
    update_lynx_core
    echo "Updated successfully";
fi

update_block_explorer