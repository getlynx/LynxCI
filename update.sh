#!/bin/bash

# Mining reward addresses that are stored with LynxCI are subject to change and get updated. This
# function allows for that. We delete both the testnet and mainnet files, pull down the new,
# versions and the we update the permissions on the file. It is assumed that no spaces will be in
# the file.

refresh_mining_addresses () {

    rm -rf /root/LynxNodeBuilder/miner-address*
    cd ~/LynxNodeBuilder && curl -s https://raw.githubusercontent.com/doh9Xiet7weesh9va9th/LynxNodeBuilder/master/miner-addresses.txt > /root/LynxNodeBuilder/miner-addresses.txt
    cd ~/LynxNodeBuilder && curl -s https://raw.githubusercontent.com/doh9Xiet7weesh9va9th/LynxNodeBuilder/master/miner-addresses-testnet.txt > /root/LynxNodeBuilder/miner-addresses-testnet.txt
    chmod 744 /root/LynxNodeBuilder/miner-address*

}

update_block_explorer () {

    cd /root/LynxExplorer/

    if [ -r "/root/LynxExplorer/.commit.txt" ]; then

            remotehash=`git ls-remote origin -h refs/heads/master | awk '{print $1;exit}'`

            localhash=$(cat /root/LynxExplorer/.commit.txt)

            if [ "$remotehash" != "$localhash" ]; then

                git pull https://github.com/doh9Xiet7weesh9va9th/LynxExplorer.git

                npm install

                pm2 restart 0

            fi

            git ls-remote origin -h refs/heads/master | awk '{print $1;exit}' > /root/LynxExplorer/.commit.txt

    else
            git ls-remote origin -h refs/heads/master | awk '{print $1;exit}' > /root/LynxExplorer/.commit.txt
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

refresh_mining_addresses

update_block_explorer