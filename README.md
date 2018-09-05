# Lynx Cryptocurrency Installer (LynxCI)
Creates a Lynx cryptocurrency node that confirms and relays transactions, runs an eco-friendly built-in miner and also creates a local robust Block Explorer website including Lynx development news, real-time miner cost reporting, public API & RPC access points, and Lynx information.

## One line install script

This script supports the following Linux operating systems. [Raspbian for Raspberry Pi](https://www.raspberrypi.org/downloads/raspbian/), Ubuntu 18.04 LTS, Ubuntu 16.04 LTS, Debian 8 and Debian 9

For production (mainnet), you can manually enter this single line, as root, after your OS is installed. It will run in the background, so no need to stay logged in or keep the terminal window open. You can watch it build if you like. The full installation log is saved to /var/log/syslog.
```
$ wget -qO - https://explorer.getlynx.io/setup.sh | bash
```

For development (testnet)
```
$ wget -qO - https://test-explorer.getlynx.io/setup.sh | bash
```

## [LynxCI for Pi](http://cdn.getlynx.io/LynxCI.tar.gz)

The above instructions work fine for a Raspberry Pi 2 or 3 if you want to play, learn and do it manually. But if you want to get your Raspberry Pi up and running quick, the ISO is for you. Simply [download the LynxCI ISO from here](https://getlynx.io/downloads/) and then flash it to an SD card. We have found [Etcher](https://etcher.io) to be very easy to use. Then insert the card into the SD card slot on the bottom of the Raspberry Pi and power it on. No keyboard, mouse or monitor is required. You must plug in an ethernet cable connection to the device; maybe from your home router. That is it. It will be fully functional in about 15 hours. Here is a blog post and video of the [whole process](https://getlynx.io/can-non-techies-mine-lynx-crypto/).

## Help

Helpful videos that answer many questionsa are available on our [Lynx FAQ](https://getlynx.io/faq/).

## What is Lynx?

Lynx is a secure cryptocurrency with fast transaction speeds and low-transaction fees. It’s also eco-friendly & easy-to-use. In 2017, our team upgraded, fixed and rebranded Kittehcoin as Lynx. How? We successfully forked Litecoin and ported the Kittehcoin blockchain history to it. This gives Lynx all the benefits of Litecoin with the full transaction history of Kittehcoin. The upgrades fixed the flaws in the original coin and revived its community of users. It’s cryptocurrency from the past; redesigned for the future.

[Lynx FAQ](https://getlynx.io/faq/)

[Lynx News](https://getlynx.io/news/)

[Lynx Twitter](https://twitter.com/GetlynxIo)

[Lynx Discord](https://discord.gg/5cM3NTF)

## How is Lynx an "eco-friendly cryptocurrency"?

You can read the Lynx whitepaper PDF at the [website](https://getlynx.io).

According to a recent article in [Wired magazine](https://www.wired.com/story/bitcoin-global-warming/);, “Bitcoin emits the equivalent of 17.7 million tons of carbon dioxide every year.” That’s a big problem! At Lynx, we believe that for cryptocurrency to be considered a secure, financial solution for today’s global marketplace, it must be created with global sustainability in mind. The energy costs of high-volume mining rigs are too demanding and they create an over-reliance on fossil fuels. Lynx code discourages high-volume mining rigs because our code purposefully lacks incentives to mine it for profit. Here are some of the business rules that help us achieve this goal:

1. The mining reward takes one week to “mature.”

2. The individual mining reward is only 1 Lynx (+ fees).

3. The cost of a transaction is 0.0001 Lynx/kb.

4. Proof of Work was modified to secure against a 51% attack.

Lynx is a cryptocurrency from the past re-designed for the future. We designed Lynx to have minimal environmental impact because we’re committed to creating global solutions and maintaining a small carbon footprint. Lynx business rules encourage the use of low-cost computing (like a Raspberry Pi which only consumes less than 3 watts of electricity) to mine the coin. As a result, the electrical cost to maintain the Lynx network is a fraction of a fraction which results in a low environmental impact. The emphasis on low-cost computing also creates a decentralized, broad miner base which also strengthens the stability and security of the currency.

