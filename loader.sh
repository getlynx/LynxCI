#!/bin/bash
apt-get update -y &> /dev/null
apt-get upgrade -y &> /dev/null
apt-get install git -y &> /dev/null
git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /root/LynxNodeBuilder/
chmod 744 -R /root/LynxNodeBuilder/
/root/LynxNodeBuilder/install.sh