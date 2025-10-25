#!/bin/bash
if [ -z "$1" ] ; then
	echo "Usage: hosts_create.sh a"
	echo "a: количество хостов"
	exit
fi

var_address="10.129.0."
var_subnet="e2lujm508q11622ae9t2"


function create_host {
yc compute instance create \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,auto-delete,type=network-hdd,size=$3GB \
  --name bananaflow-19730802-$1 \
  --hostname $1  \
  --network-interface subnet-id=$var_subnet,address=$2,nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --memory 2GB --cores 2 --core-fraction 20 --preemptible 
}

# create hosts
for (( i=1; i <= $1; i++ ))
do
create_host pg0$i $var_address"1"$i 20
done

yc compute instance list
