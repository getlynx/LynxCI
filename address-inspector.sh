#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# This simple script was created to run random checks on the addresses supplied by community miners.
# Some don't do a good job of keeping the minimum balance requirements and it can create an
# ineffiency during the mining process regarding the Rule 2 check. This script saves wasted time.
wget -q https://raw.githubusercontent.com/getlynx/LynxCI/master/address-mainnet.txt -O /tmp/raw.txt
sort -R /tmp/raw.txt | head -n 500 > /tmp/random.txt
for address in $(cat /tmp/random.txt); do curl -w " = $address\r\n" "https://chainz.cryptoid.info/lynx/api.dws?q=getbalance&a=$address" && sleep 2; done
rm -rf /tmp/random.txt && rm -rf /tmp/raw.txt