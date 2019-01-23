#!/bin/bash

# Before we begin, we need to update the local repo's. For now, the update is all we need and the
# device will still function properly.

apt-get -qq update -y

# Some hosting vendors already have these installed. They aren't needed, so we are removing them
# now. This list will probably get longer over time.

apt-get -qq remove -y postfix apache2 pi-bluetooth

# Now that certain packages that might bring an interactive prompt are removed, let's do an upgrade.

apt-get -qq upgrade -y

# We need to ensure we have git for the following step. Let's not assume we already ahve it. Also
# added a few other tools as testing has revealed that some vendors didn't have them pre-installed.

apt-get -qq install -y autoconf automake build-essential bzip2 curl unzip fail2ban g++ gcc git git-core htop libboost-all-dev libcurl4-openssl-dev libevent-dev libgmp-dev libjansson-dev libminiupnpc-dev libncurses5-dev libssl-dev libtool libz-dev make nano pkg-config software-properties-common ca-certificates apt-transport-https

/root/LynxCI/installers/nginx.sh

apt-get -qq autoremove -y