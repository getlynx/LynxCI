#!/bin/bash

CONF_DIR="/root/.lynx/"
CONF_FILE="${CONF_DIR}/lynx.conf"
GIT_URL="https://github.com/getlynx/lynx.git"
GIT_BRANCH="master"
GIT_DIR="/root/lynx"
#SSL_VERSION="1.0.0" # <-- DEBIAN
SSL_VERSION="" # <-- UBUNTU (blank)
LIBRARIES="libssl${SSL_VERSION}-dev libboost-all-dev libevent-dev libminiupnpc-dev"
DEV_TOOLS="build-essential libtool autotools-dev autoconf cmake pkg-config bsdmainutils git"

# Ubuntu 16.04 Requirement
add-apt-repository -y ppa:bitcoin/bitcoin
apt-get -qq update -y
apt-get -qq install -y libdb4.8-dev
apt-get -qq install -y libdb4.8++-dev

# Install Boostrap First
mkdir ${CONF_DIR}
wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.5/bootstrap.tar.gz -O - | tar -xz -C ${CONF_DIR}

touch ${CONF_FILE}

cd /root
apt-get -qq update -y
apt-get -qq install -y ${DEV_TOOLS} ${LIBRARIES}
git clone --branch ${GIT_BRANCH} --single-branch ${GIT_URL} ${GIT_DIR}
cd ${GIT_DIR}
./autogen.sh
./configure --without-gui --disable-tests --disable-bench
make -j$(nproc)
make install

# Build the DEB
rm -Rf /root/lynxd
rm -Rf /root/lynxd/DEBIAN/postinst*
rm -Rf /root/lynxd_16.3.5-1_amd64.deb
mkdir lynxd && mkdir lynxd/DEBIAN
mkdir -p lynxd/usr/local/bin/
cp /usr/local/bin/lynx* lynxd/usr/local/bin/

echo "

Package: lynxd
Version: 0.16.3.5
Maintainer: Lynx Core Development Team
Architecture: all
Description: https://getlynx.io

" > /root/lynxd/DEBIAN/control

#wget http://cdn.getlynx.io/postinst ‐P /lynxd/DEBIAN 

chmod -R 755 /root/lynxd/*

cd /root/ && dpkg-deb --build lynxd

mv lynxd.deb lynxd_16.3.5-1_amd64.deb

# curl -sLO http://cdn.getlynx.io/lynxd_16.3.5-1_amd64.deb && dpkg -i lynxd_16.3.5-1_amd64.deb

#curl -sLO http://cdn.getlynx.io/lynxd.deb && dpkg -i lynxd.deb





