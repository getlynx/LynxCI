#!/bin/bash

echo "update.service: Run the date command." | systemd-cat -p info
date





echo "update.service: Run the remove command." | systemd-cat -p info
rm -rf /usr/local/bin/config/updateTest.sh