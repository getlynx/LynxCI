#!/bin/bash

url01='http://seed01.getlynx.io:8080/'
url02='http://seed02.getlynx.io:8080/'
url03='http://seed03.getlynx.io:8080/'

header='Content-Type:application/json'

height=$(./lynx/src/lynx-cli getblockcount)

data="{"block_height":$height}"

wget -SqO- -T 1 -t 1 --post-data=$data --header=$header $url01
wget -SqO- -T 1 -t 1 --post-data=$data --header=$header $url02
wget -SqO- -T 1 -t 1 --post-data=$data --header=$header $url03