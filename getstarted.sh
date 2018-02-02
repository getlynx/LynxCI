#!/bin/bash
apt-get update -y && apt-get install git -y
git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /root/LynxNodeBuilder/
chmod 744 -R /root/LynxNodeBuilder/
/root/LynxNodeBuilder/build.sh