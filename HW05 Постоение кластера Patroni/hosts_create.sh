#!/bin/bash
if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Usage: hosts_create.sh a b"
	echo "a: количенство хостов etcd"
	echo "b: количенство хостов postgres"
	exit
fi

var_address="10.129.0."
var_subnet="e2lujm508q11622ae9t2"


function create_host {
yc compute instance create \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,auto-delete,type=network-hdd,size=$3GB \
  --name bananaflow-19730802-$1 \
  --hostname $1  \
  --network-interface subnet-id=$var_subnet,address=$2 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --memory 2GB --cores 2 --core-fraction 20 --preemptible 
}

# create etcd hosts
for (( i=1; i <= $1; i++ ))
do
create_host etcd0$i $var_address"1"$i 8
done

# create postgres hosts
for (( i=1; i <= $2; i++ ))
do
create_host pg0$i $var_address"2"$i 20
done

# create main host
yc compute instance create \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,auto-delete,type=network-hdd,size=20GB \
  --name bananaflow-19730802-main \
  --hostname main \
  --network-interface subnet-id=e2lujm508q11622ae9t2,address=10.129.0.101,nat-address=51.250.31.197 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --memory 2GB --cores 2 --core-fraction 20 --preemptible

yc compute instance list
