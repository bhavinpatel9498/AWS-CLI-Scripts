#!/bin/bash
## This file is used to initialize launched AWS instance
#Image created with git, apache, node pre installed
#sudo apt-get update
#sudo apt-get install git -y
#sudo apt-get install apache2 -y

#####################

cd /home/ubuntu

sudo git clone git@github.com:illinoistech-itm/bpatel68.git

cd ./bpatel68/itmo-544/mp3/node-proj-translator-ui-mp3

npm install

#sudo chown -R ubuntu:ubuntu /home/ubuntu

pm2 start server.js --name "translator-app"

#pm2 delete/stop "user-app"

#####################

#Wait up to 10 mins to format and mount additional EBS volume. Retry to mount every 15 sec.

x=0

while [ $x -lt 40 ]
do	
	sudo mkfs -t ext4 /dev/xvdh
  
	if [ "$?" -ne "0" ]
	then
		x=$(( $x + 1 ))
		sleep 15
	else
		x=$(( $x + 100 ))	
		
		sudo mkdir -p /mnt/datadisk
		sudo mount -t ext4 /dev/xvdh /mnt/datadisk
		sudo chown -R ubuntu:ubuntu /mnt/datadisk		
	fi      
done

############

