CONF_DIR="/root/.lynx/"
CONF_FILE="${CONF_DIR}/lynx.conf"
GIT_URL="https://github.com/getlynx/lynx.git"
GIT_BRANCH="master"
GIT_DIR="/root/lynx"
#SSL_VERSION="1.0.0" # <-- DEBIAN
SSL_VERSION="" # <-- UBUNTU (blank)
LIBRARIES="libssl${SSL_VERSION}-dev libboost-all-dev libevent-dev libminiupnpc-dev"
DEV_TOOLS="build-essential libtool autotools-dev autoconf cmake pkg-config bsdmainutils git checkinstall htop"

# Install Boostrap First
mkdir ${CONF_DIR}
wget https://github.com/getlynx/Lynx/releases/download/v0.16.3.5/bootstrap.tar.gz -O - | tar -xz -C ${CONF_DIR}

touch ${CONF_FILE}

cd /root
apt-get update
apt-get -y install ${DEV_TOOLS} ${LIBRARIES}
git clone --branch ${GIT_BRANCH} --single-branch ${GIT_URL} ${GIT_DIR}
cd ${GIT_DIR}
./autogen.sh
./configure --without-gui --disable-tests --disable-bench
make -j$(nproc)
#make install
checkinstall -D --install=no --pkgname=lynxd --pkgversion=16.3.5 --include=/root/.lynx/lynx.conf