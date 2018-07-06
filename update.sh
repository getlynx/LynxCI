#!/bin/bash

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

git remote update && git status -uno | grep -q 'Your branch is behind' && changed=1

if [ $changed = 1 ]; then
    git pull
    update_lynx_core
    echo "Updated successfully";
fi

