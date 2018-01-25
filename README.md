# LynxNodeBuilder
Create a Lynxd node that serves as a seed node, a miner and a block crawler.

[Lynx FAQ](https://getlynx.io/faq/)
[Lynx News](https://getlynx.io/news/)

## For Ubuntu 16.04 LTS

You can manually enter these three lines, as root, after your OS is installed.

```
$ apt-get update -y && apt-get install git -y
```
```
$ git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /tmp/LynxNodeBuilder
```
```
$ sh /tmp/LynxNodeBuilder/build.sh
```

## For [Raspian Stretch Lite](https://www.raspberrypi.org/downloads/raspbian/) on a Raspberry Pi 3

After you have created your micro SD card from the Raspian ISO, the very first step is to open up access to SSH with your physically attached keyboard;

```
$ sudo touch /boot/ssh
```

Reboot your Pi before the next step. Now you will be able to connect to your Pi over your local network. Figure out it's IP and SSH into it.

The following commands must be done as the root user;

```
$ apt-get update -y && apt-get install git -y
```
```
$ git clone https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder.git /tmp/LynxNodeBuilder
```
```
$ sh /tmp/LynxNodeBuilder/buildPi.sh
```


## How is Lynx an "eco-friendly cryptocurrency"?

According to a recent article in [Wired magazine](https://www.wired.com/story/bitcoin-global-warming/);, “Bitcoin emits the equivalent of 17.7 million tons of carbon dioxide every year.” That’s a big problem! At Lynx, we believe that for cryptocurrency to be considered a secure, financial solution for today’s global marketplace, it must be created with global sustainability in mind. The energy costs of high-volume mining rigs are too demanding and they create an over-reliance on fossil fuels. Lynx code discourages high-volume mining rigs because our code purposefully lacks incentives to mine it for profit. Here are some of the business rules that help us achieve this goal:

1. The mining reward takes one week to “mature.”

2. The individual mining reward is only 1 Lynx (+ fees).

3. The cost of a transaction is 1 Lynx/kb with a cap of 10 Lynx.

Lynx is a cryptocurrency from the past re-designed for the future. We designed Lynx to have minimal environmental impact because we’re committed to creating global solutions and maintaining a small carbon footprint. Lynx business rules encourage the use of low-cost computing (like a Raspberry Pi which only consumes less than 3 watts of electricity) to mine the coin. As a result, the electrical cost to maintain the Lynx network is a fraction of a fraction which results in a low environmental impact. The emphasis on low-cost computing also creates a decentralized, broad miner base which also strengthens the stability and security of the currency.



