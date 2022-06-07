#!/bin/bash

apt-get update
apt-get -y install build-essential  
apt-get -y install git

git clone https://github.com/Microsoft/ntttcp-for-linux
cd ntttcp-for-linux/src
make && make install

HOME="/home/ubuntu"

echo "#!/bin/bash" > $HOME/client1
echo "ntttcp -s -m 15,*,${peer1}.avxlab.de -V -L" >> $HOME/client1
chmod +x $HOME/client1

echo "#!/bin/bash" > $HOME/client2
echo "ntttcp -s -m 15,*,${peer2}.avxlab.de -V -L" >> $HOME/client2
chmod +x $HOME/client2


echo "#!/bin/bash" > $HOME/server
echo "IP=$(hostname -I)" >> $HOME/server
echo "ntttcp -r -H -M -m 15,*,\$IP -V" >> $HOME/server

chmod +x $HOME/server

