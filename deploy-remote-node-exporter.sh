#!/bin/bash

VERSION="1.7.0"
TARGET=$1

if [[ -z $TARGET ]]; then
    echo "Need the target host name"
    exit
fi

wget https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-amd64.tar.gz
tar xvfz node_exporter-$VERSION.linux-amd64.tar.gz
scp -r node_exporter-$VERSION.linux-amd64 $TARGET:

# Run remotely in background
ssh $TARGET "cd node_exporter-$VERSION.linux-amd64 && ./node_exporter &> ~/node-exporter.log & echo $! > node-exporter.pid && exit"

rm -rf node_exporter-$VERSION.linux-amd64 node_exporter-$VERSION.linux-amd64.tar.gz