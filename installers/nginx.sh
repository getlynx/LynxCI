#!/bin/bash

apt-get -qq install apt-transport-https lsb-release ca-certificates -y &> /dev/null

curl -ssL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg

sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

apt-get -qq update -y &> /dev/null

apt-get -qq install nginx php7.2 php7.2-common php7.2-bcmath php7.2-cli php7.2-fpm php7.2-opcache php7.2-xml php7.2-curl php7.2-mbstring php7.2-zip -y &> /dev/null
