CONF_DIR="/root/.lynx/"
CONF_FILE="${CONF_DIR}/lynx.conf"
GIT_URL="https://github.com/getlynx/lynx.git"
GIT_BRANCH="master"
GIT_DIR="/root/lynx"
SSL_VERSION="1.0" # <-- DEBIAN
#SSL_VERSION="" # <-- UBUNTU (blank)
LIBRARIES="libssl${SSL_VERSION}-dev libboost-all-dev libevent-dev libminiupnpc-dev"
DEV_TOOLS="build-essential libtool autotools-dev autoconf cmake pkg-config bsdmainutils git"

# Ubuntu 16.04 Requirement
#add-apt-repository -y ppa:bitcoin/bitcoin
#apt-get -y update
#apt install -y libdb4.8-dev
#apt install -y libdb4.8++-dev

# Install Boostrap First
mkdir ${CONF_DIR}
wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.5/bootstrap.tar.gz -O - | tar -xz -C ${CONF_DIR}

cd /root
apt-get update
apt-get -y install ${DEV_TOOLS} ${LIBRARIES}
git clone --branch ${GIT_BRANCH} --single-branch ${GIT_URL} ${GIT_DIR}
cd ${GIT_DIR}
./autogen.sh
./configure --without-gui --disable-tests --disable-bench
make -j$(nproc)
make install
cd /root
touch ${CONF_FILE}
cat "lynx.conf" > ${CONF_FILE}
printf "Done.\n\n"




-----






rm -Rf /root/lynx/
rm -Rf /root/lynx/description-pak/

git clone https://github.com/getlynx/Lynx.git /root/lynx/

GIT_URL="https://github.com/getlynx/lynx.git"
GIT_BRANCH="master"
GIT_DIR="/root/lynx/"
LIBRARIES="libssl-dev libboost-all-dev libevent-dev libminiupnpc-dev"
DEV_TOOLS="build-essential libtool autotools-dev autoconf cmake pkg-config bsdmainutils git checkinstall htop"

apt update -y
apt upgrade -y
apt dist-upgrade -y

apt-get -y install ${DEV_TOOLS} ${LIBRARIES}

rm -rf /root/lynx/db4 && mkdir -p /root/lynx/db4
cd /root/lynx/

# Debian 9 Requirement
wget http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz
tar -xzf db-4.8.30.NC.tar.gz
cd db-4.8.30.NC/build_unix/
../dist/configure --enable-cxx --disable-shared --with-pic --prefix=/root/lynx/db4
make && make install

cd /root/lynx/

./autogen.sh
./configure LDFLAGS="-L/root/lynx/db4/lib/" CPPFLAGS="-I/root/lynx/db4/include/ -O2" --without-gui --disable-tests --disable-bench
make
#make install
checkinstall -D --install=no --pkgname=lynxd --pkgversion=16.3.5 --include=/root/.lynx/lynx.conf
