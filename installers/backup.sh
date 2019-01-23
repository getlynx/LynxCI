#!/bin/bash

### Set timestamp and file paths
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
FULL_PATH_TO_BACKUP_DIR="/root/archive"
FULL_PATH_TO_WALLET_DAT="/root/.lynx/wallet.dat"
RPC_COMMAND_DUMPWALLET="/root/lynx/src/lynx-cli backupwallet /root/archive/wallet.dat"

### Copy wallet file to timestamped backup folder
cp "${FULL_PATH_TO_WALLET_DAT}" "${FULL_PATH_TO_BACKUP_DIR}/${TIMESTAMP}-wallet.dat"

${RPC_COMMAND_DUMPWALLET}

### Zip up then delete the original timestamped folder
cd ${FULL_PATH_TO_BACKUP_DIR}
tar -zcf ${TIMESTAMP}.tar.gz ${TIMESTAMP}
rm -R ${TIMESTAMP}

### Prune the folder after 7 days worth of bi-hourly backups (7 * 12 = 84 files)
ls -t | sed -e '1,84d' | xargs -rd '\n' rm