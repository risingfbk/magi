#!/bin/bash

sudo netstat -apeen | grep $(pgrep containerd | xargs ps | grep "containerd$" | cut -f 1 -d " ")/containerd | grep tcp | grep 10.231.0.208 | sed -E " s/ +/ /g" | cut -f 4 -d " " | cut -f 2 -d : | xargs -I {} sudo ss -K src 192.168.121.58 sport = {}