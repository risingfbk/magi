#!/bin/bash

MODE=$1

if [[ "$UID" -ne 0 ]]; then
    echo "Please run magi_system.sh as root."
    exit 1
fi

if [[ "$MODE" == "master" ]]; then
    echo "Starting magi_system node in master mode..."
    ./init_master.sh
elif [[ "$MODE" == "node" ]]; then
    echo "Starting magi_system node in node mode..."
    ./init_node.sh
else
    echo "Please specify a mode: master or node"
    exit 1
fi