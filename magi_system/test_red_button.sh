#!/bin/bash

[[ -z "$1" ]] && echo "Please provide the ip address as first argument." && exit -1
[[ -z "$2" ]] && echo "Please provide a valid image name as first argument." && exit -1

python3 -c "import requests;requests.post("http://$1:22333/alert", json={ "image": "$1"})"