#!/bin/bash

if [[ -f ./Dockerfile ]]; then
    echo "This directory has already a Dockerfile! Do you want to erase it? (y/n)"
    read -r answer
    if [[ $answer != 'y' ]]; then
        echo "Interruption due to objection."
        exit
    fi
fi

for i in {1..200}; do
    echo "FROM ubuntu:latest" >> Dockerfile
    for y in $(seq 1 5); do
        printf 'RUN od --format=c --address-radix=n /dev/urandom | tr -d " " | tr -d "\\n" | head -c 39M >> random.random.%s\n' "$y" >> Dockerfile 
    done
    docker build . -t "registry-10-231-0-208.nip.io/mfranzil/100mb:$i" --no-cache
    docker push "registry-10-231-0-208.nip.io/mfranzil/100mb:$i"
    rm Dockerfile
done
