#!/bin/bash

if [[ -z $1 ]]; then
    echo "Need the target host name"
    exit
fi

scp certs/$REGISTRY_IP_DOMAIN.crt $1:
ssh $1 "sudo cp $REGISTRY_IP_DOMAIN.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates && sudo systemctl restart containerd"
