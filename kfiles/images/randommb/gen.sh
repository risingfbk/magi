#!/bin/bash

if [[ -f ./Dockerfile ]]; then
    echo "This directory has already a Dockerfile! Do you want to erase it? (y/n)"
    read -r answer
    if [[ $answer != 'y' ]]; then
        echo "Interruption due to objection."
        exit
    fi
fi

if [[ -z $REGISTRY_IP_DOMAIN ]]; then
    echo "The domain with its port of the registry is missing. E.g. registry.example.com:8080. Please add it to the variable \$REGISTRY_IP_DOMAIN."
    exit
fi

for i in {1..40}; do
    echo "FROM ubuntu:latest" >> Dockerfile
    for y in $(seq 1 "$i"); do
        printf 'RUN od --format=c --address-radix=n /dev/urandom | tr -d " " | tr -d "\\n" | head -c 20M >> random.random.%s\n' "$y" >> Dockerfile 
    done
    docker build . -t "$REGISTRY_IP_DOMAIN/mfranzil/randommb:$i" --no-cache
    docker push "$REGISTRY_IP_DOMAIN/mfranzil/randommb:$i"
    rm Dockerfile
done
