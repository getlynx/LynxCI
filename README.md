# LynxNodeBuilder
Create a Lynxd node that serves as a seed node, a miner and a block crawler.

## For Ubuntu 16.04 LTS, use build.sh

## For Raspberry Pi 3, use buildPi.sh

For Pi, you must open up access with your keyboard, video and mouse (KVM) for access to the device via SSH terminal;

```
sudo touch /boot/ssh
```

Reboot your Pi before the next step.

Then via remote connection, as root user;

```
apt-get update -y && apt-get install git -y
```
```
git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /tmp/LynxNodeBuilder
```
```
sh /tmp/LynxNodeBuilder/buildPi.sh
```