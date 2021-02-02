# [Lynx](https://getlynx.io) Cryptocurrency Installer (LynxCI)

Creates a Lynx cryptocurrency node that confirms and relays transactions, and runs an eco-friendly built-in miner.

## One line install script

This script supports the following Linux operating systems. [Raspberry Pi OS](https://www.raspberrypi.org/software/operating-systems/), Debian 10 (Buster), Ubuntu 20.10 & Ubuntu 20.04 LTS. The script is only recommended for a VPS or local server that has a freshly installed OS with no previously written data. Seriously, don't execute this script on a VPS that has data you care about. This precaution is for your own security.

You can execute the following install script, as 'root', after your OS is installed and updated. Just copy/paste and hit return. 
```
wget -qO - https://getlynx.io/install.sh | bash
```

Alternatively, the following install script can be adjusted to quickly build a node on testnet or mainnet, an alternate CPU mining default, and finally the reset time of the built-in firewall. If you are noob, we recommend the above line instead.
```
wget -O - https://getlynx.io/install.sh | bash -s "[mainnet|testnet]" "[0.01-0.95]" "[300-604900]"
```

The initial setup takes less then 1 minute (depending on the speed of your host), so keep your terminal open until it tells you it's done. The script will reboot the target device when it is done executing. The full installation log is saved to /var/log/syslog.

After the LynxCI node is built, the default user account is 'lynx' and the password will be 'lynx'. You won't be able to log in as 'root' (or 'pi'), as the installer locks those user accounts for security reasons. The 'lynx' user account does get sudo, but after a few days it is removed for additional security. The last step of the build is to reboot the host, so you will know it's done when your host or Pi reboots itself. Some VPS vendors don't reboot well, so check the status of your VPS after about 45 minutes to make sure it came back up. 

After you log into the 'lynx' user account, type 'doc' for a complete built-in set of command options..

## [LynxCI for Pi](https://github.com/getlynx/LynxCI/releases/download/v26-ISO/LynxCI.tar.gz)

The above instructions work fine for a Raspberry Pi 3 or 4 if you want to play, learn and do it manually. But if you want to get your Raspberry Pi up and running quick, the ISO is for you. Simply [download the LynxCI ISO from here](https://getlynx.io/downloads/) and then flash it to an SD card. We have found [the Raspberry Pi Imager](https://www.raspberrypi.org/software/) to be very easy to use. Then insert the card into the SD card slot on the bottom of the Raspberry Pi and power it on. No keyboard, mouse or monitor is required. You must plug in an ethernet cable connection to the device; maybe from your home router. That is it. It will be fully functional in about 15 hours. Here is a blog post and video of the [whole process](https://getlynx.io/can-non-techies-mine-lynx-crypto/).

## Help

Helpful videos that answer many questions are available on our [Lynx FAQ](https://getlynx.io/faq/).

## What is Lynx?

Lynx is a secure cryptocurrency with fast transaction speeds and low-transaction fees. It’s also eco-friendly & easy-to-use. In 2017, our team upgraded, fixed and rebranded Kittehcoin as Lynx. How? We successfully forked Litecoin and ported the Kittehcoin blockchain history to it. This gives Lynx all the benefits of Litecoin with the full transaction history of Kittehcoin. The upgrades fixed the flaws in the original coin and revived its community of users. It’s cryptocurrency from the past; redesigned for the future.

[Lynx FAQ](https://getlynx.io/faq/) | [Lynx News](https://getlynx.io/news/) | [Lynx Twitter](https://twitter.com/GetlynxIo) | [Lynx Discord](https://discord.gg/5cM3NTF)

## How is Lynx an "eco-friendly cryptocurrency"?

You can read the Lynx whitepaper PDF at the [website](https://getlynx.io).

According to a recent article in [Wired magazine](https://www.wired.com/story/bitcoin-global-warming/);, “Bitcoin emits the equivalent of 17.7 million tons of carbon dioxide every year.” That’s a big problem! At Lynx, we believe that for cryptocurrency to be considered a secure, financial solution for today’s global marketplace, it must be created with global sustainability in mind. The energy costs of high-volume mining rigs are too demanding and they create an over-reliance on fossil fuels. Lynx code discourages high-volume mining rigs because our code purposefully lacks incentives to mine it for profit. Here are some of the business rules that help us achieve this goal:

1. The mining reward takes one week to “mature.”

2. The individual mining reward is only 1 Lynx (+ fees).

3. The cost of a transaction is 0.0001 Lynx/kb.

4. Proof of Work was modified to better secure against a 51% attack.

Lynx is a cryptocurrency from the past re-designed for the future. We designed Lynx to have minimal environmental impact because we’re committed to creating global solutions and maintaining a small carbon footprint. Lynx business rules encourage the use of low-cost computing (like a Raspberry Pi which only consumes less than 3 watts of electricity) to mine the coin. As a result, the electrical cost to maintain the Lynx network is a fraction of a fraction which results in a low environmental impact. The emphasis on low-cost computing also creates a decentralized, broad miner base which also strengthens the stability and security of the currency.

## Bootstrap File

A (relatively) current bootstrap file can be downloaded [here](https://github.com/getlynx/LynxBootstrap/releases). Any remaining blocks will be synced automatically. The bootstrap is used automatically in the LynxCI install.
