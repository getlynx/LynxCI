# LynxNodeBuilder
Creates a Lynxd node that confirms and relays network transactions, runs an eco-friendly micro-miner and also creates a local Block Crawler website with network news and information.

[Lynx FAQ](https://getlynx.io/faq/)

[Lynx News](https://getlynx.io/news/)

[Lynx Twitter](https://twitter.com/GetlynxIo)

## For [Raspian Lite](https://www.raspberrypi.org/downloads/raspbian/) & Ubuntu 18.04 LTS

You can manually enter these four lines, as root, after your OS is installed.
```
$ apt-get update -y && apt-get install git -y
```
```
$ git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /root/LynxNodeBuilder/
```
```
$ chmod 744 -R /root/LynxNodeBuilder/
```
```
$ /root/LynxNodeBuilder/build.sh
```

## [LynxCI](http://cdn.getlynx.io/LynxCI.tar.gz)

The above instructions work fine for a Raspberry Pi 2 or 3 if you want to play, learn and do it manually. But if you want to get your Raspberry Pi up and running quick, the ISO is for you. Simply [download the LynxCI ISO from here](http://cdn.getlynx.io/LynxCI.tar.gz) and then flash it to an SD card. We have found [Etcher](https://etcher.io) to be very easy to use. Then insert the card into the SD card slot on the bottom of the Raspberry Pi and power it on. No keyboard, mouse or monitor is required. You must plug in an ethernet cable connection to the device; maybe from your home router. That is it. It will be fully functional in about 15 hours. Here is a blog post and video of the [whole process](https://getlynx.io/can-non-techies-mine-lynx-crypto/).

## Extras

If you are interested in changing the default deposit account for the micro-miner, add your Lynx address to /root/LynxNodeBuilder/miner-addresses.txt. Add as many or as few as you like. Currently, the default deposit account will go to the Lynx Core Team and is applied towards the cost of maintaining the seed nodes. If you would like to see it running, log in and enter this command.

```
$ sudo tail -F /root/.lynx/debug.log
```

also, the miner logs to syslog;

```
$ sudo tail -F /var/log/syslog
```

Once you know the IP address of your Pi, you can enter it in your web browser and directly visit it with your favorite browser. Bookmark it and have fun. It will take about 1.5 hours to sync, so be patient. You are now an active member of the Lynx community. Congratulations!

## Don't have a Raspberry Pi?

We like Linode.com and have created a [StackScript for Lynx](https://www.linode.com/stackscripts/view/277281). Create and Log into your Linode.com account and click "Add a Linode". You can get away with a "Nanode 1GB" which costs $5/m. Chose the location of your liking and click "Add this Linode". You will be redirected to the main dashboard and see your Linode hardware provisioned, but it's not running yet. Click the Name it was given (ie. linode54325432) and on the next screen click "Deploy an Image". Here you will be able to select an OS, but don't. Instead, click the link to the right that says "Deploying using StackScripts". Do a search for the Lynx StackScript by searching for 'Lynx'. You will find our's titled "getlynx / Lynx Node Builder". Select it. Now, you can select a swap size (we recommend the largest available) and enter your root password. Be sure to write this down for future reference. Then click "Deploy". The final step is to boot your new Linode. From the main dashboard, select the Linode you created and click the "Boot" button. That is it. Your new Lynx node will build itself and in about 1.5 hours it will be fully synced on the network and micro-mining too. For the sake of security, SSH access is disabled by default. Refer to password info below for how to change this.

### Enable access via SSH

When the LynxNodeBuilder runs, it wraps up by locking down SSH by default. This mean that you can't log into the Pi or your Linode via terminal. But you can change this if you like. 

With the Pi, plug in a keyboard and monitor and use the username ('lynx') and password ('lynx'). (SSH for local DHCP addressing is enabled so if you know the local IP, SSH will work.)

At Linode.com, you can do this via the "Launch Lish Console" link under the Remote Access tab. On a Linode, the default username is 'lynx' and the default password is 'lynx'.

In both cases, be sure to change your password with the 'passwd' command. Then, run the following command as the root user;

```
$ sed -i 's/IsSSH=N/IsSSH=Y/' /root/firewall.sh && /root/firewall.sh
```

REQUIRED STEP: If you do this step and don't change your default password, your Pi will get hacked within a matter of time. Don't forget!

## What is Lynx?

Lynx is a secure cryptocurrency with fast transaction speeds and low-transaction fees. It’s also eco-friendly & easy-to-use. In 2017, our team upgraded and rebranded an existing coin (MEOW) as Lynx. How? We successfully forked Litecoin and ported the Kittehcoin blockchain history to it. This gives Lynx all the benefits of Litecoin with the full transaction history of Kittehcoin. These upgrades fixed the flaws in the original coin and revived its community of users. It’s cryptocurrency from the past; redesigned for the future.

## How is Lynx an "eco-friendly cryptocurrency"?

You can read the Lynx whitepaper PDF at the [website](https://getlynx.io).

According to a recent article in [Wired magazine](https://www.wired.com/story/bitcoin-global-warming/);, “Bitcoin emits the equivalent of 17.7 million tons of carbon dioxide every year.” That’s a big problem! At Lynx, we believe that for cryptocurrency to be considered a secure, financial solution for today’s global marketplace, it must be created with global sustainability in mind. The energy costs of high-volume mining rigs are too demanding and they create an over-reliance on fossil fuels. Lynx code discourages high-volume mining rigs because our code purposefully lacks incentives to mine it for profit. Here are some of the business rules that help us achieve this goal:

1. The mining reward takes one week to “mature.”

2. The individual mining reward is only 1 Lynx (+ fees).

3. The cost of a transaction is 0.0001 Lynx/kb.

Lynx is a cryptocurrency from the past re-designed for the future. We designed Lynx to have minimal environmental impact because we’re committed to creating global solutions and maintaining a small carbon footprint. Lynx business rules encourage the use of low-cost computing (like a Raspberry Pi which only consumes less than 3 watts of electricity) to mine the coin. As a result, the electrical cost to maintain the Lynx network is a fraction of a fraction which results in a low environmental impact. The emphasis on low-cost computing also creates a decentralized, broad miner base which also strengthens the stability and security of the currency.

