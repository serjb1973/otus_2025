#!/bin/bash

if [ -z "$1" ]; then
	echo "Usage: hosts.sh a"
	echo "a: stop|start|delete"
	exit
fi

for i in $(yc compute instance list --jq '.[].name' |grep -E 'bananaflow')
do
yc compute instance $1 --name $i
done

yc compute instance list
