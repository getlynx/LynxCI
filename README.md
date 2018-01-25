# LynxNodeBuilder
Create a Lynxd node that serves as a seed node, a miner and a block crawler.

For Ubuntu 16.04 LTS, use build.sh
For Raspberry Pi 3, use buildPi.sh

For Pi, you must open up access with your keyboard, video and mouse (KVM) for access to the device via SSH terminal;

$ sudo touch /boot/ssh

Then via remote connection;

$ apt-get update -y && apt-get install git -y

$ cd /tmp/ && git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git && sh /tmp/LynxNodeBuilder/buildPi.sh