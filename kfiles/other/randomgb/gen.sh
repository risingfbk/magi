#!/bin/bash

for i in {1..9}; do
    dir="randomgb-$i"
    mkdir $dir
    echo "FROM ubuntu:latest" >> $dir/Dockerfile
    for y in $(seq 1 $i); do
        echo 'RUN od --format=c --address-radix=n /dev/urandom | tr -d " " | tr -d "\n" | head -c 1950M >> random.random.'$y >> $dir/Dockerfile
    done
done
