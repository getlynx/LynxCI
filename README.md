# LynxNodeBuilder
Creates a Lynxd node that confirms and relays network transactions, runs an eco-friendly micro-miner and also creates a local Block Crawler website with network news and information.

[Lynx FAQ](https://getlynx.io/faq/)

[Lynx News](https://getlynx.io/news/)

[Lynx Twitter](https://twitter.com/GetlynxIo)

## For [Raspian Lite](https://www.raspberrypi.org/downloads/raspbian/), Ubuntu 16.04 LTS, Debian 8 & Debian 9

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

## LynxOS

The above instructions work fine for a Raspberry Pi 2 or 3 if you want to play, learn and do it manually. But if you want to get your Raspberry Pi up and running quick, the ISO is for you. Simply [download the Lynx ISO from here](http://cdn.getlynx.io/LynxOS.tar.gz) and then flash it to an SD card. We have found [Etcher](https://etcher.io) to be very easy to use. Then insert the card into the SD card slot on the bottom of the Raspberry Pi and power it on. No keyboard, mouse or monitor is required. You must plug in an ethernet connection to the device; maybe from your home router. That is it. It will be fully functional in about 15 hours.

## Extras

If you are interested in changing the default deposit account for the micro-miner, review the code in /root/init.sh. You can customize it as you like. Currently, the default deposit account will go to the Lynx Core Team. If you would like to 'see' it running, you can log in as root and enter this command.

```
$ tail -F ~/.lynx/debug.log
```

also, the miner logs to syslog;

```
$ tail -F /var/log/syslog
```

Once you know the IP address of your Pi, you can enter it in your web browser and directly visit it with your favorite browser. Bookmark it and have fun. It will take about 15 hours to sync, so be patient. You are now an active member of the Lynx community. Congratulations!

## What is Lynx?

Lynx is a secure cryptocurrency with fast transaction speeds and low-transaction fees. It’s also eco-friendly & easy-to-use. In 2017, our team upgraded and rebranded an existing coin (MEOW) as Lynx. How? We successfully forked Litecoin and ported the Kittehcoin blockchain history to it. This gives Lynx all the benefits of Litecoin with the full transaction history of Kittehcoin. These upgrades fixed the flaws in the original coin and revived its community of users. It’s cryptocurrency from the past; redesigned for the future.

## How is Lynx an "eco-friendly cryptocurrency"?

According to a recent article in [Wired magazine](https://www.wired.com/story/bitcoin-global-warming/);, “Bitcoin emits the equivalent of 17.7 million tons of carbon dioxide every year.” That’s a big problem! At Lynx, we believe that for cryptocurrency to be considered a secure, financial solution for today’s global marketplace, it must be created with global sustainability in mind. The energy costs of high-volume mining rigs are too demanding and they create an over-reliance on fossil fuels. Lynx code discourages high-volume mining rigs because our code purposefully lacks incentives to mine it for profit. Here are some of the business rules that help us achieve this goal:

1. The mining reward takes one week to “mature.”

2. The individual mining reward is only 1 Lynx (+ fees).

3. The cost of a transaction is 1 Lynx/kb with a cap of 10 Lynx.

Lynx is a cryptocurrency from the past re-designed for the future. We designed Lynx to have minimal environmental impact because we’re committed to creating global solutions and maintaining a small carbon footprint. Lynx business rules encourage the use of low-cost computing (like a Raspberry Pi which only consumes less than 3 watts of electricity) to mine the coin. As a result, the electrical cost to maintain the Lynx network is a fraction of a fraction which results in a low environmental impact. The emphasis on low-cost computing also creates a decentralized, broad miner base which also strengthens the stability and security of the currency.



