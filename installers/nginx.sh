#!/bin/bash

wget https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -

echo "deb https://packages.sury.org/php/ stretch main" | sudo tee /etc/apt/sources.list.d/php.list

apt-get -qq update -y

apt-get -qq install -y nginx php7.2 php7.2-common php7.2-bcmath php7.2-cli php7.2-fpm php7.2-opcache php7.2-xml php7.2-curl php7.2-mbstring php7.2-zip
